import { EventEmitter } from 'node:events';
import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, renameSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { ARENA_CATALOG, buildDeckPool, drawRankedDecks } from './arenas.mjs';

export class GameError extends Error {
  constructor(code, message, { roomPreview } = {}) {
    super(message); this.code = code;
    if (roomPreview) this.roomPreview = roomPreview;
  }
}

const fail = (code, message, details) => { throw new GameError(code, message, details); };
const tokenHash = token => createHash('sha256').update(token).digest('hex');
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const themes = ['garden', 'cosmos', 'ocean', 'paola', 'food', 'sports', 'travel'];
const legacyThemes = ['garden', 'cosmos', 'ocean'];
// Only friendly lobbies hosted by a 'multiplayer-v1' client hold more than two seats.
const MAX_FRIENDLY_PLAYERS = 8;

export class GameEngine extends EventEmitter {
  constructor({ dataDir, now = Date.now, mismatchMs = 900, graceMs = 90_000,
    ttlMs = 86_400_000, maxRooms = 500, ownsDeck = (_id, theme) => ['garden', 'cosmos', 'ocean', 'paola'].includes(theme),
    onCompleted, onRankedSettlement, getProfile, catalog = ARENA_CATALOG } = {}) {
    super();
    this.catalog = catalog;
    this.rooms = new Map();
    this.now = now;
    this.mismatchMs = mismatchMs;
    this.graceMs = graceMs;
    this.ttlMs = ttlMs;
    this.maxRooms = maxRooms;
    this.ownsDeck = ownsDeck;
    this.onCompleted = onCompleted;
    this.onRankedSettlement = onRankedSettlement;
    this.getProfile = getProfile;
    this.pendingRewards = new Map();
    if (dataDir) {
      mkdirSync(dataDir, { recursive: true, mode: 0o700 });
      this.file = join(dataDir, 'rooms.json');
      if (existsSync(this.file)) {
        const stored = JSON.parse(readFileSync(this.file, 'utf8'));
        if (stored.version !== 1 || !Array.isArray(stored.rooms)) throw new Error('Unsupported room store');
        for (const room of stored.rooms) {
          // Recover an unpaid completed round even if its room TTL elapsed offline.
          // Do not persist through settleRewards until every stored room is loaded.
          if (room.phase === 'finished' && ((room.matchType === 'ranked' && this.onRankedSettlement) || (room.finishReason === 'completed' && this.onCompleted))) {
            try { room.rewards = room.matchType === 'ranked' ? this.onRankedSettlement(room) : this.onCompleted(room); }
            catch { this.pendingRewards.set(room.code, this.now() + 5000); }
          }
          if (this.now() - room.updatedAt >= ttlMs && !this.pendingRewards.has(room.code)) continue;
          for (const player of room.players) {
            // Preserve an existing deadline so repeated restarts cannot extend it.
            if (player.connected) player.disconnectedAt = this.now();
            player.connected = false;
          }
          this.rooms.set(room.code, room);
        }
        this.persist();
        this.tick();
      }
    }
  }

  persist() {
    if (!this.file) return;
    const tmp = `${this.file}.tmp`;
    writeFileSync(tmp, JSON.stringify({ version: 1, rooms: [...this.rooms.values()] }), { mode: 0o600 });
    renameSync(tmp, this.file);
  }

  change(room) {
    room.revision++;
    room.updatedAt = this.now();
    this.persist();
    this.settleRewards(room);
    this.emit('change', room.code);
  }

  settleRewards(room) {
    const settle = room.matchType === 'ranked' ? this.onRankedSettlement : room.finishReason === 'completed' ? this.onCompleted : null;
    if (room.phase !== 'finished' || !settle) return false;
    try {
      const rewards = settle(room);
      const changed = JSON.stringify(rewards) !== JSON.stringify(room.rewards ?? {});
      room.rewards = rewards;
      this.persist();
      this.pendingRewards.delete(room.code);
      return changed;
    } catch (error) {
      // A wallet outage must not conceal an already committed final game state.
      this.pendingRewards.set(room.code, this.now() + 5000);
      this.emit('rewardError', error);
      return false;
    }
  }

  name(input) {
    if (typeof input !== 'string') fail('INVALID_NAME', 'Inserisci il tuo nome.');
    const name = [...input.trim().replace(/[\p{C}]/gu, '')].slice(0, 24).join('');
    if (!name) fail('INVALID_NAME', 'Inserisci il tuo nome.');
    return name;
  }

