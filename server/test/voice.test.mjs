import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createIceProvider, createVoiceRelay, iceConfigFromEnv, validateSignal, VoiceError } from '../src/voice.mjs';
import { startServer } from '../src/server.mjs';

const caps = { supportedFeatures: ['lobby-v1', 'voice-v1'], supportedDecks: ['garden'] };
const sdp = 'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\n';
const candidate = { candidate: 'candidate:1 1 UDP 1 1.1.1.1 9 typ host', sdpMid: '0', sdpMLineIndex: 0 };

test('voice relay is lobby-wide, optional and does not persist descriptions', () => {
  const voice = createVoiceRelay();
  const code = 'ROOM01';
  const a = {}, b = {}, outsider = {};
  assert.deepEqual(voice.stateMessage(code).members, []);
  assert.equal(voice.handle(code, 'a', a, { action: 'join' }).broadcast, true);
  assert.equal(voice.handle(code, 'b', b, { action: 'join' }).broadcast, true);
  assert.deepEqual(voice.members(code).map(member => member.id), ['a', 'b']);
  const [genA, genB] = voice.members(code).map(member => member.generation);
  const offer = voice.handle(code, 'a', a, {
    action: 'signal', to: 'b', kind: 'offer', generation: genA, peerGeneration: genB,
    payload: { type: 'offer', sdp },
  });
  assert.equal(offer.relay.conn, b);
  assert.equal(offer.relay.message.from, 'a');
  assert.equal(offer.relay.message.peerGeneration, genB);
  assert.equal(offer.relay.message.payload.sdp.includes('127.0.0.1'), true);
  assert.equal(JSON.stringify(voice.stateMessage(code)).includes('127.0.0.1'), false);
  assert.throws(() => voice.handle(code, 'a', a, {
    action: 'signal', to: 'a', kind: 'offer', generation: genA, payload: { type: 'offer', sdp: 'v=0' },
  }), VoiceError);
  assert.throws(() => voice.handle(code, 'outsider', outsider, {
    action: 'signal', to: 'b', kind: 'offer', generation: 1, payload: { type: 'offer', sdp: 'v=0' },
  }), (error) => error.code === 'NOT_IN_VOICE');
  assert.equal(voice.handle(code, 'b', b, { action: 'mute', muted: true }).broadcast, true);
  assert.equal(voice.handle(code, 'b', b, { action: 'mute', muted: true }).broadcast, false);
  assert.equal(voice.members(code).find(member => member.id === 'b').muted, true);
  assert.equal(voice.drop(code, 'b'), true);
  assert.deepEqual(voice.members(code).map(member => member.id), ['a']);
  voice.forgetRoom(code);
  assert.deepEqual(voice.members(code), []);
  assert.equal(voice.disconnect(a), null);
});

test('generations are never reused and gate every relayed signal', () => {
  const voice = createVoiceRelay();
  const code = 'ROOM02';
  const a = {}, b = {};
  voice.handle(code, 'a', a, { action: 'join' });
  voice.handle(code, 'b', b, { action: 'join', muted: true });
  const generation = id => voice.members(code).find(member => member.id === id).generation;
  const first = { a: generation('a'), b: generation('b') };
  assert.equal(voice.members(code).find(member => member.id === 'b').muted, true);
  const ice = (from, conn, to, own, peer) => voice.handle(code, from, conn, {
    action: 'signal', to, kind: 'ice', generation: own, ...(peer === undefined ? {} : { peerGeneration: peer }),
    payload: candidate,
  });
  assert.ok(ice('a', a, 'b', first.a, first.b).relay);

  // A rejoin, even after the channel emptied, takes a brand new generation.
  voice.handle(code, 'a', a, { action: 'leave' });
  voice.handle(code, 'b', b, { action: 'leave' });
  assert.deepEqual(voice.members(code), []);
  voice.handle(code, 'a', a, { action: 'join' });
  voice.handle(code, 'b', b, { action: 'join' });
  const second = { a: generation('a'), b: generation('b') };
  assert.equal(new Set([first.a, first.b, second.a, second.b]).size, 4);

  // The sender's own stale generation and a stale view of the target both drop.
  for (const stale of [ice('a', a, 'b', first.a, second.b), ice('a', a, 'b', second.a, first.b)]) {
    assert.equal(stale.dropped, true);
    assert.equal(stale.relay, undefined);
  }
  // 30018 clients omit peerGeneration: their signal is still relayed, unlabelled.
  const legacy = ice('a', a, 'b', second.a);
  assert.equal(legacy.relay.conn, b);
  assert.equal('peerGeneration' in legacy.relay.message, false);

  // A target that just left is a lost race, not an error shown to the sender.
  voice.handle(code, 'b', b, { action: 'leave' });
  assert.equal(ice('a', a, 'b', second.a, second.b).dropped, true);
});

