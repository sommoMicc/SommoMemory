import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'voice_engine.dart';
import 'webrtc_voice_engine.dart';

/// What the player can be told about voice at any moment.
enum VoiceStatus {
  /// Not in voice.
  off,

  /// Waiting for the microphone.
  starting,

  /// In voice, but the room connection or a peer link is still being set up.
  connecting,

  /// In voice with nobody else to talk to yet.
  alone,

  /// Audio flows with at least one other player.
  live,

  /// Every attempt to reach the other players failed; no automatic retry is
  /// pending. Leaving and rejoining voice starts over.
  unreachable,
}

/// Recovery clock. Tests shorten it; production uses the defaults.
class VoiceTimings {
  const VoiceTimings({
    this.connect = const Duration(seconds: 15),
    this.answererGrace = const Duration(seconds: 3),
    this.disconnectGrace = const Duration(seconds: 5),
    this.stable = const Duration(seconds: 10),
    this.operation = const Duration(seconds: 10),
    this.backoff = const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
  });

  /// A new link must be connected within this time.
  final Duration connect;

  /// Extra patience of the answering side, so that when both ends notice the
  /// same failure only the offering side restarts the pair.
  final Duration answererGrace;

  /// How long a connected link may stay interrupted before it is rebuilt.
  final Duration disconnectGrace;

  /// A link connected for this long clears its failure count.
  final Duration stable;

  /// Upper bound for any single engine call, so one stuck platform call
  /// cannot stall everything queued behind it.
  final Duration operation;

  /// Delay before each successive rebuild of the same pair. When the list is
  /// used up the pair is reported as [VoiceStatus.unreachable].
  final List<Duration> backoff;
}

class VoiceMember {
  const VoiceMember({
    required this.id,
    required this.muted,
    required this.generation,
  });

  final String id;
  final bool muted;
  final int generation;
}

/// Optional room-wide voice. Every opted-in seat shares one channel; audio is
/// peer-to-peer and is never uploaded as a recording.
///
/// The controller is declarative. The player's intent ([enabled], [muted]),
/// the room connection and the server roster are the only inputs; one
/// serialized [_reconcile] pass turns them into the set of open links. A link
/// belongs to exactly one pair of roster generations, so recovering a broken
/// link is "join again": the server hands out a new generation, both ends
/// rebuild from the roster, and anything still in flight for the old pair is
/// discarded by generation instead of by timing.
class LobbyVoice extends ChangeNotifier {
  LobbyVoice(
    this.channel, {
    VoiceEngine? engine,
    this.timings = const VoiceTimings(),
  }) : _engine = engine ?? WebRtcVoiceEngine() {
    _seated = channel.seated;
    _serial = channel.sessionSerial;
    if (_seated) _adoptRoster(channel.voiceRoster);
    _subscription = channel.voiceMessages.listen(_onMessage);
    channel.addListener(_onChannel);
  }

  final VoiceChannel channel;
  final VoiceTimings timings;
  final VoiceEngine _engine;
  static const _iceDefine = String.fromEnvironment('VOICE_ICE_SERVERS');
  static const _micUnavailable =
      'Microfono non disponibile. Puoi continuare senza voce.';
  static const _voiceUnavailable = 'Voce non disponibile.';
  static const _unpromptedJoins = 6;

  bool enabled = false;
  bool muted = false;
  bool busy = false;
  bool foreground = true;
  String? micError;
  List<VoiceMember> members = const [];

  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final Map<String, _Link> _links = {};
  final Map<String, int> _strikes = {};
  List<Map<String, dynamic>> _iceServers = _fallbackIceServers();
  Future<void> _queue = Future.value();
  bool _closed = false, _micOpen = false;
  bool _seated = false, _joinPending = false, _announced = false;
  bool? _publishedMuted;
  int _serial = 0, _joinBudget = _unpromptedJoins;

  /// Voice can be turned on: the seat is confirmed on a live connection.
  bool get available => !_closed && channel.seated;
  bool get paused => enabled && !foreground;