  room(code) {
    if (typeof code !== 'string' || !/^[A-Z2-9]{6}$/.test(code.trim().toUpperCase())) {
      fail('ROOM_NOT_FOUND', 'Codice stanza non valido.');
    }
    const room = this.rooms.get(code.trim().toUpperCase());
    if (!room) fail('ROOM_NOT_FOUND', 'Questa stanza non esiste o è scaduta.');
    return room;
  }

  player(room, id) {
    const player = room.players.find(p => p.id === id && !p.left);
    if (!player) fail('NO_SESSION', 'Entra in una stanza per giocare.');
    return player;
  }

  newPlayer(name) {
    const token = randomBytes(32).toString('base64url');
    return { token, player: { id: randomBytes(12).toString('base64url'), name: this.name(name),
      score: 0, connected: true, disconnectedAt: null, left: false, tokenHash: tokenHash(token) } };
  }

  capabilities(supportedDecks) {
    const supported = supportedDecks === undefined ? legacyThemes : supportedDecks;
    if (!Array.isArray(supported) || supported.length > 64 ||
        supported.some(id => typeof id !== 'string' || !this.catalog.decks.some(deck => deck.id === id)) ||
        new Set(supported).size !== supported.length) {
      fail('INVALID_CAPABILITIES', 'Invia un elenco valido delle collezioni supportate.');
    }
    return supported;
  }

  assertSupported(theme, supportedDecks) {
    const supported = this.capabilities(supportedDecks);
    if (!supported.includes(theme)) fail('UPDATE_REQUIRED', 'Aggiorna SommoMemory per giocare con questa collezione.');
  }

  assertRankedSupport(supportedDecks, supportedFeatures, pool) {
    const supported = this.capabilities(supportedDecks);
    if (!Array.isArray(supportedFeatures) || !supportedFeatures.includes('ranked-v1') ||
        !supportedFeatures.includes('ranked-attempts-v1') || pool.some(id => !supported.includes(id)))
      fail('UPDATE_REQUIRED', 'Aggiorna SommoMemory per giocare in classificata.');
  }

  assertLobbySupport(room, supportedFeatures) {
    if (room.lobbyMode && (!Array.isArray(supportedFeatures) || !supportedFeatures.includes('lobby-v1')))
      fail('UPDATE_REQUIRED', 'Aggiorna SommoMemory per entrare in questa lobby.');
    // Older lobby clients only render two seats, so they must not sit in a bigger room.
    if (this.capacity(room) > 2 && !supportedFeatures?.includes('multiplayer-v1'))
      fail('UPDATE_REQUIRED', 'Aggiorna SommoMemory per entrare in questa lobby.');
  }

  /// Seats in a room. Rooms stored before multiplayer have no `maxPlayers`.
  capacity(room) {
    return room.maxPlayers ?? 2;
  }

  /// Players still in the match: seated, and not gone via leave or timeout.
  activePlayers(room) {
    return room.players.filter(p => !p.left);
  }

  /// TODO(Michele): CORE LOGIC — whose turn comes after `room.turn`?
  /// Called when a mismatch closes (and when the current player drops out).
  /// Must return a player id. Rules so far: seats rotate in `room.players`
  /// order, players with `left === true` are skipped, a match keeps the turn
  /// (that case never reaches here). Open question for you: should a player
  /// who is merely disconnected (not left) be skipped too?
  /// Placeholder: correct for 2 players only, so the 3+ player tests fail.
  nextTurnPlayerId(room) {
    const { players } = room;
    const from = players.findIndex(p => p.id === room.turn);
    for (let step = 1; step <= players.length; step++) {
      const candidate = players[(from + step) % players.length];
      if (!candidate.left) return candidate.id;
    }
    return room.turn;
  }

  /// TODO(Michele): CORE LOGIC — which player ids won a completed friendly game?
  /// Return every id sharing the top score (ties = several ids, nobody = []).
  /// Players who left stay in the ranking with the points they scored.
  /// Placeholder: correct for 2 players only, so the 3+ player tests fail.
  winnersOf(players) {
    const best = Math.max(...players.map(p => p.score));
    return players.filter(p => p.score === best).map(p => p.id);
  }

