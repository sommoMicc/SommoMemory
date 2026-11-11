import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createVoiceRelay, validateSignal, VoiceError } from '../src/voice.mjs';
import { startServer } from '../src/server.mjs';

const caps = { supportedFeatures: ['lobby-v1', 'voice-v1'], supportedDecks: ['garden'] };

test('voice relay is lobby-wide, optional and does not persist descriptions', () => {
  const voice = createVoiceRelay();
  const code = 'ROOM01';
  assert.deepEqual(voice.stateMessage(code).members, []);
  assert.equal(voice.handle(code, 'a', { action: 'join' }, ['a', 'b']).broadcast, true);
  assert.equal(voice.handle(code, 'b', { action: 'join' }, ['a', 'b']).broadcast, true);
  assert.deepEqual(voice.members(code).map(member => member.id), ['a', 'b']);
  const offer = voice.handle(code, 'a', {
    action: 'signal', to: 'b', kind: 'offer', generation: 1,
    payload: { type: 'offer', sdp: 'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\n' },
  }, ['a', 'b']);
  assert.equal(offer.relay.to, 'b');
  assert.equal(offer.relay.message.from, 'a');
  assert.equal(offer.relay.message.payload.sdp.includes('127.0.0.1'), true);
  assert.equal(JSON.stringify(voice.stateMessage(code)).includes('127.0.0.1'), false);
  assert.throws(() => voice.handle(code, 'a', {
    action: 'signal', to: 'a', kind: 'offer', generation: 1, payload: { type: 'offer', sdp: 'v=0' },
  }, ['a', 'b']), VoiceError);
  assert.throws(() => voice.handle(code, 'outsider', {
    action: 'signal', to: 'b', kind: 'offer', generation: 1, payload: { type: 'offer', sdp: 'v=0' },
  }, ['a', 'b']), (error) => error.code === 'NOT_IN_VOICE');
  voice.handle(code, 'b', { action: 'mute', muted: true }, ['a', 'b']);
  assert.equal(voice.members(code).find(member => member.id === 'b').muted, true);
  voice.handle(code, 'a', { action: 'join' }, ['a', 'b']);
  assert.equal(voice.members(code).find(member => member.id === 'a').generation, 2);
  const stale = voice.handle(code, 'a', {
    action: 'signal', to: 'b', kind: 'ice', generation: 1,
    payload: { candidate: 'candidate:1 1 UDP 1 1.1.1.1 9 typ host', sdpMid: '0', sdpMLineIndex: 0 },
  }, ['a', 'b']);
  assert.equal(stale.drop, true);
  assert.equal(stale.relay, undefined);
  assert.equal(voice.drop(code, 'b'), true);
  assert.deepEqual(voice.members(code).map(member => member.id), ['a']);
  voice.forgetRoom(code);
  assert.deepEqual(voice.members(code), []);
});

test('signal whitelist rejects oversized or unexpected fields', () => {
  assert.throws(() => validateSignal({
    to: 'b', kind: 'offer', generation: 1, payload: { type: 'offer', sdp: 'x'.repeat(8001) },
  }), VoiceError);
  assert.throws(() => validateSignal({
    to: 'b', kind: 'offer', generation: 1, payload: { type: 'answer', sdp: 'v=0' },
  }), VoiceError);
  const ice = validateSignal({
    to: 'b', kind: 'ice', generation: 2,
    payload: { candidate: 'candidate:1 1 UDP 1 1.1.1.1 9 typ host', sdpMid: '0', sdpMLineIndex: 0, extra: 'no' },
  });
  assert.equal(ice.payload.extra, undefined);
});

async function voiceState(client, accept) {
  for (;;) {
    const message = await client.take('voice');
    if (message.action === 'state' && accept(message.members)) return message;
  }
}

test('websocket voice reaches every opted-in seat and leaves with the socket', async () => {
  const server = startServer({ port: 0, dataDir: null });
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
    return {
      ws,
      send: msg => ws.send(JSON.stringify(msg)),
      next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise(resolve => waiters.push(resolve)),
      take: async (type) => {
        for (;;) {
          const msg = queue.length ? queue.shift() : await new Promise(resolve => waiters.push(resolve));
          if (msg.type === type) return msg;
        }
      },
    };
  }
  try {
    const host = await connect(), guest = await connect();
    host.send({ type: 'create', name: 'A', theme: 'garden', pairs: 6, ...caps });
    const session = await host.next();
    assert.equal(session.type, 'session');
    await host.next();
    guest.send({ type: 'join', name: 'B', code: session.code, ...caps });
    const guestSession = await guest.next();
    await guest.next();
    await host.take('state');
    host.send({ type: 'voice', action: 'join' });
    const hostOnly = await voiceState(host, members => members.some(member => member.id === session.playerId) && members.length === 1);
    assert.deepEqual(hostOnly.members.map(member => member.id), [session.playerId]);
    guest.send({ type: 'voice', action: 'join' });
    const both = await voiceState(guest, members => members.length === 2);
    assert.equal(both.members.length, 2);
    await voiceState(host, members => members.length === 2);
    const sdp = 'v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\n';
    host.send({
      type: 'voice', action: 'signal', to: guestSession.playerId, kind: 'offer', generation: 1,
      payload: { type: 'offer', sdp },
    });
    const relayed = await guest.take('voice');
    assert.equal(relayed.action, 'signal');
    assert.equal(relayed.from, session.playerId);
    assert.equal(relayed.payload.sdp, sdp);
    host.ws.close();
    const left = await voiceState(guest, members => !members.some(member => member.id === session.playerId));
    assert.equal(left.members.some(member => member.id === session.playerId), false);
    guest.send({ type: 'voice', action: 'signal', to: session.playerId, kind: 'answer', generation: 1, payload: { type: 'answer', sdp } });
    let denied;
    do { denied = await guest.take('voice'); } while (denied.action !== 'error');
    assert.equal(denied.code, 'NOT_IN_VOICE');
  } finally {
    for (const socket of sockets) socket.terminate();
    await server.close();
  }
});
