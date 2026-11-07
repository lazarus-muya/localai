import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/speech/text_to_speech.dart';
import '../../../domain/entities/message.dart';
import 'rich_content_view.dart';
import 'streaming_indicator.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.isModelWarm,
    this.isLoadingModel = false,
  });

  final ChatMessage message;
  final bool? isModelWarm;
  final bool isLoadingModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh;
    final textColor = isUser ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final isEmptyStreaming = message.content.isEmpty && message.status == MessageStatus.streaming;

    final speech = ref.watch(speechControllerProvider);
    final isSpeakingThis = speech.isSpeaking && speech.speakingKey == message.id;
    final canRead = message.content.trim().isNotEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Card(
          color: bubbleColor,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEmptyStreaming)
                  StreamingIndicator(
                    since: message.createdAt,
                    isModelWarm: isModelWarm,
                    isLoadingModel: isLoadingModel,
                  )
                else
                  RichContentView(content: message.content, textColor: textColor),
                if (message.status == MessageStatus.error && message.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message.errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                if (message.status == MessageStatus.cancelled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Stopped', style: Theme.of(context).textTheme.labelSmall),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.status == MessageStatus.streaming && !isEmptyStreaming)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (message.tokensPerSecond != null)
                      Text(
                        '${message.tokensPerSecond!.toStringAsFixed(1)} tok/s',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    const Spacer(),
                    if (!isUser && canRead)
                      IconButton(
                        icon: Icon(
                          isSpeakingThis ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                          size: 16,
                        ),
                        tooltip: isSpeakingThis ? 'Stop reading' : 'Read aloud',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          final notifier = ref.read(speechControllerProvider.notifier);
                          if (isSpeakingThis) {
                            notifier.stop();
                          } else {
                            notifier.speak(message.content, key: message.id);
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy',
                      visualDensity: VisualDensity.compact,
                      onPressed: message.content.isEmpty
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await Clipboard.setData(ClipboardData(text: message.content));
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              } catch (_) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Copy failed'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
