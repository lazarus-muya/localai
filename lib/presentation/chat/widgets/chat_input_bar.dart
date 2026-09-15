import 'package:flutter/material.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 6,
                enabled: !isSending,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Message the model…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            if (isSending)
              IconButton.filledTonal(
                icon: const Icon(Icons.stop),
                tooltip: 'Stop generating',
                onPressed: onStop,
              )
            else
              IconButton.filled(
                icon: const Icon(Icons.send),
                tooltip: 'Send',
                onPressed: onSend,
              ),
          ],
        ),
      ),
    );
  }
}
