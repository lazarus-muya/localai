import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../domain/usecases/model_recommendation_service.dart';

class FitBadge extends StatelessWidget {
  const FitBadge({super.key, required this.fit});

  final ModelFit fit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (label, color) = switch (fit) {
      ModelFit.fits => ('Fits', palette.success),
      ModelFit.tight => ('Tight fit', palette.warning),
      ModelFit.tooLarge => ('Too large', palette.danger),
      ModelFit.unknown => ('Unknown', palette.mutedText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
