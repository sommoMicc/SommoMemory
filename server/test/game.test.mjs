import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { GameEngine } from '../src/game.mjs';

const setup = options => {
  let time = 1_000_000;
  const game = new GameEngine({ now: () => time, ...options });
  const first = game.create({ name: 'Alice', pairs: 6, theme: 'garden' });
  const second = game.join({ code: first.code, name: 'Bob' });
  return { game, first, second, advance(ms) { time += ms; game.tick(); } };
};

test('deck capabilities are strict, bounded and checked before any room or seat mutation', () => {
  const game = new GameEngine();
  const invalid = [null, 'garden', {}, [1], ['unknown'], ['Garden'], ['garden '], ['garden', 'garden'], Array(11).fill('garden')];
  for (const supportedDecks of invalid) {
    assert.throws(() => game.create({ name: 'A', theme: 'garden', supportedDecks }), { code: 'INVALID_CAPABILITIES' });
    assert.equal(game.rooms.size, 0);
  }
  assert.throws(() => game.create({ name: 'A', theme: 'paola' }), { code: 'UPDATE_REQUIRED' });
  assert.equal(game.rooms.size, 0);
  const host = game.create({ name: 'A', theme: 'paola', supportedDecks: ['paola'] });
  const before = game.state(host.code);
  for (const supportedDecks of invalid) {
    assert.throws(() => game.join({ code: host.code, name: 'B', supportedDecks }), { code: 'INVALID_CAPABILITIES' });
    assert.deepEqual(game.state(host.code), before);
  }
  game.disconnect(host.code, host.playerId);
  const disconnected = game.state(host.code);
  for (const supportedDecks of invalid) {
    assert.throws(() => game.resume({ ...host, supportedDecks }), { code: 'INVALID_CAPABILITIES' });
    assert.deepEqual(game.state(host.code), disconnected);
  }
});

test('full-room previews precede theme compatibility and expose only copied public scores/results', () => {
  const game = new GameEngine();
  const first = game.create({ name: 'Alice', pairs: 6, theme: 'paola', profileId: 'private-profile-a', supportedDecks: ['paola'] });
  const second = game.join({ code: first.code, name: 'Bob', profileId: 'private-profile-b', supportedDecks: ['paola'] });
  const room = game.room(first.code);
  const pair = room.board.flatMap((value, index) => value === room.board[0] ? [index] : []);
  pair.forEach(index => game.flip(first.code, first.playerId, index));
  const revision = room.revision;
  let rejected;
  try { game.join({ code: first.code, name: 'Old client' }); } catch (error) { rejected = error; }
  assert.equal(rejected.code, 'ROOM_FULL');
  const preview = rejected.roomPreview;
  assert.deepEqual(Object.keys(preview).sort(), ['code', 'phase', 'players', 'winnerId', 'winnerIds', 'finishReason'].sort());
  assert.deepEqual(preview.players.map(p => p.score), [1, 0]);
  assert.equal(preview.phase, 'playing');
  for (const player of preview.players) assert.deepEqual(Object.keys(player).sort(), ['id', 'name', 'score', 'connected'].sort());
  for (const secret of [first.token, second.token, 'private-profile-a', 'private-profile-b', 'tokenHash', 'cards', 'board', 'selected'])
    assert.equal(JSON.stringify(preview).includes(secret), false);
  assert.equal(room.players.length, 2);
  assert.equal(room.revision, revision);
  for (let value = 0; value < room.pairs; value++) {
    const indices = room.board.flatMap((card, index) => card === String(value) && !room.matched.includes(index) ? [index] : []);
    indices.forEach(index => game.flip(first.code, first.playerId, index));
  }
  const finished = game.preview({ code: first.code });
  assert.equal(finished.phase, 'finished');
  assert.equal(finished.winnerId, first.playerId);
  assert.equal(finished.finishReason, 'completed');
  assert.deepEqual(finished.players.map(p => p.score), [6, 0]);
  assert.deepEqual(preview.players.map(p => p.score), [1, 0]);
  preview.players[0].name = 'Changed copy';
  assert.equal(room.players[0].name, 'Alice');
  const cosmos = game.create({ name: 'Legacy', pairs: 6, theme: 'cosmos' });
  assert.doesNotThrow(() => game.join({ code: cosmos.code, name: 'Legacy too' }));
  assert.throws(() => game.join({ code: cosmos.code, name: 'Third', supportedDecks: ['garden'] }), { code: 'ROOM_FULL' });
});

test('public state never reveals hidden identities, tokens or internal board', () => {
  const { game, first } = setup();
  const state = game.state(first.code);
  assert.equal(state.cards.length, 12);
  assert.ok(state.cards.every(c => c === null));
  assert.ok(!JSON.stringify(state).includes('token'));
  assert.ok(!('board' in state));
  game.flip(first.code, first.playerId, 0);
  const next = game.state(first.code);
  assert.equal(next.cards.filter(c => c !== null).length, 1);
  assert.equal(next.cards[0], game.rooms.get(first.code).board[0]);
});

