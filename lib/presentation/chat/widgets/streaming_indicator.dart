import 'dart:async';

import 'package:flutter/material.dart';

/// Shows "Thinking…" while waiting for the first token, then switches to a
/// "loading the model" message if nothing has arrived after a few seconds —
/// distinguishing a normal cold-start delay from the model actually working.
class StreamingIndicator extends StatefulWidget {
  const StreamingIndicator({super.key, required this.since});

  final DateTime since;

  @override
  State<StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<StreamingIndicator> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.since);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(widget.since));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _elapsed.inSeconds < 4 ? 'Thinking…' : 'Loading model into memory…';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