  rankedSetup(room, hostPlayer, guestPlayer, draw = false) {
    const host = this.rankedProfile(hostPlayer.profileId, room);
    const guest = this.rankedProfile(guestPlayer.profileId, room);
    if (host.id === guest.id) fail('SAME_PROFILE', 'Servono due profili distinti.');
    if (host.currentArenaId !== room.arenaId || guest.currentArenaId !== room.arenaId)
      fail('ARENA_MISMATCH', 'I profili devono essere nella stessa arena.');
    const pool = buildDeckPool(room.arenaId, host.ownedDecks, guest.ownedDecks, this.catalog);
    this.assertRankedSupport(hostPlayer.supportedDecks, hostPlayer.supportedFeatures, pool);
    this.assertRankedSupport(guestPlayer.supportedDecks, guestPlayer.supportedFeatures, pool);
    if (!draw) return null;
    const roundDecks = drawRankedDecks(room.arenaId, host.ownedDecks, guest.ownedDecks, this.catalog);
    return { roundDecks, rankedPool: pool, roundIndex: 1, roundResults: [], starter: randomInt(2), theme: roundDecks[0] };
  }

  rankedProfile(id, excluding) {
    if (!id || !this.getProfile) fail('PROFILE_REQUIRED', 'Accedi con un profilo per giocare in classificata.');
    const profile = this.getProfile(id);
    for (const room of this.rooms.values()) {
      if (room === excluding || room.matchType !== 'ranked' || !room.matchId) continue;
      if ((room.phase !== 'finished' || this.pendingRewards.has(room.code)) && room.players.some(p => p.profileId === id))
        fail('RANKED_BUSY', 'Questo profilo ha già una partita classificata in corso.');
    }
    return profile;
  }

  roomPreview(room) {
    return { code: room.code, phase: room.phase,
      players: room.players.map(({ id, name, score, connected }) => ({ id, name, score, connected })),
      winnerId: room.winnerId, winnerIds: room.winnerIds ?? (room.winnerId ? [room.winnerId] : []),
      finishReason: room.finishReason };
  }

  preview({ code }) {
    this.tick();
    const room = this.room(code);
    if (room.players.length < 2 || !['playing', 'roundFinished', 'finished'].includes(room.phase))
      fail('ROOM_NOT_FOUND', 'Questa anteprima non è disponibile.');
    return this.roomPreview(room);
  }

  create({ name, pairs = 8, theme = 'garden', profileId, supportedDecks, supportedFeatures, matchType = 'friendly', arenaId }) {
    this.tick();
    if (!['friendly', 'ranked'].includes(matchType)) fail('INVALID_OPTIONS', 'Modalità non valida.');
    if (matchType === 'ranked') {
      if (!this.catalog.rankedEnabled) fail('RANKED_DISABLED', 'La classificata non è ancora disponibile.');
      const profile = this.rankedProfile(profileId);
      if (arenaId !== profile.currentArenaId) fail('ARENA_MISMATCH', 'La tua arena è cambiata.');
      if (this.catalog.decks.filter(deck => deck.arenaId === arenaId && deck.price === 0 && deck.contentReady).length < 3)
        fail('RANKED_UNAVAILABLE', 'Questa arena non è ancora pronta per la classificata.');
      this.assertRankedSupport(supportedDecks, supportedFeatures, buildDeckPool(arenaId, profile.ownedDecks, [], this.catalog));
      pairs = 12;
    } else if (![6, 8, 12, 18].includes(pairs) || !this.catalog.decks.some(d => d.id === theme && d.contentReady)) {
      fail('INVALID_OPTIONS', 'Scegli un tema e una difficoltà validi.');
    }
    if (matchType === 'friendly') {
      this.assertSupported(theme, supportedDecks);
      if (!this.ownsDeck(profileId, theme)) fail('DECK_LOCKED', 'Sblocca questa collezione prima di ospitare la partita.');
      arenaId = this.catalog.decks.find(deck => deck.id === theme).arenaId;
    }
    if (this.rooms.size >= this.maxRooms) fail('SERVER_FULL', 'Il servizio è occupato. Riprova tra poco.');
    const { player, token } = this.newPlayer(name);
    if (profileId) player.profileId = profileId;
    player.supportedDecks = supportedDecks;
    player.supportedFeatures = supportedFeatures;
    let code;
    do { code = Array.from({ length: 6 }, () => alphabet[randomInt(alphabet.length)]).join(''); }
    while (this.rooms.has(code));
    const room = { code, pairs, theme, phase: 'waiting', players: [player], board: [],
      matched: [], selected: [], turn: null, starter: 0, revision: 0, rematch: [],
      lockedUntil: null, winnerId: null, finishReason: null, createdAt: this.now(), updatedAt: this.now(), matchType, arenaId: arenaId ?? null,
      lobbyMode: Array.isArray(supportedFeatures) && supportedFeatures.includes('lobby-v1'), lobbyReady: [] };
    room.maxPlayers = matchType === 'friendly' && room.lobbyMode && supportedFeatures.includes('multiplayer-v1')
      ? MAX_FRIENDLY_PLAYERS : 2;
    if (matchType === 'ranked') room.matchId = randomBytes(24).toString('base64url');
    this.rooms.set(code, room);
    this.change(room);
    return { code, token, playerId: player.id };
  }