test('only current player may reveal valid, unrevealed cards', () => {
  const { game, first, second } = setup();
  assert.throws(() => game.flip(first.code, second.playerId, 0), { code: 'NOT_YOUR_TURN' });
  for (const index of [-1, 12, 0.5, '0', null]) {
    assert.throws(() => game.flip(first.code, first.playerId, index), { code: 'INVALID_CARD' });
  }
  game.flip(first.code, first.playerId, 0);
  assert.throws(() => game.flip(first.code, first.playerId, 0), { code: 'INVALID_CARD' });
});

test('mismatches lock the board, hide after delay and change turn', () => {
  const { game, first, second, advance } = setup();
  const room = game.rooms.get(first.code);
  const other = room.board.findIndex(c => c !== room.board[0]);
  game.flip(first.code, first.playerId, 0);
  game.flip(first.code, first.playerId, other);
  assert.equal(game.state(first.code).selected.length, 2);
  assert.throws(() => game.flip(first.code, first.playerId, 2), { code: 'BOARD_LOCKED' });
  advance(899);
  assert.equal(game.state(first.code).selected.length, 2);
  advance(1);
  const state = game.state(first.code);
  assert.ok(state.cards.every(c => c === null));
  assert.equal(state.turn, second.playerId);
});

test('matching retains turn, scores, finishes and requires both rematch votes', () => {
  const { game, first, second } = setup();
  const room = game.rooms.get(first.code);
  for (let value = 0; value < room.pairs; value++) {
    const indices = room.board.flatMap((c, i) => c === String(value) ? [i] : []);
    indices.forEach(i => game.flip(first.code, first.playerId, i));
  }
  let state = game.state(first.code);
  assert.equal(state.phase, 'finished');
  assert.equal(state.finishReason, 'completed');
  assert.equal(state.players[0].score, 6);
  assert.equal(state.winnerId, first.playerId);
  assert.equal(state.turn, null);
  game.rematch(first.code, first.playerId);
  assert.equal(game.state(first.code).phase, 'finished');
  assert.deepEqual(game.state(first.code).rematch, [first.playerId]);
  game.rematch(first.code, second.playerId);
  state = game.state(first.code);
  assert.equal(state.phase, 'playing');
  assert.equal(state.turn, second.playerId);
  assert.ok(state.cards.every(c => c === null));
  assert.deepEqual(state.players.map(p => p.score), [0, 0]);
});

test('disconnect pauses play, secure resume restores identity and grace forfeits', () => {
  const { game, first, second, advance } = setup();
  game.disconnect(first.code, second.playerId);
  assert.throws(() => game.flip(first.code, first.playerId, 0), { code: 'OPPONENT_OFFLINE' });
  assert.throws(() => game.resume({ code: first.code, token: 'wrong' }), { code: 'INVALID_SESSION' });
  advance(30_000);
  const restored = game.resume(second);
  assert.equal(restored.playerId, second.playerId);
  assert.equal(game.state(first.code).players[1].connected, true);
  game.disconnect(first.code, second.playerId);
  advance(90_000);
  assert.equal(game.state(first.code).winnerId, first.playerId);
  assert.equal(game.state(first.code).finishReason, 'forfeit');
  assert.throws(() => game.resume(second), { code: 'INVALID_SESSION' });
});

test('explicit leave invalidates token and prevents rematch', () => {
  const { game, first, second } = setup();
  game.leave(first.code, first.playerId);
  assert.equal(game.state(first.code).winnerId, second.playerId);
  assert.throws(() => game.resume(first), { code: 'INVALID_SESSION' });
  assert.throws(() => game.rematch(second.code, second.playerId), { code: 'OPPONENT_OFFLINE' });
});

test('persistent restart restores cards and scores without persisting bearer tokens', () => {
  const dataDir = mkdtempSync(join(tmpdir(), 'mymemory-test-'));
  try {
    const { game, first, second } = setup({ dataDir });
    game.flip(first.code, first.playerId, 0);
    const before = game.state(first.code);
    const file = readFileSync(join(dataDir, 'rooms.json'), 'utf8');
    assert.ok(!file.includes(first.token));
    assert.ok(!file.includes(second.token));
    const restored = new GameEngine({ dataDir, now: () => 1_000_001 });
    assert.ok(restored.state(first.code).players.every(p => !p.connected));
    restored.resume(first);
    restored.resume(second);
    assert.deepEqual(restored.state(first.code).cards, before.cards);
    assert.equal(restored.state(first.code).turn, first.playerId);
  } finally { rmSync(dataDir, { recursive: true, force: true }); }
});

test('capacity, expiry, invalid options and player name boundaries', () => {
  let time = 10_000;
  const game = new GameEngine({ maxRooms: 1, now: () => time, ttlMs: 1000 });
  assert.throws(() => game.create({ name: '', pairs: 6 }), { code: 'INVALID_NAME' });
  assert.throws(() => game.create({ name: 'Alice', pairs: 7 }), { code: 'INVALID_OPTIONS' });
  const session = game.create({ name: ' A\n' + '😀'.repeat(30), pairs: 6 });
  assert.equal([...game.state(session.code).players[0].name].length, 24);
  assert.throws(() => game.create({ name: 'Bob' }), { code: 'SERVER_FULL' });
  time += 1001;
  game.tick();
  assert.equal(game.rooms.size, 0);
});