test('membership belongs to one connection of the seat', () => {
  const voice = createVoiceRelay();
  const code = 'ROOM03';
  const old = {}, fresh = {};
  voice.handle(code, 'a', old, { action: 'join' });
  const before = voice.members(code)[0].generation;
  // The seat resumes elsewhere and joins again before the old socket closes.
  voice.handle(code, 'a', fresh, { action: 'join' });
  const after = voice.members(code)[0].generation;
  assert.notEqual(after, before);
  assert.equal(voice.disconnect(old), null);
  assert.equal(voice.drop(code, 'a', old), false);
  assert.deepEqual(voice.members(code).map(member => member.generation), [after]);
  // The replaced connection can no longer speak for the seat.
  assert.throws(() => voice.handle(code, 'a', old, { action: 'mute', muted: true }),
    error => error.code === 'NOT_IN_VOICE');
  assert.equal(voice.handle(code, 'a', old, { action: 'leave' }).broadcast, false);
  assert.equal(voice.disconnect(fresh), code);
  assert.deepEqual(voice.members(code), []);
});

test('signal whitelist rejects oversized or unexpected fields', () => {
  assert.throws(() => validateSignal({
    to: 'b', kind: 'offer', generation: 1, payload: { type: 'offer', sdp: 'x'.repeat(8001) },
  }), VoiceError);
  assert.throws(() => validateSignal({
    to: 'b', kind: 'offer', generation: 1, payload: { type: 'answer', sdp: 'v=0' },
  }), VoiceError);
  assert.throws(() => validateSignal({
    to: 'b', kind: 'offer', generation: 1, peerGeneration: 0, payload: { type: 'offer', sdp: 'v=0' },
  }), VoiceError);
  assert.throws(() => validateSignal({
    to: 'b', kind: 'ice', generation: 1, payload: { candidate: 'candidate:1' },
  }), VoiceError);
  const ice = validateSignal({
    to: 'b', kind: 'ice', generation: 2, payload: { ...candidate, extra: 'no' },
  });
  assert.equal(ice.payload.extra, undefined);
  assert.equal(validateSignal({
    to: 'b', kind: 'ice', generation: 2, payload: { candidate: 'candidate:1', sdpMid: '0' },
  }).payload.sdpMLineIndex, null);
});