  VoiceStatus get status {
    if (!enabled) return busy ? VoiceStatus.starting : VoiceStatus.off;
    final self = _self;
    if (!channel.seated || self == null) return VoiceStatus.connecting;
    if (!members.any((member) => member.id != self.id)) {
      return VoiceStatus.alone;
    }
    if (_links.values.any((link) => link.connected)) return VoiceStatus.live;
    if (_links.isNotEmpty && _links.values.every((link) => link.unreachable)) {
      return VoiceStatus.unreachable;
    }
    return VoiceStatus.connecting;
  }

  VoiceMember? memberFor(String? id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  VoiceMember? get _self => memberFor(channel.playerId);
  bool get _silenced => muted || !foreground;
  bool get _wantsIn => enabled && _micOpen && !_closed && channel.seated;

  Future<void> toggleJoin() => enabled ? leave() : join();

  Future<void> join() async {
    if (_closed || busy || enabled) return;
    busy = true;
    micError = null;
    _changed();
    try {
      await _run(() async {
        try {
          await _engine.openMicrophone();
        } catch (_) {
          micError = _micUnavailable;
          return;
        }
        if (_closed) return;
        _micOpen = true;
        enabled = true;
        muted = false;
        _strikes.clear();
        _joinBudget = _unpromptedJoins;
        _engine.setMicrophoneLive(!_silenced);
        _sendJoin();
      });
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> leave() async {
    if (_closed || !enabled) return;
    _stop();
    await _run(_reconcile);
  }

  void toggleMute() {
    if (!enabled || _closed) return;
    muted = !muted;
    _applySilence();
  }

  /// A backgrounded app neither sends nor plays voice until it returns.
  void setForeground(bool value) {
    if (foreground == value || _closed) return;
    foreground = value;
    for (final link in _links.values) {
      link.media?.setAudible(value);
    }
    _applySilence();
  }

  void _applySilence() {
    if (_micOpen) _engine.setMicrophoneLive(enabled && !_silenced);
    _publishMute();
    _changed();
  }

  void _publishMute() {
    if (!_wantsIn || !_announced || _publishedMuted == _silenced) return;
    _publishedMuted = _silenced;
    channel.send({'type': 'voice', 'action': 'mute', 'muted': _silenced});
  }

  /// Enters the channel, or re-enters it to obtain a new generation. The
  /// current mute state travels with the join, so a rebuilt roster entry never
  /// shows a silenced player as speaking.
  void _sendJoin() {
    if (!_wantsIn) return;
    _joinPending = true;
    _announced = true;
    _publishedMuted = _silenced;
    channel.send({'type': 'voice', 'action': 'join', 'muted': _silenced});
  }

  /// The server no longer lists us although we never left: join again, but
  /// only a bounded number of times per connection.
  void _rejoinAfterDrop() {
    if (!_wantsIn || _joinPending) return;
    if (_joinBudget-- <= 0) {
      _abandon();
      return;
    }
    _sendJoin();
  }

  void _stop() {
    final announced = _announced && channel.seated;
    enabled = false;
    muted = false;
    micError = null;
    _joinPending = false;
    _announced = false;
    if (announced) channel.send({'type': 'voice', 'action': 'leave'});
    _changed();
  }

  void _abandon() {
    if (!enabled) return;
    _stop();
    micError = _voiceUnavailable;
    unawaited(_run(_reconcile));
    _changed();
  }

  void _onChannel() {
    if (_closed) return;
    final seated = channel.seated, serial = channel.sessionSerial;
    if (seated == _seated && serial == _serial) return;
    _seated = seated;
    _serial = serial;
    // A roster, a join and every link belong to one connection to the room.
    members = const [];
    _joinPending = false;
    _announced = false;
    _strikes.clear();
    _joinBudget = _unpromptedJoins;
    if (seated) {
      _adoptRoster(channel.voiceRoster);
      _sendJoin();
    }
    unawaited(_run(_reconcile));
    _changed();
  }

  void _onMessage(Map<String, dynamic> message) {
    if (_closed || !channel.seated) return;
    switch (message['action']) {
      case 'config':
        _adoptIceServers(message['iceServers']);
      case 'state':
        if (!_adoptRoster(message)) return;
        if (_self != null) {
          _joinPending = false;
        } else {
          _rejoinAfterDrop();
        }
        unawaited(_run(_reconcile));
        _changed();
      case 'signal':
        unawaited(_run(() => _onSignal(message)));
      case 'error':
        switch (message['code']) {
          case 'NOT_IN_VOICE':
            _rejoinAfterDrop();
          case 'RATE_LIMITED' || 'INVALID_SIGNAL':
            // One lost signal: the affected link times out and is rebuilt.
            break;
          default:
            _abandon();
        }
    }
  }

  bool _adoptRoster(Map<String, dynamic>? message) {
    final raw = message?['members'];
    if (raw is! List) return false;
    final next = <VoiceMember>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final id = value['id'], generation = value['generation'];
      final silenced = value['muted'];
      if (id is! String || generation is! int || silenced is! bool) continue;
      next.add(VoiceMember(id: id, muted: silenced, generation: generation));
    }
    members = List.unmodifiable(next);
    return true;
  }

  void _adoptIceServers(Object? raw) {
    if (raw is! List) return;
    final servers = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final urls = item['urls'];
      final list = urls is String
          ? [urls]
          : urls is List
          ? urls.whereType<String>().toList()
          : const <String>[];
      if (list.isEmpty) continue;
      servers.add({
        'urls': list,
        if (item['username'] is String) 'username': item['username'],
        if (item['credential'] is String) 'credential': item['credential'],
      });
    }
    _iceServers = servers;
  }

  /// Makes the open links match intent, connection and roster. Runs only on
  /// the serialized queue, so it never interleaves with itself or a signal.
  Future<void> _reconcile() async {
    final self = _wantsIn ? _self : null;
    for (final link in _links.values.toList()) {
      final remote = self == null ? null : memberFor(link.remoteId);
      if (remote == null ||
          link.selfGeneration != self!.generation ||
          link.remoteGeneration != remote.generation) {
        await _closeLink(link);
      }
    }
    if (!enabled && _micOpen) {
      _micOpen = false;
      await _quietly(_engine.closeMicrophone());
    }
    if (self != null) {
      for (final remote in members) {
        if (remote.id == self.id || _links.containsKey(remote.id)) continue;
        await _openLink(self, remote);
      }
    }
    _changed();
  }

  Future<void> _openLink(VoiceMember self, VoiceMember remote) async {
    final link = _Link(
      remoteId: remote.id,
      selfGeneration: self.generation,
      remoteGeneration: remote.generation,
      // Exactly one side offers, so two offers can never cross.
      offerer: self.id.compareTo(remote.id) < 0,
    );
    _links[remote.id] = link;
    link.arm(
      timings.connect + (link.offerer ? Duration.zero : timings.answererGrace),
      () => _trouble(link),
    );
    try {
      final media = await _engine
          .connect(
            iceServers: _iceServers,
            onCandidate: (candidate) => _signal(link, 'ice', candidate),
            onState: (state) => _onLinkState(link, state),
          )
          .timeout(timings.operation);
      link.media = media;
      if (link.closed || _closed) {
        await _quietly(media.close());
        return;
      }
      media.setAudible(foreground);
      if (link.offerer) {
        final offer = await media.createOffer().timeout(timings.operation);
        _signal(link, 'offer', offer);
      }
    } catch (_) {
      _trouble(link);
    }
  }

  Future<void> _closeLink(_Link link) async {
    if (identical(_links[link.remoteId], link)) _links.remove(link.remoteId);
    link.close();
    await _quietly(link.media?.close());
  }

  Future<void> _onSignal(Map<String, dynamic> message) async {
    final from = message['from'], kind = message['kind'];
    final generation = message['generation'];
    final peerGeneration = message['peerGeneration'];
    final payload = message['payload'];
    if (from is! String || kind is! String || payload is! Map) return;
    final link = _links[from];
    final media = link?.media;
    // Anything not addressed to the current pair belongs to an older attempt.
    if (link == null ||
        media == null ||
        link.closed ||
        generation != link.remoteGeneration ||
        (peerGeneration != null && peerGeneration != link.selfGeneration)) {
      return;
    }
    final body = Map<String, dynamic>.from(payload);
    try {
      switch (kind) {
        case 'offer':
          if (link.offerer || link.described) return;
          link.described = true;
          final answer = await media
              .acceptOffer(body)
              .timeout(timings.operation);
          _signal(link, 'answer', answer);
        case 'answer':
          if (!link.offerer || link.described) return;
          link.described = true;
          await media.acceptAnswer(body).timeout(timings.operation);
        case 'ice':
          await media.addCandidate(body).timeout(timings.operation);
      }
    } catch (_) {
      if (kind != 'ice') _trouble(link);
    }
  }

  void _signal(_Link link, String kind, Map<String, dynamic> payload) {
    if (_closed || link.closed || !channel.seated) return;
    channel.send({
      'type': 'voice',
      'action': 'signal',
      'to': link.remoteId,
      'kind': kind,
      'generation': link.selfGeneration,
      'peerGeneration': link.remoteGeneration,
      'payload': payload,
    });
  }

  void _onLinkState(_Link link, VoiceLinkState state) {
    if (_closed || link.closed || link.troubled) return;
    switch (state) {
      case VoiceLinkState.connecting:
        return;
      case VoiceLinkState.connected:
        link.connected = true;
        link.arm(timings.stable, () => _strikes.remove(link.remoteId));
      case VoiceLinkState.disconnected:
        // Often a brief network blip that heals by itself.
        link.connected = false;
        link.arm(timings.disconnectGrace, () => _trouble(link));
      case VoiceLinkState.failed || VoiceLinkState.closed:
        _trouble(link);
    }
    _changed();
  }

  /// The link will not work as it is. Rebuild the pair by joining again, with
  /// a growing delay, until the allowance for this player is used up.
  void _trouble(_Link link) {
    if (_closed || link.closed || link.troubled) return;
    link.troubled = true;
    link.connected = false;
    final strikes = _strikes[link.remoteId] ?? 0;
    if (strikes >= timings.backoff.length) {
      link.unreachable = true;
      link.arm(null, null);
    } else {
      _strikes[link.remoteId] = strikes + 1;
      link.arm(
        timings.backoff[strikes] +
            (link.offerer ? Duration.zero : timings.answererGrace),
        _sendJoin,
      );
    }
    _changed();
  }

  Future<void> _run(Future<void> Function() operation) {
    final next = _queue.then((_) async {
      if (_closed) return;
      try {
        await operation();
      } catch (error) {
        // Voice never affects the match; a failed step is retried by timers.
        assert(() {
          debugPrint('LobbyVoice: $error');
          return true;
        }());
      }
    });
    return _queue = next;
  }

  Future<void> _quietly(Future<void>? operation) async {
    try {
      await operation?.timeout(timings.operation);
    } catch (_) {}
  }

  static List<Map<String, dynamic>> _fallbackIceServers() {
    final servers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
    ];
    if (_iceDefine.isEmpty) return servers;
    try {
      final decoded = jsonDecode(_iceDefine);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map && item['urls'] != null) {
            servers.add(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (_) {}
    return servers;
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    final announced = _announced && channel.seated;
    _closed = true;
    if (announced) channel.send({'type': 'voice', 'action': 'leave'});
    channel.removeListener(_onChannel);
    unawaited(_subscription.cancel());
    final links = _links.values.toList();
    _links.clear();
    for (final link in links) {
      link.close();
    }
    unawaited(_shutdown(links));
    super.dispose();
  }

  Future<void> _shutdown(List<_Link> links) async {
    for (final link in links) {
      await _quietly(link.media?.close());
    }
    _micOpen = false;
    await _quietly(_engine.closeMicrophone());
  }
}

/// One attempt to reach one remote player, valid for one generation pair.
class _Link {
  _Link({
    required this.remoteId,
    required this.selfGeneration,
    required this.remoteGeneration,
    required this.offerer,
  });

  final String remoteId;
  final int selfGeneration, remoteGeneration;
  final bool offerer;
  VoiceLink? media;
  Timer? _timer;

  /// The remote description of this attempt has been applied.
  bool described = false;
  bool connected = false, troubled = false, unreachable = false;
  bool closed = false;

  /// A link waits for one thing at a time: to connect, to prove stable, to
  /// recover from an interruption, or for its rebuild delay.
  void arm(Duration? delay, void Function()? action) {
    _timer?.cancel();
    _timer = delay == null || action == null ? null : Timer(delay, action);
  }

  void close() {
    closed = true;
    connected = false;
    arm(null, null);
  }
}
