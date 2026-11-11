import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { dirname, extname, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';
import { GameEngine, GameError } from './game.mjs';
import { createVoiceRelay, VoiceError } from './voice.mjs';
import { EconomyStore, EconomyError } from './economy.mjs';
import { economyApi } from './economy-http.mjs';
import { createAuthService } from './auth.mjs';
import { createAdminService } from './admin.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.woff2': 'font/woff2',
  '.ttf': 'font/ttf', '.wav': 'audio/wav', '.bin': 'application/octet-stream' };

export function startServer({ port = Number(process.env.PORT || 8787), host = process.env.HOST || '127.0.0.1',
  dataDir = process.env.DATA_DIR || resolve(here, '../data'),
  webDir = process.env.WEB_DIR || resolve(here, '../../app/build/web'),
  allowedOrigins = process.env.ALLOWED_ORIGINS || 'https://sommomemory.sommomi.cc,http://localhost:8080,http://127.0.0.1:8080',
  trustProxy = process.env.TRUST_PROXY === '1', engine: providedEngine, economy: providedEconomy,
  authConfig, verifyIdentity, adminConfig } = {}) {
  const economy = providedEconomy || new EconomyStore({ dataDir });
  const engine = providedEngine || new GameEngine({ dataDir,
    ownsDeck: (id, theme) => economy.ownsDeck(id, theme), onCompleted: room => economy.rewardOnline(room),
    getProfile: id => economy.profile(id), onRankedSettlement: room => economy.settleRanked(room) });
  if (providedEngine) {
    engine.ownsDeck = (id, theme) => economy.ownsDeck(id, theme);
    engine.onCompleted = room => economy.rewardOnline(room);
    engine.getProfile = id => economy.profile(id);
    engine.onRankedSettlement = room => economy.settleRanked(room);
    for (const room of engine.rooms.values()) engine.settleRewards(room);
  }
  const orphanProfiles = new Set([...engine.rooms.values()].flatMap(room =>
    room.players.map(player => player.profileId).filter(id => id && !economy.hasProfile(id))));
  for (const id of orphanProfiles) engine.detachProfile(id);
  engine.on('rewardError', error => console.error('Completion reward pending:', error.message));
  const sockets = new Map();
  const byAddress = new Map();
  const origins = new Set(allowedOrigins.split(',').map(s => s.trim()));
  const addressOf = req => trustProxy && req.headers['x-forwarded-for'] ?
    String(req.headers['x-forwarded-for']).split(',')[0].trim() : req.socket.remoteAddress;
  const auth = createAuthService({ store: economy, config: authConfig, verifyIdentity,
    onProfileDeleted: id => engine.detachProfile(id) });
  const admin = createAdminService({ store: economy, engine, dataDir, addressOf, connections: () => wss.clients.size, config: adminConfig });
  const api = economyApi({ store: economy, origins, addressOf, auth });
  const send = (ws, value) => {
    if (ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 256 * 1024) ws.send(JSON.stringify(value));
    else if (ws.bufferedAmount >= 256 * 1024) ws.terminate();
  };
  const sessionsFor = code => [...sockets.values()].filter(s => s.code === code);
  const voice = createVoiceRelay();
  const seatOf = new WeakMap();
  const publishVoice = code => {
    const message = voice.stateMessage(code);
    for (const session of sessionsFor(code)) send(session.ws, message);
  };
  const relayVoice = (code, playerId, message) => {
    const room = engine.room(code);
    const result = voice.handle(code, playerId, message, room.players.map(player => player.id));
    if (result.broadcast) publishVoice(code);
    if (result.relay) {
      const target = sessionsFor(code).find(session => session.playerId === result.relay.to);
      if (target) send(target.ws, result.relay.message);
    }
  };

  const http = createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Permissions-Policy', 'camera=(), microphone=(self), geolocation=()');
    let pathname;
    try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
    catch { res.writeHead(400); res.end(); return; }
    if (await admin.handle(req, res, pathname)) return;
    if (await auth.handle(req, res, pathname, { origins, addressOf })) return;
    if (pathname === '/api/v1' || pathname.startsWith('/api/v1/')) { await api(req, res, pathname); return; }
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); res.end(); return; }
    if (pathname === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify({ ok: true, service: 'mymemory', protocol: 1, rooms: engine.rooms.size }));
      return;
    }
    let path;
    const associations = {
      '/.well-known/apple-app-site-association': 'apple-app-site-association',
      '/apple-app-site-association': 'apple-app-site-association',
      '/.well-known/assetlinks.json': 'assetlinks.json',
    };
    if (Object.hasOwn(associations, pathname)) {
      path = resolve(here, '../public/.well-known', associations[pathname]);
      if (!existsSync(path)) { res.writeHead(404); res.end('Not found'); return; }
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'public, max-age=3600' });
      if (req.method === 'HEAD') res.end(); else createReadStream(path).on('error', () => res.destroy()).pipe(res);
      return;
    } else if (['/delete-account', '/delete-account/', '/en/delete-account', '/en/delete-account/'].includes(pathname)) {
      path = resolve(here, pathname.startsWith('/en/') ? '../public/en/delete-account.html' : '../public/delete-account.html');
      res.setHeader('Referrer-Policy', 'no-referrer');
      res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");
    } else if (pathname === '/account-deletion.js' || pathname === '/en/account-deletion.js') {
      path = resolve(here, pathname.startsWith('/en/') ? '../public/en/account-deletion.js' : '../public/account-deletion.js');
    } else if (['/privacy', '/privacy/', '/support', '/support/', '/en/privacy', '/en/privacy/', '/en/support', '/en/support/'].includes(pathname)) {
      path = resolve(here, pathname.startsWith('/en/') ? '../public/en' : '../public', pathname.includes('privacy') ? 'privacy.html' : 'support.html');
    } else {
      path = resolve(webDir, `.${pathname}`);
      if (path !== resolve(webDir) && !path.startsWith(resolve(webDir) + sep)) { res.writeHead(403); res.end(); return; }
      if (existsSync(path) && statSync(path).isDirectory()) path = resolve(path, 'index.html');
      if (!existsSync(path) && !extname(pathname)) path = resolve(webDir, 'index.html');
    }
    if (!existsSync(path) || !statSync(path).isFile()) { res.writeHead(404); res.end('Not found'); return; }
    res.writeHead(200, { 'Content-Type': mime[extname(path)] || 'application/octet-stream',
      'Cache-Control': path.endsWith('/delete-account.html') ? 'no-store' :
        ['.html', '.js', '.mjs', '.json'].includes(extname(path)) ? 'no-cache' : 'public, max-age=3600' });
    if (req.method === 'HEAD') res.end();
    else createReadStream(path).on('error', () => res.destroy()).pipe(res);
  });
  const wss = new WebSocketServer({ noServer: true, maxPayload: 16384, perMessageDeflate: false });
  http.on('upgrade', (req, socket, head) => {
    const origin = req.headers.origin;
    const path = req.url?.split('?')[0];
    if (path !== '/ws' || (origin && !origins.has(origin))) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
    }
    const address = addressOf(req);
    if ((byAddress.get(address) || 0) >= 32) {
      socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n'); return;
    }
    wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, req, address));
  });

  engine.on('change', code => {
    for (const { ws, playerId } of sessionsFor(code)) send(ws, engine.state(code, playerId));
  });
  engine.on('removed', code => {
    voice.forgetRoom(code);
    for (const session of sessionsFor(code)) {
      sockets.delete(session.ws);
      send(session.ws, { type: 'error', code: 'ROOM_EXPIRED', message: 'La stanza è scaduta. Crea una nuova partita.' });
      send(session.ws, { type: 'left' });
    }
  });
  engine.on('seatRemoved', (code, playerId) => {
    if (voice.drop(code, playerId)) publishVoice(code);
    for (const session of sessionsFor(code).filter(s => s.playerId === playerId)) {
      sockets.delete(session.ws);
      send(session.ws, { type: 'error', code: 'NO_SESSION', message: 'Il posto nella lobby non è più disponibile.' });
      send(session.ws, { type: 'left' });
    }
  });

  wss.on('connection', (ws, req, address) => {
    byAddress.set(address, (byAddress.get(address) || 0) + 1);
    ws.alive = true;
    ws.on('pong', () => { ws.alive = true; });
    let windowStart = Date.now(), count = 0;
    ws.on('message', (raw, isBinary) => {
      if (Date.now() - windowStart > 10_000) { windowStart = Date.now(); count = 0; }
      if (++count > 120) { ws.close(1008, 'Rate limit'); return; }
      try {
        if (isBinary) throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.');
        let message;
        try { message = JSON.parse(raw.toString()); }
        catch { throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.'); }
        if (!message || typeof message !== 'object' || Array.isArray(message)) {
          throw new GameError('INVALID_MESSAGE', 'Invia un messaggio valido.');
        }
        const current = sockets.get(ws);
        if (['create', 'join', 'resume'].includes(message.type)) {
          if (current) throw new GameError('ALREADY_JOINED', 'Esci prima dalla partita attuale.');
          // Never accept a client-supplied profile ID or relay account tokens.
          const profileId = message.type !== 'resume' && message.profileToken !== undefined ?
            economy.authenticate(message.profileToken) : undefined;
          const session = engine[message.type]({ ...message, profileId });
          const previous = [...sockets.values()].find(s => s.code === session.code && s.playerId === session.playerId);
          if (previous) {
            sockets.delete(previous.ws);
            previous.ws.close(4001, 'Session resumed on another connection');
          }
          sockets.set(ws, { ws, ...session });
          seatOf.set(ws, { code: session.code, playerId: session.playerId });
          economy.markActive(engine.room(session.code).players.find(p => p.id === session.playerId)?.profileId);
          send(ws, { type: 'session', ...session });
          send(ws, engine.state(session.code, session.playerId));
          const voiceSnapshot = voice.stateMessage(session.code);
          if (voiceSnapshot.members.length) send(ws, voiceSnapshot);
        } else if (message.type === 'preview') send(ws, { type: 'roomPreview', roomPreview: engine.preview(message) });
        else if (message.type === 'ping') send(ws, { type: 'pong', time: Date.now() });
        else {
          if (!current) throw new GameError('NO_SESSION', 'Entra in una stanza per giocare.');
          economy.markActive(engine.room(current.code).players.find(p => p.id === current.playerId)?.profileId);
          switch (message.type) {
            case 'flip': engine.flip(current.code, current.playerId, message.index); break;
            case 'ready': engine.ready(current.code, current.playerId, message.ready); break;
            case 'nextRound': engine.nextRound(current.code, current.playerId); break;
            case 'rematch': engine.rematch(current.code, current.playerId); break;
            case 'leave':
              sockets.delete(ws);
              if (voice.drop(current.code, current.playerId)) publishVoice(current.code);
              engine.leave(current.code, current.playerId);
              send(ws, { type: 'left' });
              break;
            case 'voice':
              try { relayVoice(current.code, current.playerId, message); }
              catch (error) {
                if (!(error instanceof VoiceError)) throw error;
                send(ws, { type: 'voice', action: 'error', code: error.code, message: error.message });
              }
              break;
            default: throw new GameError('INVALID_MESSAGE', 'Azione non riconosciuta.');
          }
        }
      } catch (error) {
        const safe = error instanceof GameError || error instanceof EconomyError;
        if (!safe) console.error('Request failed:', error.message);
        send(ws, { type: 'error', code: safe ? error.code : 'SERVER_ERROR',
          message: safe ? error.message : 'Errore del servizio. Riprova tra poco.',
          ...(error instanceof GameError && error.code === 'ROOM_FULL' && error.roomPreview ?
            { roomPreview: error.roomPreview } : {}) });
      }
    });
    ws.on('close', () => {
      byAddress.set(address, Math.max(0, (byAddress.get(address) || 1) - 1));
      if (byAddress.get(address) === 0) byAddress.delete(address);
      const session = sockets.get(ws);
      const seat = seatOf.get(ws);
      sockets.delete(ws);
      if (session) engine.disconnect(session.code, session.playerId);
      if (seat && voice.drop(seat.code, seat.playerId)) publishVoice(seat.code);
    });
    ws.on('error', () => { /* close handles session cleanup */ });
  });
  const tick = setInterval(() => {
    try { engine.tick(); } catch (error) { console.error('Room maintenance failed:', error.message); }
  }, 100);
  tick.unref();
  const cleanup = setInterval(() => {
    try { economy.cleanup(); admin.data.cleanup(); } catch (error) { console.error('Economy maintenance failed:', error.message); }
    void auth.maintenance().catch(() => console.error('Account maintenance failed.'));
  }, 300_000);
  cleanup.unref();
  const heartbeat = setInterval(() => {
    for (const ws of wss.clients) {
      if (!ws.alive) { ws.terminate(); continue; }
      ws.alive = false;
      ws.ping();
    }
  }, 20_000);
  heartbeat.unref();
  http.listen(port, host);
  return { http, wss, engine, economy, auth, admin, close: async () => {
    clearInterval(tick); clearInterval(heartbeat); clearInterval(cleanup);
    admin.close();
    await auth.close();
    for (const ws of wss.clients) ws.terminate();
    await new Promise(resolveClose => wss.close(resolveClose));
    await new Promise(resolveClose => http.close(resolveClose));
    if (!providedEconomy) economy.close();
  } };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = startServer();
  server.http.on('listening', () => console.log(`MyMemory listening on ${JSON.stringify(server.http.address())}`));
  let shuttingDown = false;
  const stop = async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    await server.close();
    process.exit(0);
  };
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}