test('ICE servers come from the service with short-lived TURN credentials', () => {
  const warnings = [];
  const options = { now: () => 1_000_000, warn: message => warnings.push(message) };
  assert.deepEqual(createIceProvider(iceConfigFromEnv({}), options)(), [
    { urls: ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'] },
  ]);
  const config = iceConfigFromEnv({
    VOICE_STUN_URLS: 'stun:turn.example.org:3478',
    VOICE_TURN_URLS: 'turn:turn.example.org:3478?transport=udp, turns:turn.example.org:5349?transport=tcp, http://nope',
    VOICE_TURN_SECRET: 'shared-secret',
    VOICE_TURN_TTL_SECONDS: '3600',
  });
  const provide = createIceProvider(config, options);
  const [stun, turn] = provide();
  assert.deepEqual(stun, { urls: ['stun:turn.example.org:3478'] });
  assert.deepEqual(turn.urls, ['turn:turn.example.org:3478?transport=udp', 'turns:turn.example.org:5349?transport=tcp']);
  assert.match(turn.username, /^4600:[\w-]{12}$/);
  assert.equal(turn.credential, createHmac('sha1', 'shared-secret').update(turn.username).digest('base64'));
  assert.notEqual(provide()[1].username, turn.username);
  assert.equal(warnings.length, 1);
  // URLs without the secret never yield an unusable or guessable credential.
  assert.deepEqual(createIceProvider(iceConfigFromEnv({ VOICE_STUN_URLS: '', VOICE_TURN_URLS: 'turn:t.example.org' }), options)(), []);
  assert.equal(warnings.length, 2);
  assert.equal(JSON.stringify(provide()).includes('shared-secret'), false);

  const voice = createVoiceRelay({ iceServers: provide });
  const reply = voice.handle('ROOM04', 'a', {}, { action: 'join' }).reply;
  assert.equal(reply.action, 'config');
  assert.equal(reply.iceServers.length, 2);
});

async function harness(options = {}) {
  const server = startServer({ port: 0, dataDir: null, ...options });
  await once(server.http, 'listening');
  const sockets = [];
  async function connect() {
    const ws = new WebSocket(`ws://127.0.0.1:${server.http.address().port}/ws`);
    sockets.push(ws);
    const queue = [], waiters = [];
    ws.on('message', raw => {
      const msg = JSON.parse(raw);
      waiters.length ? waiters.shift()(msg) : queue.push(msg);
    });
    await once(ws, 'open');
    const next = () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waiters.push(resolve));
    const take = async (type, accept = () => true) => {
      for (;;) {
        const msg = await next();
        if (msg.type === type && accept(msg)) return msg;
      }
    };
    return {
      ws, queue, next, take,
      send: msg => ws.send(JSON.stringify(msg)),
      voice: (action, accept = () => true) => take('voice', msg => msg.action === action && accept(msg)),
      roster: accept => take('voice', msg => msg.action === 'state' && accept(msg.members)),
    };
  }
  async function room(guestCaps = caps) {
    const host = await connect(), guest = await connect();
    host.send({ type: 'create', name: 'A', theme: 'garden', pairs: 6, ...caps });
    const hostSession = await host.take('session');
    guest.send({ type: 'join', name: 'B', code: hostSession.code, ...guestCaps });
    const guestSession = await guest.take('session');
    await host.take('state', state => state.players.length === 2);
    return { host, guest, hostSession, guestSession };
  }
  return {
    server, connect, room,
    close: async () => {
      for (const socket of sockets) socket.terminate();
      await server.close();
    },
  };
}

test('websocket voice reaches every opted-in seat and leaves with the socket', async () => {
  const h = await harness();
  try {
    const { host, guest, hostSession, guestSession } = await h.room();
    host.send({ type: 'voice', action: 'join' });
    const config = await host.voice('config');
    assert.ok(config.iceServers.every(server => server.urls.every(url => url.startsWith('stun:'))));
    const hostOnly = await host.roster(members => members.length === 1);
    assert.deepEqual(hostOnly.members.map(member => member.id), [hostSession.playerId]);
    guest.send({ type: 'voice', action: 'join', muted: true });
    const both = await guest.roster(members => members.length === 2);
    const generationOf = id => both.members.find(member => member.id === id).generation;
    assert.equal(both.members.find(member => member.id === guestSession.playerId).muted, true);
    await host.roster(members => members.length === 2);
    host.send({
      type: 'voice', action: 'signal', to: guestSession.playerId, kind: 'offer',
      generation: generationOf(hostSession.playerId), peerGeneration: generationOf(guestSession.playerId),
      payload: { type: 'offer', sdp },
    });
    const relayed = await guest.voice('signal');
    assert.equal(relayed.from, hostSession.playerId);
    assert.equal(relayed.generation, generationOf(hostSession.playerId));
    assert.equal(relayed.peerGeneration, generationOf(guestSession.playerId));
    assert.equal(relayed.payload.sdp, sdp);
    host.ws.close();
    const left = await guest.roster(members => !members.some(member => member.id === hostSession.playerId));
    assert.deepEqual(left.members.map(member => member.id), [guestSession.playerId]);
    // Answering someone who just left is silent; the match and voice go on.
    guest.send({
      type: 'voice', action: 'signal', to: hostSession.playerId, kind: 'answer',
      generation: generationOf(guestSession.playerId), payload: { type: 'answer', sdp },
    });
    guest.send({ type: 'voice', action: 'mute', muted: false });
    const next = await guest.take('voice');
    assert.equal(next.action, 'state');
    assert.equal(next.members[0].muted, false);
    guest.send({ type: 'voice', action: 'leave' });
    await guest.roster(members => members.length === 0);
    guest.send({ type: 'voice', action: 'mute', muted: true });
    assert.equal((await guest.voice('error')).code, 'NOT_IN_VOICE');
  } finally {
    await h.close();
  }
});

