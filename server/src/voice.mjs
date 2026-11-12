// Ephemeral lobby-wide voice signaling. Audio stays peer-to-peer (or crosses a
// TURN relay still encrypted end to end); nothing here is persisted, logged or
// attached to match history.
//
// Model: a voice member is one *connection* of one seat. Each join receives a
// generation that is never reused, so a pair of members (generationA,
// generationB) names exactly one peer connection attempt. The relay is the
// sequencer: it forwards a signal only while both generations are current, so
// a client that rebuilds its peers from the roster can never be handed a
// description or candidate that belongs to an earlier attempt.

import { createHmac, randomBytes } from 'node:crypto';

const kinds = new Set(['offer', 'answer', 'ice']);
const maxSdp = 8_000;
const maxCandidate = 1_500;
const iceUrl = /^(stun|stuns|turn|turns):[^\s,]{1,255}$/;
const defaultStun = ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'];

export class VoiceError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function fail(code, message) {
  throw new VoiceError(code, message);
}

const validGeneration = value => Number.isSafeInteger(value) && value >= 1;

export function validateSignal(message) {
  const to = message.to;
  const kind = message.kind;
  const generation = message.generation;
  const peerGeneration = message.peerGeneration;
  const payload = message.payload;
  if (typeof to !== 'string' || to.length < 1 || to.length > 128) {
    fail('INVALID_SIGNAL', 'Destinatario della voce non valido.');
  }
  if (!kinds.has(kind)) fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  if (!validGeneration(generation) || (peerGeneration !== undefined && !validGeneration(peerGeneration))) {
    fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  }
  const base = { to, kind, generation, ...(peerGeneration === undefined ? {} : { peerGeneration }) };
  if (kind === 'ice') {
    const candidate = payload.candidate;
    const sdpMid = payload.sdpMid;
    const line = payload.sdpMLineIndex;
    if (typeof candidate !== 'string' || candidate.length < 1 || candidate.length > maxCandidate) {
      fail('INVALID_SIGNAL', 'Candidato vocale non valido.');
    }
    if (sdpMid != null && (typeof sdpMid !== 'string' || sdpMid.length > 32)) {
      fail('INVALID_SIGNAL', 'Candidato vocale non valido.');
    }
    if (line != null && (!Number.isInteger(line) || line < 0 || line > 16)) {
      fail('INVALID_SIGNAL', 'Candidato vocale non valido.');
    }
    if (sdpMid == null && line == null) fail('INVALID_SIGNAL', 'Candidato vocale non valido.');
    return { ...base, payload: { candidate, sdpMid: sdpMid ?? null, sdpMLineIndex: line ?? null } };
  }
  if (payload.type !== kind || typeof payload.sdp !== 'string' || payload.sdp.length < 1 || payload.sdp.length > maxSdp) {
    fail('INVALID_SIGNAL', 'Descrizione vocale non valida.');
  }
  return { ...base, payload: { type: kind, sdp: payload.sdp } };
}

const list = value => String(value ?? '').split(',').map(item => item.trim()).filter(Boolean);

/// Reads the ICE settings the service hands to voice members. STUN defaults to
/// public servers; TURN is offered only when both URLs and the shared secret
/// are configured (coturn `use-auth-secret` / "TURN REST API" credentials).
export function iceConfigFromEnv(env = process.env) {
  const ttl = Number(env.VOICE_TURN_TTL_SECONDS);
  return {
    stunUrls: env.VOICE_STUN_URLS === undefined ? defaultStun : list(env.VOICE_STUN_URLS),
    turnUrls: list(env.VOICE_TURN_URLS),
    turnSecret: env.VOICE_TURN_SECRET || '',
    turnTtlSeconds: Number.isInteger(ttl) && ttl >= 600 && ttl <= 86_400 ? ttl : 14_400,
  };
}

/// Returns a function producing a fresh `iceServers` list. TURN credentials are
/// short-lived and derived per call, so no long-term secret reaches a client.
export function createIceProvider(config = {}, { now = Date.now, warn = console.error } = {}) {
  const usable = (urls, schemes, label) => (urls ?? []).filter(url => {
    const ok = typeof url === 'string' && iceUrl.test(url) && schemes.includes(url.split(':')[0]);
    if (!ok) warn(`Voice: ignoring invalid ${label} URL.`);
    return ok;
  });
  const stun = usable(config.stunUrls, ['stun', 'stuns'], 'STUN');
  let turn = usable(config.turnUrls, ['turn', 'turns'], 'TURN');
  const secret = config.turnSecret ?? '';
  if (turn.length && !secret) {
    warn('Voice: VOICE_TURN_URLS is set without VOICE_TURN_SECRET; TURN stays disabled.');
    turn = [];
  }
  const ttl = config.turnTtlSeconds ?? 14_400;
  return () => {
    const servers = [];
    if (stun.length) servers.push({ urls: stun });
    if (turn.length) {
      const username = `${Math.floor(now() / 1000) + ttl}:${randomBytes(9).toString('base64url')}`;
      servers.push({
        urls: turn,
        username,
        credential: createHmac('sha1', secret).update(username).digest('base64'),
      });
    }
    return servers;
  };
}

