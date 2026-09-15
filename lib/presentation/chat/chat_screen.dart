import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'chat_controller.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    final newId =
        await ref.read(chatControllerProvider(widget.conversationId).notifier).sendMessage(text);
    if (newId != null && mounted) {
      context.go('/chat/$newId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = widget.conversationId;
    final uiState = ref.watch(chatControllerProvider(conversationId));

    if (conversationId != null) {
      ref.listen(conversationMessagesProvider(conversationId), (_, _) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: conversationId == null
                ? const _EmptyChatState()
                : ref.watch(conversationMessagesProvider(conversationId)).when(
                      data: (messages) {
                        if (messages.isEmpty) return const _EmptyChatState();
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) => MessageBubble(message: messages[index]),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Failed to load conversation: $e')),
                    ),
          ),
          if (uiState.errorMessage != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                uiState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ChatInputBar(
            controller: _textController,
            isSending: uiState.isSending,
            onSend: _send,
            onStop: () =>
                ref.read(chatControllerProvider(widget.conversationId).notifier).cancel(),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Start a new conversation', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