test('a resumed seat keeps its new voice membership when the old socket closes', async () => {
  const h = await harness();
  try {
    const { host, guest, hostSession, guestSession } = await h.room();
    host.send({ type: 'voice', action: 'join' });
    guest.send({ type: 'voice', action: 'join' });
    await host.roster(members => members.length === 2);
    const before = (await guest.roster(members => members.length === 2)).members;
    const oldGeneration = before.find(member => member.id === guestSession.playerId).generation;

    // The guest resumes on a second socket while the first is still open.
    const resumed = await h.connect();
    resumed.send({ type: 'resume', code: guestSession.code, token: guestSession.token, ...caps });
    await resumed.take('session');
    // The takeover ended the old connection's voice membership immediately.
    await host.roster(members => members.length === 1 && members[0].id === hostSession.playerId);
    const snapshot = await resumed.roster(() => true);
    assert.deepEqual(snapshot.members.map(member => member.id), [hostSession.playerId]);
    resumed.send({ type: 'voice', action: 'join' });
    const rejoined = await host.roster(members => members.length === 2);
    const newGeneration = rejoined.members.find(member => member.id === guestSession.playerId).generation;
    assert.ok(newGeneration > oldGeneration);
    if (guest.ws.readyState !== WebSocket.CLOSED) await once(guest.ws, 'close');
    // A later roster still lists the resumed connection.
    host.send({ type: 'voice', action: 'mute', muted: true });
    const after = await host.roster(members => members.some(member => member.muted));
    assert.equal(after.members.find(member => member.id === guestSession.playerId).generation, newGeneration);
  } finally {
    await h.close();
  }
});

test('seats that did not advertise voice-v1 neither receive nor send voice', async () => {
  const h = await harness();
  try {
    const { host, guest } = await h.room({ supportedFeatures: ['lobby-v1'], supportedDecks: ['garden'] });
    host.send({ type: 'voice', action: 'join' });
    await host.roster(members => members.length === 1);
    guest.send({ type: 'voice', action: 'join' });
    const denied = await guest.take('voice');
    assert.equal(denied.action, 'error');
    assert.equal(denied.code, 'VOICE_UNSUPPORTED');
    guest.send({ type: 'ping' });
    await guest.take('pong');
    assert.equal(guest.queue.some(message => message.type === 'voice'), false);
  } finally {
    await h.close();
  }
});

test('a signaling burst is dropped without closing the match socket', async () => {
  const h = await harness();
  try {
    const { host, guest, guestSession } = await h.room();
    host.send({ type: 'voice', action: 'join' });
    guest.send({ type: 'voice', action: 'join' });
    const roster = (await host.roster(members => members.length === 2)).members;
    const own = roster.find(member => member.id !== guestSession.playerId).generation;
    for (let i = 0; i < 200; i++) {
      host.send({ type: 'voice', action: 'signal', to: guestSession.playerId, kind: 'ice', generation: own, payload: candidate });
    }
    assert.equal((await host.voice('error')).code, 'RATE_LIMITED');
    host.send({ type: 'ping' });
    await host.take('pong');
    assert.equal(host.ws.readyState, WebSocket.OPEN);
    let relayed = 0;
    guest.send({ type: 'ping' });
    for (;;) {
      const message = await guest.next();
      if (message.type === 'pong') break;
      if (message.type === 'voice' && message.action === 'signal') relayed++;
    }
    assert.ok(relayed > 0 && relayed < 200, `relayed ${relayed}`);
  } finally {
    await h.close();
  }
});
