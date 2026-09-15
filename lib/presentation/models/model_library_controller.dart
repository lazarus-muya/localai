import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/di/providers.dart';
import '../../data/remote/huggingface/huggingface_models.dart';
import '../../domain/entities/hardware_profile.dart';
import '../../domain/usecases/model_recommendation_service.dart';

const modelRecommendationService = ModelRecommendationService();

final hardwareProfileProvider = FutureProvider<HardwareProfile>((ref) {
  return ref.watch(hardwareDetectorProvider).detect();
});

/// Live snapshot of models the local Ollama server already has. This is the
/// source of truth for "installed models" — no separate local registry is
/// kept, so it can never drift out of sync with what Ollama actually has.
final installedModelsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final engine = ref.watch(ollamaEngineProvider);
  final settings = await repo.getSettings();
  return engine.listModels(baseUrl: settings.ollamaServerUrl);
});

final huggingFaceSearchProvider =
    FutureProvider.autoDispose.family<List<HuggingFaceModelSummary>, String>((ref, query) async {
  final client = ref.watch(huggingFaceApiClientProvider);
  return client.searchGgufModels(query);
});

final huggingFaceFilesProvider =
    FutureProvider.autoDispose.family<List<HuggingFaceFile>, String>((ref, repoId) async {
  final client = ref.watch(huggingFaceApiClientProvider);
  return client.listGgufFiles(repoId);
});

class DownloadState {
  const DownloadState({
    required this.label,
    required this.receivedBytes,
    this.totalBytes,
    this.error,
    this.done = false,
  });

  final String label;
  final int receivedBytes;
  final int? totalBytes;
  final String? error;
  final bool done;

  double? get fraction => totalBytes == null || totalBytes == 0 ? null : receivedBytes / totalBytes!;

  DownloadState copyWith({int? receivedBytes, int? totalBytes, String? error, bool? done}) {
    return DownloadState(
      label: label,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error ?? this.error,
      done: done ?? this.done,
    );
  }
}

/// Tracks in-flight HuggingFace/remote-URL downloads and, on completion,
/// registers the resulting GGUF file with Ollama via `/api/create`.
class DownloadManager extends Notifier<Map<String, DownloadState>> {
  @override
  Map<String, DownloadState> build() => {};

  Future<void> downloadAndRegister({
    required String key,
    required String label,
    required String url,
    required String modelName,
  }) async {
    final downloader = ref.read(modelDownloaderProvider);
    final supportDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(supportDir.path, 'models'));
    if (!await modelsDir.exists()) await modelsDir.create(recursive: true);
    final destination = p.join(modelsDir.path, key.replaceAll(RegExp(r'[\\/]'), '_'));

    state = {...state, key: DownloadState(label: label, receivedBytes: 0)};

    try {
      await for (final progress in downloader.download(url: url, destinationPath: destination)) {
        final current = state[key];
        if (current == null) return; // dismissed mid-download
        state = {
          ...state,
          key: current.copyWith(receivedBytes: progress.receivedBytes, totalBytes: progress.totalBytes),
        };
      }

      final repo = ref.read(chatRepositoryProvider);
      final engine = ref.read(ollamaEngineProvider);
      final settings = await repo.getSettings();
      await engine.createModelFromGguf(
        baseUrl: settings.ollamaServerUrl,
        modelName: modelName,
        ggufPath: destination,
      );

      final finalState = state[key];
      if (finalState != null) {
        state = {...state, key: finalState.copyWith(done: true)};
      }
      ref.invalidate(installedModelsProvider);
    } catch (e) {
      final current = state[key];
      if (current != null) {
        state = {...state, key: current.copyWith(error: e.toString())};
      }
    }
  }

  void dismiss(String key) {
    final next = {...state}..remove(key);
    state = next;
  }
}

final downloadManagerProvider =
    NotifierProvider<DownloadManager, Map<String, DownloadState>>(DownloadManager.new);
