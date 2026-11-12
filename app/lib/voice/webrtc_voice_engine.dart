import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../audio_session.dart';
import 'voice_audio_sink.dart';
import 'voice_engine.dart';

/// flutter_webrtc implementation of [VoiceEngine]. It holds no policy: when to
/// connect, retry or give up is decided by the controller.
class WebRtcVoiceEngine implements VoiceEngine {
  MediaStream? _local;
  bool _live = false;
  int _epoch = 0;

  @override
  Future<void> openMicrophone() async {
    await closeMicrophone();
    final epoch = ++_epoch;
    // Raised before capture starts: from here on the call owns the session.
    voiceCallActive.value = true;
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      if (stream.getAudioTracks().isEmpty) {
        throw StateError('No audio track');
      }
    } catch (_) {
      if (stream != null) await _release(stream);
      if (epoch == _epoch) voiceCallActive.value = false;
      rethrow;
    }
    if (epoch != _epoch) {
      // Closed or reopened while the permission prompt was still showing.
      await _release(stream);
      throw StateError('Microphone request superseded');
    }
    _local = stream;
    _applyLive();
    if (!kIsWeb) {
      try {
        // Loudspeaker instead of the earpiece, but never over a headset.
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      } catch (_) {
        // The default route still carries the call.
      }
    }
  }

  @override
  void setMicrophoneLive(bool live) {
    _live = live;
    _applyLive();
  }

  void _applyLive() {
    for (final track
        in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = _live;
    }
  }

  @override
  Future<void> closeMicrophone() async {
    ++_epoch;
    final local = _local;
    _local = null;
    if (local != null) await _release(local);
    voiceCallActive.value = false;
  }

  Future<void> _release(MediaStream stream) async {
    try {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    } catch (_) {
      // Already released by the platform.
    }
  }

  @override
  Future<VoiceLink> connect({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function(VoiceLinkState state) onState,
  }) async {
    final epoch = _epoch;
    if (_local == null) throw StateError('Microphone is not open');
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    final link = _WebRtcLink(pc, onCandidate, onState);
    try {
      final local = _local;
      if (local == null || epoch != _epoch) {
        throw StateError('Microphone closed while connecting');
      }
      for (final track in local.getAudioTracks()) {
        await pc.addTrack(track, local);
      }
    } catch (_) {
      await link.close();
      rethrow;
    }
    return link;
  }
}

class _WebRtcLink implements VoiceLink {
  _WebRtcLink(this._pc, this._onCandidate, this._onState) {
    _pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (_closed || value == null || value.isEmpty) return;
      _onCandidate({
        'candidate': value,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    _pc.onConnectionState = (state) => _report(switch (state) {
      RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
        VoiceLinkState.connected,
      RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
        VoiceLinkState.disconnected,
      RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
        VoiceLinkState.failed,
      RTCPeerConnectionState.RTCPeerConnectionStateClosed =>
        VoiceLinkState.closed,
      _ => VoiceLinkState.connecting,
    });
    // Browsers without connectionState still report a dead ICE transport.
    _pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _report(VoiceLinkState.failed);
      }
    };
    _pc.onTrack = (event) {
      if (_closed || event.track.kind != 'audio') return;
      _remote.add(event.track);
      event.track.enabled = _audible;
      if (event.streams.isNotEmpty) _sink.attach(event.streams.first);
    };
  }

  final RTCPeerConnection _pc;
  final void Function(Map<String, dynamic> candidate) _onCandidate;
  final void Function(VoiceLinkState state) _onState;
  final List<RTCIceCandidate> _held = [];
  final List<MediaStreamTrack> _remote = [];
  final VoiceAudioSink _sink = VoiceAudioSink();
  VoiceLinkState? _reported;
  bool _closed = false, _remoteSet = false, _audible = true;

  void _report(VoiceLinkState state) {
    if (_closed || state == _reported) return;
    _reported = state;
    _onState(state);
  }

  @override
  Future<Map<String, dynamic>> createOffer() async {
    final offer = await _pc.createOffer();
    await _pc.setLocalDescription(offer);
    return {'type': 'offer', 'sdp': offer.sdp};
  }

  @override
  Future<Map<String, dynamic>> acceptOffer(Map<String, dynamic> offer) async {
    await _setRemote(offer, 'offer');
    final answer = await _pc.createAnswer();
    await _pc.setLocalDescription(answer);
    return {'type': 'answer', 'sdp': answer.sdp};
  }

  @override
  Future<void> acceptAnswer(Map<String, dynamic> answer) =>
      _setRemote(answer, 'answer');

  Future<void> _setRemote(Map<String, dynamic> description, String type) async {
    final sdp = description['sdp'];
    if (sdp is! String || description['type'] != type) {
      throw const FormatException('Invalid session description');
    }
    await _pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteSet = true;
    final held = List.of(_held);
    _held.clear();
    for (final candidate in held) {
      await _add(candidate);
    }
  }

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) async {
    final value = candidate['candidate'];
    if (_closed || value is! String || value.isEmpty) return;
    final ice = RTCIceCandidate(
      value,
      candidate['sdpMid'] as String?,
      (candidate['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (_remoteSet) {
      await _add(ice);
    } else {
      _held.add(ice);
    }
  }

  Future<void> _add(RTCIceCandidate candidate) async {
    if (_closed) return;
    try {
      await _pc.addCandidate(candidate);
    } catch (_) {
      // One unusable candidate must not discard the others.
    }
  }

  @override
  void setAudible(bool audible) {
    _audible = audible;
    for (final track in _remote) {
      track.enabled = audible;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pc.onIceCandidate = null;
    _pc.onConnectionState = null;
    _pc.onIceConnectionState = null;
    _pc.onTrack = null;
    _held.clear();
    _remote.clear();
    _sink.detach();
    try {
      await _pc.close();
    } catch (_) {}
    try {
      // close() alone leaves the native connection registered.
      await _pc.dispose();
    } catch (_) {}
  }
}
