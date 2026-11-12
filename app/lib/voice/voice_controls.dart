import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../palette.dart';
import 'lobby_voice.dart';

/// Join/leave and mute controls for lobby voice, in a compact toolbar form or
/// a full-width panel form with a status line.
class LobbyVoiceControls extends StatelessWidget {
  const LobbyVoiceControls({
    super.key,
    required this.voice,
    this.compact = false,
  });

  final LobbyVoice voice;
  final bool compact;

  static String statusText(BuildContext context, LobbyVoice voice) {
    if (voice.micError != null) return tr(context, voice.micError!);
    if (voice.paused) return tr(context, 'Voce in pausa');
    return switch (voice.status) {
      VoiceStatus.off => tr(
        context,
        'La voce è per tutta la lobby. Non viene registrata e puoi giocare senza.',
      ),
      VoiceStatus.starting => tr(context, 'Connessione…'),
      VoiceStatus.connecting => tr(context, 'Connessione voce…'),
      VoiceStatus.alone => tr(context, 'In attesa degli altri'),
      VoiceStatus.unreachable => tr(
        context,
        'Impossibile collegare la voce. Esci dalla voce e riprova.',
      ),
      VoiceStatus.live =>
        voice.muted ? tr(context, 'Voce silenziata') : tr(context, 'In voce'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final joined = voice.enabled;
        final silenced = voice.muted || voice.paused;
        final canToggle = joined || (voice.available && !voice.busy);
        final muteTooltip = voice.muted
            ? tr(context, 'Riattiva microfono')
            : tr(context, 'Silenzia');
        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: joined
                    ? tr(context, 'Esci dalla voce')
                    : tr(context, 'Attiva voce'),
                onPressed: canToggle ? () => voice.toggleJoin() : null,
                icon: Icon(
                  joined ? Icons.call_end_rounded : Icons.mic_none_rounded,
                  color: joined ? coral : ink,
                  size: 20,
                ),
              ),
              if (joined)
                IconButton(
                  tooltip: muteTooltip,
                  onPressed: voice.toggleMute,
                  icon: Icon(
                    silenced ? Icons.mic_off_rounded : Icons.mic_rounded,
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
              statusText(context, voice),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ink, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: canToggle ? () => voice.toggleJoin() : null,
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
                    tooltip: muteTooltip,
                    onPressed: voice.toggleMute,
                    icon: Icon(
                      silenced ? Icons.mic_off_rounded : Icons.mic_rounded,
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