  join({ code, name, profileId, supportedDecks, supportedFeatures }) {
    this.tick();
    const room = this.room(code);
    this.capabilities(supportedDecks);
    this.assertLobbySupport(room, supportedFeatures);
    // Full-room previews contain no card/theme data and need no rendering support.
    if (room.phase !== 'waiting' || room.players.length >= this.capacity(room))
      fail('ROOM_FULL', 'La stanza è già al completo.', { roomPreview: this.roomPreview(room) });
    const { player, token } = this.newPlayer(name);
    if (profileId) player.profileId = profileId;
    player.supportedDecks = supportedDecks;
    player.supportedFeatures = supportedFeatures;
    let rankedStart;
    if (room.matchType === 'ranked') rankedStart = this.rankedSetup(room, room.players[0], player, !room.lobbyMode);
    else this.assertSupported(room.theme, supportedDecks);
    if (rankedStart) Object.assign(room, rankedStart);
    room.players.push(player);
    if (!room.lobbyMode) this.start(room);
    this.change(room);
    return { code: room.code, token, playerId: player.id };
  }

  start(room) {
    if (room.matchType !== 'ranked' || room.roundIndex === 1) room.matchStartedAt = this.now();
    room.finishedAt = null;
    room.roundId = randomBytes(24).toString('base64url');
    room.rewards = {};
    const values = Array.from({ length: room.matchType === 'ranked' ? 18 : room.pairs }, (_, i) => String(i));
    if (room.matchType === 'ranked') for (let i = values.length - 1; i > 0; i--) {
      const j = randomInt(i + 1); [values[i], values[j]] = [values[j], values[i]];
    }
    room.board = [...values.slice(0, room.pairs), ...values.slice(0, room.pairs)];
    for (let i = room.board.length - 1; i > 0; i--) {
      const j = randomInt(i + 1);
      [room.board[i], room.board[j]] = [room.board[j], room.board[i]];
    }
    room.players.forEach(p => {
      p.score = 0;
      if (room.matchType === 'ranked') p.individual = { matched: [], selected: [], lockedUntil: null, attempts: 0 };
    });
    room.phase = 'playing';
    room.turn = room.matchType === 'ranked' ? null : room.players[room.starter].id;
    room.matched = [];
    room.selected = [];
    room.rematch = [];
    room.lockedUntil = null;
    room.winnerId = null;
    room.finishReason = null;
  }

  resume({ code, token, supportedDecks, supportedFeatures }) {
    this.tick();
    const room = this.room(code);
    this.assertLobbySupport(room, supportedFeatures);
    if (room.matchType === 'ranked') this.assertRankedSupport(supportedDecks, supportedFeatures, room.rankedPool ?? []);
    else this.assertSupported(room.theme, supportedDecks);
    if (typeof token !== 'string' || token.length > 128) fail('INVALID_SESSION', 'Sessione non valida.');
    const hash = Buffer.from(tokenHash(token), 'hex');
    const player = room.players.find(p => !p.left && timingSafeEqual(Buffer.from(p.tokenHash, 'hex'), hash));
    if (!player) fail('INVALID_SESSION', 'La sessione è scaduta. Crea o raggiungi una nuova stanza.');
    player.supportedDecks = supportedDecks;
    player.supportedFeatures = supportedFeatures;
    player.connected = true;
    player.disconnectedAt = null;
    this.change(room);
    return { code: room.code, token, playerId: player.id };
  }

