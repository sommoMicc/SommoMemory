import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'l10n/app_strings.dart';
import 'online.dart';
import 'palette.dart';

/// Optional room-wide voice. Every opted-in seat shares one channel; audio is
/// peer-to-peer and is never uploaded as a recording.
class LobbyVoice extends ChangeNotifier {
  LobbyVoice(this.online) {
    _subscription = online.voiceEvents.stream.listen(_onVoice);
    online.addListener(_onOnline);
  }

  final OnlineGame online;
  static const _iceDefine = String.fromEnvironment('VOICE_ICE_SERVERS');

  bool enabled = false;
  bool muted = false;
  bool busy = false;
  bool foreground = true;
  String? micError;
  List<VoiceMember> members = const [];

  StreamSubscription<Map<String, dynamic>>? _subscription;
  MediaStream? _local;
  final Map<String, _Peer> _peers = {};
  final Map<String, String> _negotiated = {};
  Future<void> _chain = Future.value();
  bool _joinSent = false;
  bool _closed = false;
  int _epoch = 0;

  VoiceMember? memberFor(String? id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  bool get hearingLobby =>
      enabled && members.any((member) => member.id != online.playerId);

  Future<void> toggleJoin() async {
    if (_closed || busy) return;
    if (enabled) {
      await leave();
      return;
    }
    busy = true;
    micError = null;
    _changed();
    try {
      await _startMic();
      enabled = true;
      muted = false;
      _joinSent = false;
      _sendJoinIfReady();
    } catch (_) {
      enabled = false;
      micError = 'Microfono non disponibile. Puoi continuare senza voce.';
      await _stopMic();
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> leave() async {
    if (_closed) return;
    final epoch = ++_epoch;
    enabled = false;
    muted = false;
    micError = null;
    _joinSent = false;
    if (online.connected) {
      online.send({'type': 'voice', 'action': 'leave'});
    }
    await _stopMic();
    await _closePeers();
    if (epoch == _epoch) _changed();
  }

  void toggleMute() {
    if (!enabled || _closed) return;
    muted = !muted;
    _applyTrackEnabled();
    _publishMute();
    _changed();
  }

  void setForeground(bool value) {
    if (foreground == value || _closed) return;
    foreground = value;
    _applyTrackEnabled();
    _publishMute();
    _changed();
  }

  void _publishMute() {
    if (!enabled || !online.connected || memberFor(online.playerId) == null) {
      return;
    }
    online.send({
      'type': 'voice',
      'action': 'mute',
      'muted': muted || !foreground,
    });
  }

  void _onOnline() {
    if (_closed) return;
    if (!online.connected || online.playerId == null) {
      _joinSent = false;
      unawaited(_closePeers());
      return;
    }
    _sendJoinIfReady();
  }

  void _sendJoinIfReady() {
    if (!enabled || _joinSent || !online.connected || online.playerId == null) {
      return;
    }
    _joinSent = true;
    online.send({'type': 'voice', 'action': 'join'});
  }

  void _onVoice(Map<String, dynamic> message) {
    if (_closed) return;
    switch (message['action']) {
      case 'state':
        final raw = message['members'];
        if (raw is! List) return;
        final next = <VoiceMember>[];
        for (final value in raw) {
          if (value is! Map) continue;
          final id = value['id'];
          final generation = value['generation'];
          if (id is! String || generation is! int || value['muted'] is! bool) {
            continue;
          }
          next.add(
            VoiceMember(
              id: id,
              muted: value['muted'] as bool,
              generation: generation,
            ),
          );
        }
        members = List.unmodifiable(next);
        micError = null;
        if (enabled && online.playerId != null && memberFor(online.playerId) == null) {
          _joinSent = false;
          _sendJoinIfReady();
        }
        _enqueue(() => _sync());
        _changed();
      case 'signal':
        _enqueue(() => _onSignal(message));
      case 'error':
        micError = message['message'] as String? ?? 'Voce non disponibile.';
        _changed();
    }
  }

  Future<void> _sync() async {
    final self = memberFor(online.playerId);
    if (!enabled || self == null || _local == null) {
      await _closePeers();
      return;
    }
    final remotes = members.where((member) => member.id != self.id).toList();
    for (final id in _peers.keys.toList()) {
      if (!remotes.any((member) => member.id == id)) await _closePeer(id);
    }
    for (final remote in remotes) {
      final key = '${self.generation}:${remote.generation}';
      if (_negotiated[remote.id] == key && _peers.containsKey(remote.id)) {
        continue;
      }
      _negotiated[remote.id] = key;
      await _openPeer(
        remote.id,
        offer: self.id.compareTo(remote.id) < 0,
        generation: self.generation,
      );
    }
  }

  Future<void> _openPeer(
    String remoteId, {
    required bool offer,
    required int generation,
  }) async {
    await _closePeer(remoteId);
    final local = _local;
    if (!enabled || local == null || _closed) return;
    final pc = await createPeerConnection({
      'iceServers': _iceServers(),
      'sdpSemantics': 'unified-plan',
    });
    if (_closed) {
      await pc.close();
      return;
    }
    final bag = _Peer(pc);
    _peers[remoteId] = bag;
    pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty || bag.closed) return;
      _signal(remoteId, 'ice', generation, {
        'candidate': value,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) bag.remote = event.streams.first;
    };
    for (final track in local.getAudioTracks()) {
      await pc.addTrack(track, local);
    }
    if (!offer || bag.closed) return;
    final description = await pc.createOffer({'offerToReceiveAudio': 1});
    if (bag.closed) return;
    await pc.setLocalDescription(description);
    _signal(remoteId, 'offer', generation, {
      'type': 'offer',
      'sdp': description.sdp,
    });
  }

  Future<void> _onSignal(Map<String, dynamic> message) async {
    final from = message['from'];
    final kind = message['kind'];
    final generation = message['generation'];
    final payload = message['payload'];
    if (from is! String ||
        kind is! String ||
        generation is! int ||
        payload is! Map ||
        !enabled) {
      return;
    }
    final remote = memberFor(from);
    final self = memberFor(online.playerId);
    if (remote == null || self == null || generation != remote.generation) {
      return;
    }
    var bag = _peers[from];
    if (bag == null && kind == 'offer') {
      await _openPeer(from, offer: false, generation: self.generation);
      bag = _peers[from];
    }
    if (bag == null || bag.closed) return;
    if (kind == 'offer' || kind == 'answer') {
      final sdp = payload['sdp'];
      if (sdp is! String || payload['type'] != kind) return;
      await bag.pc.setRemoteDescription(RTCSessionDescription(sdp, kind));
      for (final candidate in bag.pending) {
        await bag.pc.addCandidate(candidate);
      }
      bag.pending.clear();
      if (kind == 'offer' && !bag.closed) {
        final answer = await bag.pc.createAnswer({'offerToReceiveAudio': 1});
        if (bag.closed) return;
        await bag.pc.setLocalDescription(answer);
        _signal(from, 'answer', self.generation, {
          'type': 'answer',
          'sdp': answer.sdp,
        });
      }
      return;
    }
    if (kind == 'ice') {
      final candidate = payload['candidate'];
      if (candidate is! String || candidate.isEmpty) return;
      final ice = RTCIceCandidate(
        candidate,
        payload['sdpMid'] as String?,
        (payload['sdpMLineIndex'] as num?)?.toInt(),
      );
      final remoteDescription = await bag.pc.getRemoteDescription();
      if (remoteDescription == null) {
        bag.pending.add(ice);
      } else {
        await bag.pc.addCandidate(ice);
      }
    }
  }

  void _signal(
    String to,
    String kind,
    int generation,
    Map<String, dynamic> payload,
  ) {
    if (!online.connected || _closed) return;
    online.send({
      'type': 'voice',
      'action': 'signal',
      'to': to,
      'kind': kind,
      'generation': generation,
      'payload': payload,
    });
  }

  Future<void> _startMic() async {
    await _stopMic();
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    _applyTrackEnabled();
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {
        // Earpiece fallback still carries the call.
      }
    }
  }

  void _applyTrackEnabled() {
    final live = enabled && !muted && foreground;
    for (final track in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = live;
    }
  }

  Future<void> _stopMic() async {
    final local = _local;
    _local = null;
    if (local == null) return;
    for (final track in local.getTracks()) {
      await track.stop();
    }
    await local.dispose();
  }

  Future<void> _closePeer(String id) async {
    final bag = _peers.remove(id);
    _negotiated.remove(id);
    if (bag == null) return;
    bag.closed = true;
    bag.remote?.getTracks().forEach((track) => track.stop());
    await bag.pc.close();
  }

  Future<void> _closePeers() async {
    for (final id in _peers.keys.toList()) {
      await _closePeer(id);
    }
  }

  void _enqueue(Future<void> Function() action) {
    _chain = _chain.then((_) => action()).catchError((Object _) {});
  }

  List<Map<String, dynamic>> _iceServers() {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
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
    _closed = true;
    ++_epoch;
    if (enabled && online.connected) {
      online.send({'type': 'voice', 'action': 'leave'});
    }
    online.removeListener(_onOnline);
    unawaited(_subscription?.cancel());
    unawaited(_stopMic());
    unawaited(_closePeers());
    super.dispose();
  }
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

class _Peer {
  _Peer(this.pc);
  final RTCPeerConnection pc;
  final List<RTCIceCandidate> pending = [];
  MediaStream? remote;
  bool closed = false;
}

class LobbyVoiceControls extends StatelessWidget {
  const LobbyVoiceControls({
    super.key,
    required this.voice,
    this.compact = false,
  });

  final LobbyVoice voice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final joined = voice.enabled;
        final paused = joined && !voice.foreground;
        final status = voice.micError != null
            ? tr(context, voice.micError!)
            : !joined
            ? tr(
                context,
                'La voce è per tutta la lobby. Non viene registrata e puoi giocare senza.',
              )
            : paused
            ? tr(context, 'Voce in pausa')
            : voice.muted
            ? tr(context, 'Voce silenziata')
            : voice.hearingLobby
            ? tr(context, 'In voce')
            : tr(context, 'In attesa degli altri');
        if (compact) {
          final canJoin = !voice.busy && voice.online.connected;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: joined
                    ? tr(context, 'Esci dalla voce')
                    : tr(context, 'Attiva voce'),
                onPressed: canJoin ? () => voice.toggleJoin() : null,
                icon: Icon(
                  joined ? Icons.call_end_rounded : Icons.mic_none_rounded,
                  color: joined ? coral : ink,
                  size: 20,
                ),
              ),
              if (joined)
                IconButton(
                  tooltip: voice.muted
                      ? tr(context, 'Riattiva microfono')
                      : tr(context, 'Silenzia'),
                  onPressed: voice.toggleMute,
                  icon: Icon(
                    voice.muted || paused
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    color: popYellow,
                    size: 20,
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ink, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: voice.busy || !voice.online.connected
                        ? null
                        : () => voice.toggleJoin(),
                    child: Text(
                      voice.busy
                          ? tr(context, 'Connessione…')
                          : joined
                          ? tr(context, 'Esci dalla voce')
                          : tr(context, 'Attiva voce'),
                    ),
                  ),
                ),
                if (joined) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: voice.muted
                        ? tr(context, 'Riattiva microfono')
                        : tr(context, 'Silenzia'),
                    onPressed: voice.toggleMute,
                    icon: Icon(
                      voice.muted || paused
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: ink,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
