import test from 'node:test';
import assert from 'node:assert/strict';
import { GameEngine } from '../src/game.mjs';
import { ARENA_CATALOG } from '../src/arenas.mjs';

const decks = ARENA_CATALOG.decks.map(d => d.id);
const multi = { supportedFeatures: ['lobby-v1', 'multiplayer-v1'], supportedDecks: decks };
const lobbyOnly = { supportedFeatures: ['lobby-v1'], supportedDecks: decks };

function lobby(n, { now = () => 0 } = {}) {
  const engine = new GameEngine({ now, mismatchMs: 900, graceMs: 90_000 });
  const host = engine.create({ name: 'P0', theme: 'garden', pairs: 6, ...multi });
  const seats = [host];
  for (let i = 1; i < n; i++) seats.push(engine.join({ code: host.code, name: `P${i}`, ...multi }));
  return { engine, code: host.code, seats };
}

const startGame = ({ engine, code, seats }) => seats.forEach(s => engine.ready(code, s.playerId, true));

/// Flips two cards that do NOT match, as the player whose turn it is.
function missAs(engine, code, id) {
  const board = engine.room(code).board;
  const first = 0;
  const second = board.findIndex((v, i) => i !== first && v !== board[first]);
  engine.flip(code, id, first);
  engine.flip(code, id, second);
}

/// Flips a matching pair as `id`.
function matchAs(engine, code, id) {
  const room = engine.room(code);
  const free = room.board.map((_, i) => i).filter(i => !room.matched.includes(i));
  const a = free[0];
  const b = free.find(i => i !== a && room.board[i] === room.board[a]);
  engine.flip(code, id, a);
  engine.flip(code, id, b);
}

// ---- Plumbing (already passes) ------------------------------------------------

test('a multiplayer-v1 lobby seats up to eight players, the ninth is refused', () => {
  const { engine, code, seats } = lobby(8);
  assert.equal(engine.state(code).maxPlayers, 8);
  assert.equal(engine.state(code).players.length, 8);
  assert.equal(seats.length, 8);
  assert.throws(() => engine.join({ code, name: 'P8', ...multi }), { code: 'ROOM_FULL' });
});

test('rooms without multiplayer-v1 keep exactly two seats', () => {
  const engine = new GameEngine({});
  const host = engine.create({ name: 'A', theme: 'garden', pairs: 6, ...lobbyOnly });
  assert.equal(engine.state(host.code).maxPlayers, 2);
  engine.join({ code: host.code, name: 'B', ...lobbyOnly });
  assert.throws(() => engine.join({ code: host.code, name: 'C', ...lobbyOnly }), { code: 'ROOM_FULL' });
});

test('a lobby client without multiplayer-v1 cannot join or resume an eight-seat room', () => {
  const { engine, code } = lobby(2);
  assert.throws(() => engine.join({ code, name: 'Old', ...lobbyOnly }), { code: 'UPDATE_REQUIRED' });
});

test('the game starts only when every seated player is ready (minimum two)', () => {
  const ctx = lobby(4);
  const { engine, code, seats } = ctx;
  seats.slice(0, 3).forEach(s => engine.ready(code, s.playerId, true));
  assert.equal(engine.state(code).phase, 'waiting');
  engine.ready(code, seats[3].playerId, true);
  assert.equal(engine.state(code).phase, 'playing');
});

test('a guest leaving the lobby frees exactly that seat and resets readiness', () => {
  const { engine, code, seats } = lobby(4);
  engine.ready(code, seats[0].playerId, true);
  engine.leave(code, seats[2].playerId);
  const state = engine.state(code);
  assert.deepEqual(state.players.map(p => p.id), [seats[0].playerId, seats[1].playerId, seats[3].playerId]);
  assert.deepEqual(state.lobbyReady, []);
});