  disconnect(code, id) {
    const room = this.rooms.get(code);
    if (!room) return;
    const player = room.players.find(p => p.id === id && !p.left);
    if (!player || !player.connected) return;
    player.connected = false;
    player.disconnectedAt = this.now();
    if (room.lobbyMode && room.phase === 'waiting') room.lobbyReady = [];
    this.change(room);
  }

  ready(code, id, ready) {
    this.tick();
    const room = this.room(code);
    this.player(room, id);
    if (!room.lobbyMode || room.phase !== 'waiting') fail('NOT_IN_LOBBY', 'La lobby non è disponibile.');
    if (typeof ready !== 'boolean') fail('INVALID_OPTIONS', 'Scegli se sei pronto.');
    const votes = new Set(room.lobbyReady ?? []);
    if (ready) votes.add(id); else votes.delete(id);
    if (room.players.length >= 2 && room.players.every(p => p.connected && votes.has(p.id))) {
      if (room.matchType === 'ranked') Object.assign(room, this.rankedSetup(room, room.players[0], room.players[1], true));
      else {
        if (!this.ownsDeck(room.players[0].profileId, room.theme)) fail('DECK_LOCKED', 'Il profilo dell’host deve possedere questa collezione.');
        for (const player of room.players) this.assertSupported(room.theme, player.supportedDecks);
      }
      room.lobbyReady = [...votes];
      this.start(room);
    } else room.lobbyReady = [...votes];
    this.change(room);
  }

  flip(code, id, index) {
    this.tick();
    const room = this.room(code);
    const player = this.player(room, id);
    if (room.phase !== 'playing') fail('NOT_PLAYING', 'La partita non è in corso.');
    if (this.activePlayers(room).some(p => !p.connected)) fail('OPPONENT_OFFLINE', 'Attendi che l’altro giocatore si ricolleghi.');
    if (room.matchType === 'ranked') {
      const board = player.individual;
      if (!board || board.matched.length === room.board.length) fail('ROUND_COMPLETE', 'Hai completato questo round.');
      if (board.lockedUntil !== null) fail('BOARD_LOCKED', 'Aspetta che le carte si richiudano.');
      if (!Number.isInteger(index) || index < 0 || index >= room.board.length || board.matched.includes(index) || board.selected.includes(index))
        fail('INVALID_CARD', 'Questa carta non è disponibile.');
      board.selected.push(index);
      if (board.selected.length === 2) {
        board.attempts++;
        const [first, second] = board.selected;
        if (room.board[first] === room.board[second]) {
          board.matched.push(first, second); board.selected = []; player.score++;
          if (room.players.every(p => p.individual.matched.length === room.board.length)) this.finishRound(room);
        } else board.lockedUntil = this.now() + this.mismatchMs;
      }
      this.change(room);
      return;
    }
    if (room.turn !== id) fail('NOT_YOUR_TURN', 'Aspetta il tuo turno.');
    if (room.lockedUntil !== null) fail('BOARD_LOCKED', 'Aspetta che le carte si richiudano.');
    if (!Number.isInteger(index) || index < 0 || index >= room.board.length ||
        room.matched.includes(index) || room.selected.includes(index)) {
      fail('INVALID_CARD', 'Questa carta non è disponibile.');
    }
    room.selected.push(index);
    if (room.selected.length === 2) {
      const [first, second] = room.selected;
      if (room.board[first] === room.board[second]) {
        room.matched.push(first, second);
        room.selected = [];
        player.score++;
        if (room.matched.length === room.board.length) {
          if (room.matchType === 'ranked') this.finishRound(room);
          else this.finish(room, 'completed');
        }
      } else room.lockedUntil = this.now() + this.mismatchMs;
    }
    this.change(room);
  }

