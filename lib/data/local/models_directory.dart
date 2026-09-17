import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The single directory GGUF files are staged into while downloading, before
/// being uploaded to the Ollama server and deleted.
Future<Directory> getModelsDirectory() async {
  final supportDir = await getApplicationSupportDirectory();
  final modelsDir = Directory(p.join(supportDir.path, 'models'));
  if (!await modelsDir.exists()) await modelsDir.create(recursive: true);
  return modelsDir;
}
