import 'package:flutter/foundation.dart';

/// The platform audio session is one per process. Lobby voice raises this for
/// as long as it holds the microphone, so every other sound in the app plays
/// through the call's session instead of reconfiguring it underneath the call.
final ValueNotifier<bool> voiceCallActive = ValueNotifier<bool>(false);
