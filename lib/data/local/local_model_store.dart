import 'dart:io';

import 'package:path/path.dart' as p;

import 'models_directory.dart';

/// A GGUF model that lives on the device and can be loaded by the embedded
/// llama.cpp engine.
class LocalModelFile {
  const LocalModelFile({required this.name, required this.path, required this.sizeBytes});

  /// Stable identifier used across settings and chat (the GGUF filename
  /// without extension).
  final String name;

  /// Absolute path to the `.gguf` file on disk.
  final String path;

  final int sizeBytes;

  String get fileName => p.basename(path);
}

/// Reads and maintains the on-device GGUF library. Downloaded files are
/// stored directly in [getModelsDirectory] and discovered from disk on every
/// call, so the registry can never drift from reality the way a persisted
/// index could.
class LocalModelStore {
  const LocalModelStore();

  Future<List<LocalModelFile>> list() async {
    final dir = await getModelsDirectory();
    if (!await dir.exists()) return const [];
    final files = <LocalModelFile>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.gguf')) continue;
      files.add(LocalModelFile(
        name: p.basenameWithoutExtension(entity.path),
        path: entity.path,
        sizeBytes: await entity.length(),
      ));
    }
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return files;
  }

  Future<LocalModelFile?> resolve(String name) async {
    final models = await list();
    for (final model in models) {
      if (model.name == name) return model;
    }
    // Tolerate a name that still carries the .gguf extension.
    final normalized = p.basenameWithoutExtension(name);
    for (final model in models) {
      if (model.name == normalized) return model;
    }
    return null;
  }

  Future<void> delete(String name) async {
    final model = await resolve(name);
    if (model == null) return;
    final file = File(model.path);
    if (await file.exists()) await file.delete();
  }
}
