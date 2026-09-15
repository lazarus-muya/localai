import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model_library_controller.dart';

class AddRemoteModelDialog extends ConsumerStatefulWidget {
  const AddRemoteModelDialog({super.key});

  @override
  ConsumerState<AddRemoteModelDialog> createState() => _AddRemoteModelDialogState();
}

class _AddRemoteModelDialogState extends ConsumerState<AddRemoteModelDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add model from URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'Direct .gguf URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Model name (for Ollama)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final url = _urlController.text.trim();
            final name = _nameController.text.trim();
            if (url.isEmpty || name.isEmpty) return;
            ref.read(downloadManagerProvider.notifier).downloadAndRegister(
                  key: url,
                  label: name,
                  url: url,
                  modelName: name,
                );
            Navigator.pop(context);
          },
          child: const Text('Download'),
        ),
      ],
    );
  }
}
