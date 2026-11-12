import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_session.dart';

enum GameFeedbackEvent { flip, match, mismatch, turn }

/// Injection boundary: play completes only after its cue has stopped.
abstract interface class GameFeedbackAudio {
  Future<void> unlock();
  Future<void> play(GameFeedbackEvent event);
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class GameFeedbackHaptics {
  Future<void> play(GameFeedbackEvent event);
}

class PlatformGameHaptics implements GameFeedbackHaptics {
  const PlatformGameHaptics();
  @override
  Future<void> play(GameFeedbackEvent event) async {
    if (kIsWeb) return;
    switch (event) {
      case GameFeedbackEvent.flip:
      case GameFeedbackEvent.turn:
        await HapticFeedback.selectionClick();
      case GameFeedbackEvent.match:
        await HapticFeedback.lightImpact();
      case GameFeedbackEvent.mismatch:
        await HapticFeedback.mediumImpact();
    }
  }
}

/// Screen-owned feedback; presentation callbacks decide when events occur.
/// Construction is side-effect free, including for widget-test subclasses.
class GameFeedback {
  GameFeedback(
    this.prefs, {
    GameFeedbackAudio? audio,
    GameFeedbackHaptics? haptics,
  }) : _audio = audio,
       _haptics = haptics ?? const PlatformGameHaptics();

  final SharedPreferences prefs;
  GameFeedbackAudio? _audio;
  final GameFeedbackHaptics _haptics;
  Future<void> _queue = Future.value();
  Future<void>? _unlocking;
  bool _active = true, _disposed = false;
  int _generation = 0, _pending = 0;

  GameFeedbackAudio get _sound => _audio ??= AudioplayersGameAudio();
  bool get _canPlay => _active && !_disposed;
  // While a voice call holds the process audio session, cue playback would
  // reconfigure and deactivate it underneath the call. Haptics still play.
  bool get soundEnabled =>
      (prefs.getBool('sound') ?? true) && (kIsWeb || !voiceCallActive.value);
  bool get hapticsEnabled => prefs.getBool('haptics') ?? true;

  /// For tests and orderly shutdown; UI callbacks do not await audio.
  Future<void> get settled => _queue;

  /// Call directly from a valid user gesture, before awaiting game/network work.
  /// Browser permission failures remain silent and a later gesture can retry.
  void unlock() {
    if (!_canPlay || !soundEnabled || _unlocking != null) return;
    final generation = _generation;
    final audio = _sound;
    final job = _quiet(() async {
      await audio.unlock().timeout(const Duration(seconds: 2));
      if (!_canPlay || generation != _generation) await audio.stop();
    });
    _unlocking = job;
    unawaited(
      job.then((_) {
        if (identical(_unlocking, job)) _unlocking = null;
      }),
    );
  }

  void play(GameFeedbackEvent event) {
    if (!_canPlay || _pending >= 8) return;
    if (!soundEnabled && !hapticsEnabled) return;
    final generation = _generation;
    _pending++;
    _queue = _queue.then((_) async {
      try {
        if (!_canPlay || generation != _generation) return;
        if (hapticsEnabled) await _quiet(() => _haptics.play(event));
        if (!_canPlay || generation != _generation || !soundEnabled) return;
        await _unlocking;
        if (!_canPlay || generation != _generation || !soundEnabled) return;
        await _quiet(() async {
          await _sound.play(event).timeout(const Duration(seconds: 2));
        });
      } finally {
        _pending--;
      }
    });
  }

  /// A pause/route exit invalidates every queued event; resuming never replays it.
  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    _generation++;
    if (!active && _audio != null) unawaited(_quiet(_audio!.stop));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _generation++;
    if (_audio != null) unawaited(_quiet(_audio!.dispose));
  }

  Future<void> _quiet(Future<void> Function() operation) async {
    try {
      await operation().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Sound/haptic support and browser permissions never affect gameplay.
      try {
        await _audio?.stop().timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }
  }
}

/// One player and one original WAV sprite: cue changes reuse the browser's
/// media element/audio context. Playback is serialized by GameFeedback.
class AudioplayersGameAudio implements GameFeedbackAudio {
  AudioPlayer? _player;
  Future<void>? _preparing;
  Completer<void>? _playing;
  bool _disposed = false, _unlocked = false;
  int _generation = 0;

  static const clips = {
    GameFeedbackEvent.flip: (40, 55),
    GameFeedbackEvent.match: (1100, 200),
    GameFeedbackEvent.mismatch: (2350, 160),
    GameFeedbackEvent.turn: (3550, 110),
  };

  Future<void> _prepare() => _preparing ??= _load();
  Future<void> _load() async {
    // The game has no other audio subsystem; expected platform/autoplay errors
    // are handled here rather than printed by the plugin's default logger.
    AudioLogger.logLevel = AudioLogLevel.none;
    final player = _player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    if (!kIsWeb) {
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    }
    await player.setSource(AssetSource('audio/game_feedback.wav'));
  }

  @override
  Future<void> unlock() async {
    if (_disposed || _unlocked) return;
    final generation = _generation;
    await _prepare();
    if (_disposed || generation != _generation) return;
    // Play only the silent lead-in. Never emit a pre-animation feedback cue.
    await _segment(0, 15, 0, generation);
    if (!_disposed && generation == _generation) _unlocked = true;
  }

  @override
  Future<void> play(GameFeedbackEvent event) async {
    if (_disposed) return;
    final generation = _generation;
    await _prepare();
    if (_disposed || generation != _generation) return;
    final (start, length) = clips[event]!;
    await _segment(start, length, 0.65, generation);
  }

  Future<void> _segment(
    int start,
    int length,
    double volume,
    int generation,
  ) async {
    final player = _player!;
    await player.pause();
    if (_disposed || generation != _generation) return;
    await player.setVolume(volume);
    if (_disposed || generation != _generation) return;
    await player.seek(Duration(milliseconds: start));
    if (_disposed || generation != _generation) return;
    await player.resume();
    if (_disposed || generation != _generation) {
      await player.pause();
      return;
    }
    final done = _playing = Completer<void>();
    final timer = Timer(Duration(milliseconds: length), () {
      if (!done.isCompleted) done.complete();
    });
    try {
      await done.future;
    } finally {
      timer.cancel();
      if (identical(_playing, done)) _playing = null;
      await player.pause();
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _unlocked = false;
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    await _player?.pause();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _player?.dispose();
  }
}
