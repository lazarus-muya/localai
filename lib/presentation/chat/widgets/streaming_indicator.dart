import 'dart:async';

import 'package:flutter/material.dart';

/// Shows "Thinking…" while waiting for the first token. When the caller
/// knows (via [isModelWarm]) whether Ollama already had the model resident
/// in memory, that's authoritative: a warm model never shows the "loading"
/// message, and a cold one shows it immediately. Otherwise falls back to
/// guessing from elapsed time, which just means "this is taking a while".
class StreamingIndicator extends StatefulWidget {
  const StreamingIndicator({super.key, required this.since, this.isModelWarm});

  final DateTime since;
  final bool? isModelWarm;

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
    final label = switch (widget.isModelWarm) {
      true => 'Thinking…',
      false => 'Loading model into memory…',
      null => _elapsed.inSeconds < 4 ? 'Thinking…' : 'Loading model into memory…',
    };
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
