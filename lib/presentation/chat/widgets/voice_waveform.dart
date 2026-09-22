import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../voice_chat_controller.dart';

/// Animated audio-level bars for the voice chat overlay. Driven by the real
/// microphone sound level while listening and by a smooth oscillation while
/// the model thinks or speaks, so the bars always "breathe".
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key, required this.phase, required this.micLevel, this.color});

  final VoiceChatPhase phase;
  final double micLevel;
  final Color? color;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  double _smoothedActivity = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _targetActivity {
    switch (widget.phase) {
      case VoiceChatPhase.listening:
        return widget.micLevel.clamp(0.12, 1.0);
      case VoiceChatPhase.speaking:
        return 0.85;
      case VoiceChatPhase.thinking:
        return 0.3;
      default:
        return 0.06;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        _smoothedActivity += (_targetActivity - _smoothedActivity) * 0.12;
        return CustomPaint(
          size: const Size(double.infinity, double.infinity),
          painter: _VoiceWavePainter(
            activity: _smoothedActivity,
            progress: _controller.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  _VoiceWavePainter({
    required this.activity,
    required this.progress,
    required this.color,
  });

  final double activity;
  final double progress;
  final Color color;

  static const _barCount = 29;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final gap = size.width / (_barCount * 2);
    final barWidth = gap * 0.62;
    final maxBar = size.height * 0.34;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _barCount; i++) {
      final x = gap + i * gap * 2;
      final wave = 0.5 + 0.5 * math.sin(progress * 2 * math.pi * 2 + (i - _barCount / 2) * 0.5);
      final height = 2.0 + maxBar * activity * (0.35 + 0.65 * wave);
      final rect = Rect.fromCenter(
        center: Offset(x, centerY),
        width: barWidth,
        height: height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter oldDelegate) =>
      oldDelegate.activity != activity ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}