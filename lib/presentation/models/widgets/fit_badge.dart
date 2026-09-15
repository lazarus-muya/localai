import 'package:flutter/material.dart';

import '../../../domain/usecases/model_recommendation_service.dart';

class FitBadge extends StatelessWidget {
  const FitBadge({super.key, required this.fit});

  final ModelFit fit;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (fit) {
      ModelFit.fits => ('Fits', Colors.green),
      ModelFit.tight => ('Tight fit', Colors.orange),
      ModelFit.tooLarge => ('Too large', Colors.red),
      ModelFit.unknown => ('Unknown', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
