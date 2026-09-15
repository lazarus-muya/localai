import 'package:flutter/material.dart';

/// Placeholder for Phase 2: browsing/downloading HuggingFace models,
/// importing existing Ollama models, adding a model by remote URL, and
/// hardware-fit warnings.
class ModelLibraryScreen extends StatelessWidget {
  const ModelLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Models')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'Model library — browse and download from HuggingFace, import '
                'existing Ollama models, or add one by URL.\nComing in a later phase.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
