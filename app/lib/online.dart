import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'decks.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RoomPreview {
  RoomPreview({
    required this.code,
    required this.phase,
    required List<Map<String, dynamic>> players,
    this.winnerId,
    this.finishReason,
  }) : players = List.unmodifiable(
         players.map((player) => Map<String, dynamic>.unmodifiable(player)),
       );

  final String code, phase;
  final List<Map<String, dynamic>> players;
  final String? winnerId, finishReason;
  bool get finished => phase == 'finished';

  factory RoomPreview.fromJson(Map<String, dynamic> json) {
    final code = json['code'], phase = json['phase'], raw = json['players'];
    if (code is! String ||
        !RegExp(r'^[A-Z2-9]{6}$').hasMatch(code) ||
        !['playing', 'roundFinished', 'finished'].contains(phase) ||
        raw is! List ||
        raw.length != 2) {
      throw const FormatException('Invalid room preview');
    }
    final players = <Map<String, dynamic>>[];
    for (final value in raw) {
      if (value is! Map) throw const FormatException('Invalid preview player');
      final id = value['id'], name = value['name'], score = value['score'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 128 ||
          name is! String ||
          name.runes.length > 24 ||
          score is! int ||
          score < 0 ||
          score > 18 ||
          value['connected'] is! bool) {
        throw const FormatException('Invalid preview player');
      }
      players.add({
        'id': id,
        'name': name,
        'score': score,
        'connected': value['connected'],
      });
    }
    if (players[0]['id'] == players[1]['id']) {
      throw const FormatException('Invalid preview players');
    }
    final winnerId = json['winnerId'], finishReason = json['finishReason'];
    if ((winnerId != null && !players.any((p) => p['id'] == winnerId)) ||
        ![null, 'completed', 'forfeit', 'cancelled'].contains(finishReason) ||
        (phase == 'finished' && finishReason == null) ||
        (phase != 'finished' && (winnerId != null || finishReason != null))) {
      throw const FormatException('Invalid preview result');
    }
    return RoomPreview(
      code: code,
      phase: phase as String,
      players: players,
      winnerId: winnerId as String?,
      finishReason: finishReason as String?,
    );
  }
}

class OnlineGame extends ChangeNotifier {
  OnlineGame(this.prefs, {String? serverUrl})
    : _serverUrl = serverUrl ?? endpoint,
      _roomCode = prefs.getString('room.code'),
      _token = prefs.getString('room.token'),
      _activeRanked = prefs.getBool('room.activeRanked') ?? false;

  final SharedPreferences prefs;
  final String _serverUrl;
  static const endpoint = String.fromEnvironment(
    'MULTIPLAYER_URL',
    defaultValue: 'wss://sommomemory.sommomi.cc/ws',
  );
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _heartbeat, _handshake;
  Future<void> _storage = Future.value();
  Map<String, dynamic>? _pendingAction;
  String? _roomCode, _token;
  bool _activeRanked;
  int _sessionEpoch = 0;
  DateTime? _lastSeen;
  Map<String, dynamic>? state;
  String? playerId, error, errorCode;
  RoomPreview? _roomPreview;
  bool _terminalError = false;
  String status = 'Connessione…';
  bool connected = false, _closed = false, _connecting = false;
  int _attempt = 0, _generation = 0;
  static const _supportedFeatures = [
    'ranked-v1',
    'ranked-attempts-v1',
    'lobby-v1',
    'voice-v1',
  ];
  final StreamController<Map<String, dynamic>> voiceEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  String? get code => _roomCode;
  bool get hasSession => _roomCode != null && _token != null;
  RoomPreview? get roomPreview => _roomPreview;
  bool get terminalError => _terminalError;
  bool get canRefreshPreview =>
      !_closed && !_connecting && !connected && _roomPreview != null;
  bool get canRetry =>
      !_closed &&
      !_terminalError &&
      !_connecting &&
      !connected &&
      (_pendingAction != null || hasSession);

  bool _current(int generation) => !_closed && generation == _generation;