  finishRound(room) {
    const [a, b] = room.players;
    room.roundResults.push({ round: room.roundIndex, theme: room.theme,
      scores: { [a.id]: a.score, [b.id]: b.score },
      attempts: { [a.id]: a.individual.attempts, [b.id]: b.individual.attempts },
      winnerId: a.individual.attempts === b.individual.attempts ? null : a.individual.attempts < b.individual.attempts ? a.id : b.id });
    if (room.roundIndex === 3) {
      const totals = this.totalAttempts(room, false);
      this.finish(room, 'completed', totals[a.id] === totals[b.id] ? null : totals[a.id] < totals[b.id] ? a.id : b.id);
      if (totals[a.id] === totals[b.id]) room.winnerId = null;
    } else {
      room.phase = 'roundFinished';
      room.turn = null;
      room.lockedUntil = null;
      room.roundReady = [];
      room.selected = [];
    }
  }

  totalAttempts(room, includeCurrent = true) {
    const totals = Object.fromEntries(room.players.map(p => [p.id, 0]));
    for (const result of room.roundResults ?? []) for (const [id, attempts] of Object.entries(result.attempts ?? {})) totals[id] += attempts;
    if (includeCurrent && (room.roundResults?.length ?? 0) < (room.roundIndex ?? 0))
      for (const player of room.players) totals[player.id] += player.individual?.attempts ?? 0;
    return totals;
  }

  totalScores(room, includeCurrent = true) {
    const totals = Object.fromEntries(room.players.map(p => [p.id, 0]));
    for (const result of room.roundResults ?? []) for (const [id, score] of Object.entries(result.scores)) totals[id] += score;
    if (includeCurrent && (room.roundResults?.length ?? 0) < (room.roundIndex ?? 0))
      for (const player of room.players) totals[player.id] += player.score;
    return totals;
  }

  nextRound(code, id) {
    this.tick();
    const room = this.room(code);
    this.player(room, id);
    if (room.matchType !== 'ranked' || room.phase !== 'roundFinished') fail('NOT_READY', 'Il prossimo round non è disponibile.');
    if (room.players.some(p => !p.connected || p.left)) fail('OPPONENT_OFFLINE', 'L’altro giocatore deve essere nella stanza.');
    if (!room.roundReady.includes(id)) room.roundReady.push(id);
    if (room.roundReady.length === 2) {
      room.roundIndex++;
      room.theme = room.roundDecks[room.roundIndex - 1];
      room.starter = 1 - room.starter;
      room.roundReady = [];
      this.start(room);
    }
    this.change(room);
  }

  finish(room, reason, winnerId) {
    room.phase = 'finished';
    room.finishedAt = this.now();
    room.turn = null;
    room.lockedUntil = null;
    room.selected = [];
    room.finishReason = reason;
    room.rematch = [];
    // `winnerId` undefined = decide by score; null = explicitly nobody (ranked draw).
    room.winnerIds = reason === 'cancelled' ? [] : winnerId === undefined ? this.winnersOf(room.players) : winnerId ? [winnerId] : [];
    // Legacy field: set only for a single winner, so old clients still read "draw" on shared wins.
    room.winnerId = room.winnerIds.length === 1 ? room.winnerIds[0] : null;
  }

  rematch(code, id) {
    this.tick();
    const room = this.room(code);
    this.player(room, id);
    if (room.phase !== 'finished') fail('NOT_FINISHED', 'Completa prima questa partita.');
    if (this.pendingRewards.has(room.code)) fail('REWARD_PENDING', 'Il premio è in elaborazione. Riprova tra poco.');
    if (room.matchType !== 'ranked' && !this.ownsDeck(room.players[0].profileId, room.theme)) fail('DECK_LOCKED', 'Il profilo dell’host deve possedere questa collezione.');
    const active = this.activePlayers(room);
    if (active.length < 2 || active.some(p => !p.connected) || (room.matchType === 'ranked' && room.players.some(p => p.left)))
      fail('OPPONENT_OFFLINE', 'L’altro giocatore deve essere nella stanza.');
    let rankedProfiles, rankedPool;
    if (room.matchType === 'ranked') {
      rankedProfiles = room.players.map(p => this.rankedProfile(p.profileId, room));
      if (rankedProfiles.some(p => p.currentArenaId !== room.arenaId)) fail('ARENA_MISMATCH', 'I profili devono essere nella stessa arena.');
      rankedPool = buildDeckPool(room.arenaId, rankedProfiles[0].ownedDecks, rankedProfiles[1].ownedDecks, this.catalog);
      for (const player of room.players) this.assertRankedSupport(player.supportedDecks, player.supportedFeatures, rankedPool);
    }
    if (!room.rematch.includes(id)) room.rematch.push(id);
    if (active.every(p => room.rematch.includes(p.id))) {
      room.players = active; // players who left the previous game do not get a seat in the next
      if (room.matchType === 'ranked') {
        room.matchId = randomBytes(24).toString('base64url');
        room.roundDecks = drawRankedDecks(room.arenaId, rankedProfiles[0].ownedDecks, rankedProfiles[1].ownedDecks, this.catalog);
        room.rankedPool = rankedPool;
        room.roundIndex = 1; room.roundResults = []; room.roundReady = [];
        room.theme = room.roundDecks[0]; room.starter = randomInt(2);
      } else room.starter = (room.starter + 1) % room.players.length;
      this.start(room);
    }
    this.change(room);
  }

