import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;

/// Native platforms route remote audio to the device output themselves.
class VoiceAudioSink {
  void attach(MediaStream stream) {}
  void detach() {}
}