  Future<void> open(Map<String, dynamic>? action) async {
    if (_connecting || _closed || (_terminalError && action == null)) return;
    if (action != null &&
        prefs.getBool('room.activeRanked') == true &&
        prefs.getString('room.code') != null &&
        prefs.getString('room.token') != null) {
      error =
          'Hai una classificata in corso. Riprendila o abbandonala prima di iniziare un’altra partita.';
      errorCode = 'RANKED_SESSION_ACTIVE';
      status = 'Riprendi la partita';
      _changed();
      return;
    }
    _connecting = true;
    _terminalError = false;
    _roomPreview = null;
    errorCode = null;
    final generation = ++_generation;
    if (action != null) {
      _pendingAction = {
        ...action,
        'supportedDecks': deckNames.keys.toList(),
        'supportedFeatures': _supportedFeatures,
      };
      // A new game must never fall back to an older saved seat on reconnect.
      await _clearSession();
      if (!_current(generation)) return;
      state = null;
      playerId = null;
    }
    if (_pendingAction == null && !hasSession) {
      error = 'Torna alla home per creare o raggiungere una stanza.';
      status = 'Nessuna partita da riprendere';
      _connecting = false;
      _changed();
      return;
    }
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    status = 'Connessione…';
    error = null;
    _changed();
    await _detachChannel();
    if (!_current(generation)) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 12));
      if (!_current(generation)) {
        unawaited(_close(channel));
        return;
      }
      connected = true;
      _lastSeen = DateTime.now();
      status = hasSession
          ? 'Riprendiamo la partita…'
          : 'Prepariamo la partita…';
      _subscription = channel.stream.listen(
        (raw) {
          if (!_current(generation)) return;
          _lastSeen = DateTime.now();
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            switch (msg['type']) {
              case 'session':
                final id = msg['playerId'],
                    room = msg['code'],
                    token = msg['token'];
                if (id is! String || room is! String || token is! String) {
                  throw const FormatException('Invalid session');
                }
                playerId = id;
                _roomCode = room;
                _token = token;
                if (_pendingAction?['matchType'] == 'ranked') {
                  _activeRanked = true;
                }
                _pendingAction = null;
                _handshake?.cancel();
                unawaited(_saveSession());
                status = 'Online';
                errorCode = null;
                _roomPreview = null;
                break;
              case 'state':
                state = msg;
                if (msg['matchType'] == 'ranked') {
                  final phase = msg['phase'];
                  final rewards = msg['rewards'];
                  final settled =
                      phase == 'finished' &&
                      (msg['finishReason'] == 'cancelled' ||
                          rewards is Map &&
                              playerId != null &&
                              rewards.containsKey(playerId));
                  final active = !settled;
                  if (_activeRanked != active) {
                    _activeRanked = active;
                    unawaited(_saveSession());
                  }
                } else if (_activeRanked) {
                  _activeRanked = false;
                  unawaited(_saveSession());
                }
                error = null;
                errorCode = null;
                status = 'Online';
                _attempt = 0;
                break;
              case 'roomPreview':
                if (_pendingAction?['type'] != 'preview' ||
                    msg['roomPreview'] is! Map) {
                  throw const FormatException('Unexpected room preview');
                }
                _roomPreview = RoomPreview.fromJson(
                  Map<String, dynamic>.from(msg['roomPreview'] as Map),
                );
                _endSession('La stanza è già al completo.', code: 'ROOM_FULL');
                return;
              case 'error':
                error = msg['message'] as String? ?? 'Operazione non riuscita';
                errorCode = msg['code'] is String
                    ? msg['code'] as String
                    : null;
                _roomPreview = null;
                if (errorCode == 'ROOM_FULL' && msg['roomPreview'] is Map) {
                  try {
                    _roomPreview = RoomPreview.fromJson(
                      Map<String, dynamic>.from(msg['roomPreview'] as Map),
                    );
                  } on FormatException {
                    // A malformed optional preview cannot turn a denial into a game.
                  }
                }
                final terminal = [
                  'ROOM_NOT_FOUND',
                  'INVALID_TOKEN',
                  'ROOM_EXPIRED',
                  'INVALID_SESSION',
                  'NO_SESSION',
                  'UPDATE_REQUIRED',
                  'ROOM_FULL',
                  'INVALID_CAPABILITIES',
                  'INVALID_NAME',
                  'INVALID_OPTIONS',
                  'DECK_LOCKED',
                  'PROFILE_REQUIRED',
                  'SAME_PROFILE',
                  'ARENA_MISMATCH',
                  'RANKED_BUSY',
                  'RANKED_DISABLED',
                ].contains(errorCode);
                if (terminal || !hasSession) {
                  _endSession(error!, retryable: !terminal);
                  return;
                }
                break;
              case 'voice':
                if (!voiceEvents.isClosed) voiceEvents.add(msg);
                break;
              case 'left':
                _endSession(
                  error ?? 'Hai lasciato la stanza.',
                  code: errorCode ?? 'LEFT',
                );
                return;
            }
            _changed();
          } catch (_) {
            _endSession(
              'Risposta del servizio non valida. Riprova dalla home.',
              code: 'INVALID_RESPONSE',
            );
          }
        },
        onError: (_) => _lost(generation),
        onDone: () {
          if (!_current(generation)) return;
          if (channel.closeCode == 4001) {
            _pendingAction = null;
            _endSession(
              'Partita aperta in un’altra scheda o su un altro dispositivo.',
              clearStoredSession: false,
              code: 'SESSION_TRANSFERRED',
            );
          } else {
            _lost(generation);
          }
        },
      );
      _handshake = Timer(const Duration(seconds: 12), () {
        if (!_current(generation)) return;
        _lost(generation);
        unawaited(_close(channel));
      });
      _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!_current(generation) || !connected) return;
        if (DateTime.now().difference(_lastSeen!).inSeconds > 35) {
          _lost(generation);
          unawaited(_close(channel));
        } else {
          send({'type': 'ping'});
        }
      });
      send(
        _pendingAction ??
            {
              'type': 'resume',
              'code': code,
              'token': _token,
              'supportedDecks': deckNames.keys.toList(),
              'supportedFeatures': _supportedFeatures,
            },
      );
      _changed();
    } catch (_) {
      _lost(generation);
    } finally {
      if (_current(generation)) {
        _connecting = false;
        _changed();
      }
    }
  }

  void _lost(int generation) {
    if (!_current(generation)) return;
    connected = false;
    _terminalError = false;
    _roomPreview = null;
    _handshake?.cancel();
    _heartbeat?.cancel();
    if (hasSession) {
      status = 'Riconnessione…';
      error = null;
      errorCode = null;
      if (_retry?.isActive != true) {
        final delay = [1, 2, 4, 8, 15][_attempt.clamp(0, 4)];
        _attempt++;
        _retry = Timer(Duration(seconds: delay), () => open(null));
      }
    } else {
      status = 'Connessione non riuscita';
      error =
          'Impossibile raggiungere il servizio. Controlla Internet e riprova.';
      errorCode = 'CONNECTION_FAILED';
    }
    _changed();
  }

  void send(Map<String, dynamic> action) {
    if (_terminalError) return;
    if (!connected || _channel == null) {
      error = 'Attendi la connessione';
      _changed();
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(action));
    } catch (_) {
      _lost(_generation);
    }
  }

  void flip(int index) => send({'type': 'flip', 'index': index});
  void rematch() => send({'type': 'rematch'});
  void nextRound() => send({'type': 'nextRound'});
  void ready(bool value) => send({'type': 'ready', 'ready': value});

  Future<void> refreshPreview() async {
    if (!canRefreshPreview) return;
    final room = _roomPreview!.code;
    await open({'type': 'preview', 'code': room});
  }

  Future<void> _saveSession() {
    final room = _roomCode, token = _token, activeRanked = _activeRanked;
    final epoch = _sessionEpoch;
    _storage = _storage
        .then((_) async {
          if (epoch != _sessionEpoch || room == null || token == null) return;
          await prefs.setString('room.code', room);
          if (epoch != _sessionEpoch) return;
          await prefs.setString('room.token', token);
          if (epoch != _sessionEpoch) return;
          await prefs.setBool('room.activeRanked', activeRanked);
        })
        .catchError((Object _) {
          // The in-memory seat can still reconnect if local storage is unavailable.
        });
    return _storage;
  }

  Future<void> _clearSession() {
    final room = _roomCode, token = _token;
    ++_sessionEpoch;
    _roomCode = null;
    _token = null;
    _activeRanked = false;
    _storage = _storage
        .then((_) async {
          if (prefs.getString('room.code') != room ||
              prefs.getString('room.token') != token) {
            return;
          }
          await prefs.remove('room.code');
          await prefs.remove('room.token');
          await prefs.remove('room.activeRanked');
        })
        .catchError((Object _) {});
    return _storage;
  }

  void _endSession(
    String reason, {
    bool clearStoredSession = true,
    bool retryable = false,
    String? code,
  }) {
    ++_generation;
    _connecting = false;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    _terminalError = !retryable;
    if (!retryable) _pendingAction = null;
    state = null;
    playerId = null;
    error = reason;
    if (code != null) errorCode = code;
    status = 'Partita non disponibile';
    if (clearStoredSession) {
      unawaited(_clearSession());
    } else {
      // Another browser tab owns this same saved token now.
      ++_sessionEpoch;
      _roomCode = null;
      _token = null;
    }
    unawaited(_detachChannel());
    _changed();
  }

  Future<void> _close(WebSocketChannel channel) async {
    try {
      await channel.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _detachChannel() async {
    final subscription = _subscription, channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    if (channel != null) await _close(channel);
  }

  Future<void> leave() async {
    if (connected) send({'type': 'leave'});
    ++_generation;
    _connecting = false;
    _pendingAction = null;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    state = null;
    playerId = null;
    error = null;
    errorCode = null;
    _roomPreview = null;
    _terminalError = false;
    status = 'Disconnesso';
    await _clearSession();
    await _detachChannel();
    _changed();
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    unawaited(voiceEvents.close());
    unawaited(_detachChannel());
    super.dispose();
  }
}
