import 'package:flutter/foundation.dart';

/// What lobby voice needs from the room connection. The controller never
/// touches sockets, sessions or game state beyond this boundary.
abstract interface class VoiceChannel implements Listenable {
  String? get playerId;

  /// The server confirmed the seat on the live connection.
  bool get seated;

  /// Changes whenever the seat is confirmed on a new connection.
  int get sessionSerial;

  /// Latest `voice`/`state` message of this connection, if one arrived.
  Map<String, dynamic>? get voiceRoster;

  /// Every `voice` message of the live connection, in arrival order.
  Stream<Map<String, dynamic>> get voiceMessages;

  void send(Map<String, dynamic> action);
}

enum VoiceLinkState { connecting, connected, disconnected, failed, closed }

/// Media boundary: microphone capture and one audio link per remote player.
/// The controller owns every decision; an engine only executes them, so the
/// negotiation and recovery rules run in tests without the WebRTC plugin.
abstract interface class VoiceEngine {
  /// Acquires the microphone, asking for permission when needed. Throws when
  /// it is denied or unavailable; nothing stays open in that case.
  Future<void> openMicrophone();

  /// Whether captured audio is sent. Capture itself stays open.
  void setMicrophoneLive(bool live);

  Future<void> closeMicrophone();

  /// Creates a link that already carries the open microphone. Callbacks stop
  /// once [VoiceLink.close] has been called.
  Future<VoiceLink> connect({
    required List<Map<String, dynamic>> iceServers,
    required void Function(Map<String, dynamic> candidate) onCandidate,
    required void Function(VoiceLinkState state) onState,
  });
}

/// One peer connection attempt. Descriptions and candidates are the plain
/// JSON payloads of the `voice-v1` protocol.
abstract interface class VoiceLink {
  Future<Map<String, dynamic>> createOffer();
  Future<Map<String, dynamic>> acceptOffer(Map<String, dynamic> offer);
  Future<void> acceptAnswer(Map<String, dynamic> answer);

  /// Candidates may arrive before the remote description; the link holds them.
  Future<void> addCandidate(Map<String, dynamic> candidate);

  /// Whether the remote player's audio is played.
  void setAudible(bool audible);

  Future<void> close();
}