export function createVoiceRelay({ iceServers = () => [] } = {}) {
  const rooms = new Map();
  const seats = new WeakMap();
  let lastGeneration = 0;

  function members(code) {
    return [...(rooms.get(code)?.entries() ?? [])].map(([id, member]) => ({
      id,
      muted: member.muted,
      generation: member.generation,
    }));
  }

  function stateMessage(code) {
    return { type: 'voice', action: 'state', members: members(code) };
  }

  /// Removes a member. With `conn`, only that connection's membership goes, so
  /// a late close of a replaced socket cannot evict the seat's new connection.
  function drop(code, playerId, conn) {
    const room = rooms.get(code);
    const member = room?.get(playerId);
    if (!member || (conn !== undefined && member.conn !== conn)) return false;
    room.delete(playerId);
    seats.delete(member.conn);
    if (room.size === 0) rooms.delete(code);
    return true;
  }

  /// Ends whatever membership `conn` holds. Returns the room code to notify.
  function disconnect(conn) {
    const seat = seats.get(conn);
    if (!seat) return null;
    return drop(seat.code, seat.playerId, conn) ? seat.code : null;
  }

  function forgetRoom(code) {
    for (const member of rooms.get(code)?.values() ?? []) seats.delete(member.conn);
    rooms.delete(code);
  }

  function memberOf(code, playerId, conn) {
    const member = rooms.get(code)?.get(playerId);
    return member && member.conn === conn ? member : null;
  }

  function handle(code, playerId, conn, message) {
    const action = message.action;
    if (action === 'join') {
      if (message.muted !== undefined && typeof message.muted !== 'boolean') {
        fail('INVALID_SIGNAL', 'Stato voce non valido.');
      }
      disconnect(conn);
      drop(code, playerId);
      let room = rooms.get(code);
      if (!room) rooms.set(code, room = new Map());
      room.set(playerId, { conn, muted: message.muted === true, generation: ++lastGeneration });
      seats.set(conn, { code, playerId });
      return {
        broadcast: true,
        reply: { type: 'voice', action: 'config', iceServers: iceServers() },
      };
    }
    if (action === 'leave') {
      return { broadcast: drop(code, playerId, conn) };
    }
    if (action === 'mute') {
      if (typeof message.muted !== 'boolean') fail('INVALID_SIGNAL', 'Stato voce non valido.');
      const member = memberOf(code, playerId, conn);
      if (!member) fail('NOT_IN_VOICE', 'Attiva la voce prima di silenziarla.');
      if (member.muted === message.muted) return { broadcast: false };
      member.muted = message.muted;
      return { broadcast: true };
    }
    if (action === 'signal') {
      const signal = validateSignal(message);
      if (signal.to === playerId) fail('INVALID_SIGNAL', 'Destinatario della voce non valido.');
      const sender = memberOf(code, playerId, conn);
      if (!sender) fail('NOT_IN_VOICE', 'La voce è attiva solo tra chi l’ha scelta.');
      const target = rooms.get(code).get(signal.to);
      // Losing a race with a leave or a rejoin is normal: the roster broadcast
      // already tells the sender what changed, so these are dropped silently.
      if (!target || signal.generation !== sender.generation ||
          (signal.peerGeneration !== undefined && signal.peerGeneration !== target.generation)) {
        return { broadcast: false, dropped: true };
      }
      return {
        broadcast: false,
        relay: {
          conn: target.conn,
          message: {
            type: 'voice',
            action: 'signal',
            from: playerId,
            kind: signal.kind,
            generation: signal.generation,
            ...(signal.peerGeneration === undefined ? {} : { peerGeneration: signal.peerGeneration }),
            payload: signal.payload,
          },
        },
      };
    }
    fail('INVALID_SIGNAL', 'Azione vocale non riconosciuta.');
  }

  return { members, stateMessage, drop, disconnect, forgetRoom, handle };
}