  /// A player stops taking part mid-game: leave, or a timeout once the grace period ends.
  /// Callers handle the "fewer than two left" case before calling this.
  dropFromPlay(room, player) {
    player.left = true;
    if (room.turn !== player.id) return;
    // Cards the leaver had turned up must not stay half-selected for the next player.
    room.selected = [];
    room.lockedUntil = null;
    room.turn = this.nextTurnPlayerId(room);
  }

  leave(code, id) {
    const room = this.rooms.get(code);
    if (!room) return;
    const player = this.player(room, id);
    player.left = true;
    player.connected = false;
    player.disconnectedAt = this.now();
    player.tokenHash = tokenHash(randomBytes(32));
    if (room.lobbyMode && room.phase === 'waiting' && room.players[0].id !== id) {
      this.removeLobbyGuest(room, player);
      return;
    }
    if (room.phase === 'waiting' || (room.players.every(p => p.left) && !this.pendingRewards.has(room.code) && room.matchType !== 'ranked')) {
      this.remove(room.code);
    } else {
      if (['playing', 'roundFinished'].includes(room.phase)) {
        const remaining = this.activePlayers(room).filter(p => p.id !== id);
        // Others carry on while at least two remain; the last one standing wins by forfeit.
        if (remaining.length >= 2) this.dropFromPlay(room, player);
        else this.finish(room, 'forfeit', remaining[0].id);
      }
      room.rematch = [];
      this.change(room);
    }
  }

  removeLobbyGuest(room, guest) {
    if (!guest || !room.players.includes(guest)) return;
    room.players = room.players.filter(p => p !== guest);
    room.lobbyReady = [];
    delete room.roundDecks;
    delete room.rankedPool;
    this.emit('seatRemoved', room.code, guest.id);
    this.change(room);
  }

  remove(code) {
    this.rooms.delete(code);
    this.pendingRewards.delete(code);
    this.persist();
    this.emit('removed', code);
  }

  detachProfile(profileId) {
    // Room credentials are independent of account credentials: keep the board
    // playable, but remove the account association and its chosen display name.
    const changed = [];
    for (const room of [...this.rooms.values()]) {
      let dirty = false;
      if (room.matchType === 'ranked' && room.phase === 'waiting' && room.players.some(p => p.profileId === profileId)) {
        if (room.lobbyMode && room.players[1]?.profileId === profileId) this.removeLobbyGuest(room, room.players[1]);
        else this.remove(room.code);
        continue;
      }
      if (room.matchType === 'ranked' && room.players.some(p => p.profileId === profileId) && room.phase !== 'finished' && room.phase !== 'waiting') {
        this.finish(room, 'cancelled');
        room.winnerId = null;
        this.change(room);
      }
      for (const player of room.players) {
        if (player.profileId !== profileId) continue;
        delete player.profileId;
        player.name = 'Giocatore';
        dirty = true;
      }
      if (dirty) {
        room.revision++;
        changed.push(room.code);
      }
    }
    if (!changed.length) return;
    this.persist();
    for (const code of changed) this.emit('change', code);
  }

