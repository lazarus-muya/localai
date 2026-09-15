import 'package:flutter/material.dart';

class StreamingIndicator extends StatelessWidget {
  const StreamingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Thinking…'),
      ],
    );
  }
}
