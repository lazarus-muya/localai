import 'dart:async';

import 'package:flutter/material.dart';

/// Shows "Thinking…" while waiting for the first token. When the engine
/// reports that the model is being loaded ([isLoadingModel] — the on-device
/// backend tells us directly, since it reads a multi-GB GGUF into memory),
/// that is authoritative. Otherwise [isModelWarm] decides: a warm Ollama
/// model never shows the loading message, and a cold one shows it right away.
/// With neither signal we fall back to guessing from elapsed time.
class StreamingIndicator extends StatefulWidget {
  const StreamingIndicator({
    super.key,
    required this.since,
    this.isModelWarm,
    this.isLoadingModel = false,
  });

  final DateTime since;
  final bool? isModelWarm;
  final bool isLoadingModel;

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
    final label = switch ((widget.isLoadingModel, widget.isModelWarm)) {
      (true, _) => 'Loading model into memory…',
      (false, true) => 'Thinking…',
      (false, false) => 'Loading model into memory…',
      (false, null) => _elapsed.inSeconds < 4 ? 'Thinking…' : 'Loading model into memory…',
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