  tick() {
    const now = this.now();
    for (const room of [...this.rooms.values()]) {
      if (this.pendingRewards.has(room.code)) {
        if (now >= this.pendingRewards.get(room.code) && this.settleRewards(room)) {
          room.revision++;
          this.persist();
          this.emit('change', room.code);
        }
        if (this.pendingRewards.has(room.code)) continue;
      }
      if (now - room.updatedAt >= this.ttlMs && (room.matchType !== 'ranked' || ['finished', 'waiting'].includes(room.phase))) { this.remove(room.code); continue; }
      if (room.phase !== 'finished') {
        // Players who already left are settled; only fresh timeouts are handled here.
        const expired = room.players.filter(p => !p.left && !p.connected && now - p.disconnectedAt >= this.graceMs);
        if (expired.length > 0) {
          if (room.lobbyMode && room.phase === 'waiting') {
            if (expired.includes(room.players[0])) this.remove(room.code);
            else for (const guest of expired) this.removeLobbyGuest(room, guest);
            continue;
          }
          const survivors = this.activePlayers(room).filter(p => !expired.includes(p));
          if (room.matchType !== 'ranked' && room.phase === 'playing' && survivors.length >= 2) {
            // Big friendly game: the timed-out players drop out and the rest keep playing.
            for (const player of expired) this.dropFromPlay(room, player);
            this.change(room);
            continue;
          }
          if (room.matchType === 'ranked' && room.players.length === 2 && room.players.every(p => !p.connected) && expired.length < 2) continue;
          if (room.players.length === 1 || (survivors.length === 0 && room.matchType !== 'ranked')) this.remove(room.code);
          else if (survivors.length === 0) {
            this.finish(room, 'cancelled'); room.winnerId = null; this.change(room);
          }
          else {
            expired.forEach(p => { p.left = true; });
            this.finish(room, 'forfeit', survivors[0].id);
            this.change(room);
          }
          continue;
        }
      }
      if (room.matchType === 'ranked' && room.phase === 'playing') {
        let changed = false;
        for (const player of room.players) {
          const board = player.individual;
          if (board?.lockedUntil !== null && board?.lockedUntil !== undefined && now >= board.lockedUntil) {
            board.selected = []; board.lockedUntil = null; changed = true;
          }
        }
        if (changed) this.change(room);
      }
      if (room.lockedUntil !== null && now >= room.lockedUntil) {
        room.selected = [];
        room.lockedUntil = null;
        room.turn = this.nextTurnPlayerId(room);
        this.change(room);
      }
    }
  }

  state(code, playerId) {
    const room = this.room(code);
    const individual = room.matchType === 'ranked' ? room.players.find(p => p.id === playerId)?.individual : null;
    const matched = room.matchType === 'ranked' ? individual?.matched ?? [] : room.matched;
    const selected = room.matchType === 'ranked' ? individual?.selected ?? [] : room.selected;
    return { type: 'state', code: room.code, pairs: room.pairs, theme: room.theme,
      roundId: room.roundId ?? null,
      rewards: room.rewards ?? {},
      phase: room.phase, turn: room.turn,
      cards: Array.from({ length: room.pairs * 2 }, (_, i) =>
        matched.includes(i) || selected.includes(i) ? room.board[i] : null),
      matched: [...matched], selected: [...selected],
      players: room.players.map(({ id, name, score, connected, left, individual: board }) => ({ id, name, score, connected, left: Boolean(left),
        ...(room.matchType === 'ranked' ? { attempts: board?.attempts ?? 0, roundComplete: Boolean(board && board.matched.length === room.board.length && room.board.length) } : {}) })),
      revision: room.revision, rematch: [...room.rematch], lockedUntil: room.matchType === 'ranked' ? individual?.lockedUntil ?? null : room.lockedUntil,
      winnerId: room.winnerId, winnerIds: room.winnerIds ?? (room.winnerId ? [room.winnerId] : []),
      finishReason: room.finishReason, maxPlayers: this.capacity(room),
      matchType: room.matchType ?? 'friendly', arenaId: room.arenaId ?? null, matchId: room.matchId ?? room.roundId ?? null,
      roundIndex: room.roundIndex ?? 1, roundCount: room.matchType === 'ranked' ? 3 : 1,
      roundDecks: room.roundDecks ?? (room.lobbyMode && room.phase === 'waiting' ? [] : [room.theme]), roundResults: room.roundResults ?? [],
      totalScores: room.matchType === 'ranked' ? this.totalScores(room) : Object.fromEntries(room.players.map(p => [p.id, p.score])),
      totalAttempts: room.matchType === 'ranked' ? this.totalAttempts(room) : {},
      roundReady: room.roundReady ?? [], lobbyMode: Boolean(room.lobbyMode), lobbyReady: room.lobbyReady ?? [] };
  }
}