test('someone leaving mid-game: the rest play on; the last one standing wins by forfeit', () => {
  const ctx = lobby(3);
  const { engine, code, seats } = ctx;
  startGame(ctx);
  engine.leave(code, seats[2].playerId);
  assert.equal(engine.state(code).phase, 'playing');
  engine.leave(code, seats[1].playerId);
  const state = engine.state(code);
  assert.equal(state.phase, 'finished');
  assert.equal(state.finishReason, 'forfeit');
  assert.deepEqual(state.winnerIds, [seats[0].playerId]);
  assert.equal(state.winnerId, seats[0].playerId);
});

test('a player timing out mid-game is dropped and the others keep playing', () => {
  let now = 0;
  const ctx = lobby(3, { now: () => now });
  const { engine, code, seats } = ctx;
  startGame(ctx);
  engine.disconnect(code, seats[2].playerId);
  now += 90_001; engine.tick();
  const state = engine.state(code);
  assert.equal(state.phase, 'playing');
  assert.equal(engine.room(code).players.find(p => p.id === seats[2].playerId).left, true);
});

test('a rematch seats only the players who did not leave', () => {
  const ctx = lobby(3);
  const { engine, code, seats } = ctx;
  startGame(ctx);
  engine.leave(code, seats[2].playerId);
  // Finish the game by matching every pair as whoever holds the turn.
  while (engine.room(code).phase === 'playing') {
    matchAs(engine, code, engine.room(code).turn);
  }
  engine.rematch(code, seats[0].playerId);
  engine.rematch(code, seats[1].playerId);
  const state = engine.state(code);
  assert.equal(state.phase, 'playing');
  assert.deepEqual(state.players.map(p => p.id), [seats[0].playerId, seats[1].playerId]);
});

// ---- Core logic for you (these fail until you implement them) --------------------

test('CORE nextTurnPlayerId: turns rotate through all seats in order', () => {
  let now = 0;
  const ctx = lobby(4, { now: () => now });
  const { engine, code } = ctx;
  startGame(ctx);
  const order = [];
  for (let i = 0; i < 5; i++) {
    order.push(engine.room(code).turn);
    missAs(engine, code, engine.room(code).turn);
    // Let the mismatch timer elapse so tick() hands the turn over.
    now += 1_000;
    engine.tick();
  }
  const ids = engine.room(code).players.map(p => p.id);
  const start = ids.indexOf(order[0]);
  assert.deepEqual(order, Array.from({ length: 5 }, (_, i) => ids[(start + i) % 4]));
});

test('CORE nextTurnPlayerId: a player who left is skipped', () => {
  let now = 0;
  const ctx = lobby(3, { now: () => now });
  const { engine, code, seats } = ctx;
  startGame(ctx);
  const room = engine.room(code);
  const current = room.turn;
  const ids = room.players.map(p => p.id);
  const next = ids[(ids.indexOf(current) + 1) % 3];
  engine.leave(code, next); // leaves while it is not their turn; they must never get one
  missAs(engine, code, current);
  now += 1_000;
  engine.tick();
  assert.notEqual(engine.room(code).turn, next);
  assert.notEqual(engine.room(code).turn, current);
});

test('CORE nextTurnPlayerId: when the player on turn leaves, the turn moves on to a present player', () => {
  const ctx = lobby(3);
  const { engine, code } = ctx;
  startGame(ctx);
  const leaver = engine.room(code).turn;
  engine.leave(code, leaver);
  const turn = engine.room(code).turn;
  assert.notEqual(turn, leaver);
  assert.equal(engine.room(code).players.find(p => p.id === turn).left, false);
});

test('CORE winnersOf: the highest score wins, ties share the win', () => {
  const engine = new GameEngine({});
  const p = (id, score, left = false) => ({ id, score, left });
  assert.deepEqual(engine.winnersOf([p('a', 1), p('b', 3), p('c', 2)]), ['b']);
  assert.deepEqual(engine.winnersOf([p('a', 3), p('b', 3), p('c', 2)]).sort(), ['a', 'b']);
  assert.deepEqual(engine.winnersOf([p('a', 0), p('b', 0), p('c', 0)]).sort(), ['a', 'b', 'c']);
  assert.deepEqual(engine.winnersOf([p('a', 2, true), p('b', 1), p('c', 0)]), ['a']);
});
