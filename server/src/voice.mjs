// Ephemeral lobby-wide voice signaling. Audio stays peer-to-peer; nothing here
// is persisted, logged or attached to match history.

const kinds = new Set(['offer', 'answer', 'ice']);
const maxSdp = 8_000;
const maxCandidate = 1_500;

export class VoiceError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function fail(code, message) {
  throw new VoiceError(code, message);
}

export function validateSignal(message) {
  const to = message.to;
  const kind = message.kind;
  const generation = message.generation;
  const payload = message.payload;
  if (typeof to !== 'string' || to.length < 1 || to.length > 128) {
    fail('INVALID_SIGNAL', 'Destinatario della voce non valido.');
  }
  if (!kinds.has(kind)) fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  if (!Number.isInteger(generation) || generation < 1 || generation > 1_000_000) {
    fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    fail('INVALID_SIGNAL', 'Segnale vocale non valido.');
  }
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
    if (!Number.isInteger(line) || line < 0 || line > 16) {
      fail('INVALID_SIGNAL', 'Candidato vocale non valido.');
    }
    return {
      to,
      kind,
      generation,
      payload: { candidate, sdpMid: sdpMid ?? null, sdpMLineIndex: line },
    };
  }
  if (payload.type !== kind || typeof payload.sdp !== 'string' || payload.sdp.length < 1 || payload.sdp.length > maxSdp) {
    fail('INVALID_SIGNAL', 'Descrizione vocale non valida.');
  }
  return { to, kind, generation, payload: { type: kind, sdp: payload.sdp } };
}

export function createVoiceRelay() {
  const rooms = new Map();

  function roomOf(code) {
    let room = rooms.get(code);
    if (!room) {
      room = new Map();
      rooms.set(code, room);
    }
    return room;
  }

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

  function drop(code, playerId) {
    const room = rooms.get(code);
    if (!room?.delete(playerId)) return false;
    if (room.size === 0) rooms.delete(code);
    return true;
  }

  function forgetRoom(code) {
    rooms.delete(code);
  }

  function handle(code, playerId, message, peerIds) {
    const action = message.action;
    if (action === 'join') {
      const room = roomOf(code);
      const previous = room.get(playerId);
      const generation = (previous?.generation ?? 0) + 1;
      room.set(playerId, { muted: false, generation });
      return { broadcast: true };
    }
    if (action === 'leave') {
      return { broadcast: drop(code, playerId) };
    }
    if (action === 'mute') {
      if (typeof message.muted !== 'boolean') fail('INVALID_SIGNAL', 'Stato voce non valido.');
      const member = rooms.get(code)?.get(playerId);
      if (!member) fail('NOT_IN_VOICE', 'Attiva la voce prima di silenziarla.');
      member.muted = message.muted;
      return { broadcast: true };
    }
    if (action === 'signal') {
      const signal = validateSignal(message);
      if (signal.to === playerId) fail('INVALID_SIGNAL', 'Destinatario della voce non valido.');
      if (!peerIds.includes(signal.to)) fail('INVALID_SIGNAL', 'Quel giocatore non è nella lobby.');
      const room = rooms.get(code);
      const sender = room?.get(playerId);
      const target = room?.get(signal.to);
      if (!sender || !target) fail('NOT_IN_VOICE', 'La voce è attiva solo tra chi l’ha scelta.');
      if (signal.generation !== sender.generation) return { broadcast: false, drop: true };
      return {
        broadcast: false,
        relay: {
          to: signal.to,
          message: {
            type: 'voice',
            action: 'signal',
            from: playerId,
            kind: signal.kind,
            generation: signal.generation,
            payload: signal.payload,
          },
        },
      };
    }
    fail('INVALID_SIGNAL', 'Azione vocale non riconosciuta.');
  }

  return { members, stateMessage, drop, forgetRoom, handle };
}
