import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'voice_chat_controller.dart';
import 'widgets/voice_waveform.dart';

/// Gemini Live-style voice session shown as a translucent full-screen overlay
/// above [ChatScreen]. The chat stays visible behind a dim scrim while the
/// waveform animates as the user talks or the model replies. Utterances go
/// through the normal chat pipeline, so the conversation is populated
/// underneath exactly as if it had been typed.
class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key, required this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceChatControllerProvider(widget.conversationId).notifier).start();
    });
  }

  @override
  void dispose() {
    // Leaving the overlay always exits voice mode: stop reading anything
    // aloud, stop listening and cancel whatever reply is still generating.
    ref.read(voiceChatControllerProvider(widget.conversationId).notifier).shutdown();
    super.dispose();
  }

  void _close() {
    ref.read(voiceChatControllerProvider(widget.conversationId).notifier).shutdown();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceChatControllerProvider(widget.conversationId));

    ref.listen(
      voiceChatControllerProvider(widget.conversationId).select((s) => s.activeConversationId),
      (previous, next) {
        if (next != null && next != widget.conversationId) {
          context.go('/chat/$next');
        }
      },
    );

    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      alignment: Alignment.center,
      child: SafeArea(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    tooltip: 'Close voice chat',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _close,
                  ),
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Live voice chat',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
                const SizedBox(height: 28),
                state.phase == VoiceChatPhase.unsupported ? const SizedBox.shrink() : SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: VoiceWaveform(phase: state.phase, micLevel: state.micLevel),
                ),
                const SizedBox(height: 32),
                Text(
                  _statusLabel(state.phase),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.phase == VoiceChatPhase.thinking ||
                    state.phase == VoiceChatPhase.speaking)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(
                            voiceChatControllerProvider(widget.conversationId)
                                .notifier,
                          )
                          .interrupt(),
                      icon: const Icon(Icons.stop, size: 17),
                      label: const Text('Interrupt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                if (state.transcript.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        state.transcript,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                if (state.phase == VoiceChatPhase.unsupported) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: const Text(
                      'Voice input is not supported on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
                // const SizedBox(height: 24),
                // Text(
                //   'You can keep typing or close to stop listening.',
                //   style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(VoiceChatPhase phase) {
    return switch (phase) {
      VoiceChatPhase.starting => 'Waking up the microphone…',
      VoiceChatPhase.listening => 'Listening…',
      VoiceChatPhase.thinking => 'Thinking…',
      VoiceChatPhase.speaking => 'Speaking…',
      VoiceChatPhase.unsupported => 'Voice input unavailable',
    };
  }
}