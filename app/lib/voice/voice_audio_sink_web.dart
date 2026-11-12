import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:web/web.dart' as web;

/// A browser plays a remote track only while a media element holds it.
class VoiceAudioSink {
  web.HTMLAudioElement? _element;

  void attach(MediaStream stream) {
    if (stream is! MediaStreamWeb) return;
    var element = _element;
    if (element == null) {
      element = _element = web.HTMLAudioElement()
        ..autoplay = true
        ..style.display = 'none';
      web.document.body?.append(element);
    }
    element.srcObject = stream.jsStream;
    // Autoplay is allowed after the tap that turned voice on; if a browser
    // still refuses, the element starts with the next user interaction.
    unawaited(element.play().toDart.then((_) {}, onError: (Object _) {}));
  }

  void detach() {
    final element = _element;
    _element = null;
    if (element == null) return;
    element.srcObject = null;
    element.remove();
  }
}
