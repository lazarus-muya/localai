import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../data/local/models_directory.dart';
import '../../data/remote/huggingface/huggingface_models.dart';
import '../../domain/entities/hardware_profile.dart';
import '../../domain/usecases/model_recommendation_service.dart';

const modelRecommendationService = ModelRecommendationService();

final hardwareProfileProvider = FutureProvider<HardwareProfile>((ref) {
  return ref.watch(hardwareDetectorProvider).detect();
});

/// Live snapshot of models installed on the active Ollama server. No
/// separate local registry is kept, so this can never drift out of sync
/// with reality.
final installedModelsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final settings = await repo.getSettings();
  return ref.watch(ollamaEngineProvider).listModels(baseUrl: settings.ollamaServerUrl);
});

class ModelActions {
  ModelActions(this._ref);

  final Ref _ref;

  Future<String> _baseUrl() async {
    final repo = _ref.read(chatRepositoryProvider);
    final settings = await repo.getSettings();
    return settings.ollamaServerUrl;
  }

  Future<void> deleteModel(String name) async {
    final engine = _ref.read(ollamaEngineProvider);
    final baseUrl = await _baseUrl();
    await engine.deleteModel(baseUrl: baseUrl, model: name);
    _ref.invalidate(installedModelsProvider);
  }

  Future<void> deleteAllModels() async {
    final engine = _ref.read(ollamaEngineProvider);
    final baseUrl = await _baseUrl();
    final models = await engine.listModels(baseUrl: baseUrl);
    for (final m in models) {
      await engine.deleteModel(baseUrl: baseUrl, model: m.name);
    }
    _ref.invalidate(installedModelsProvider);
  }
}

final modelActionsProvider = Provider<ModelActions>((ref) => ModelActions(ref));

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

/// Tracks in-flight HuggingFace/remote-URL downloads. The GGUF file is
/// staged in the shared local models directory just long enough to hash and
/// upload it to the Ollama server via `/api/create`, then deleted — Ollama
/// keeps its own copy once the model is registered.
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
    final modelsDir = await getModelsDirectory();
    final fileName = key.replaceAll(RegExp(r'[\\/]'), '_');
    final destination = p.join(modelsDir.path, fileName);

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
      final settings = await repo.getSettings();
      final engine = ref.read(ollamaEngineProvider);
      await engine.createModelFromGguf(
        baseUrl: settings.ollamaServerUrl,
        modelName: modelName,
        ggufPath: destination,
      );

      // The staged download is redundant once Ollama has its own copy.
      final staged = File(destination);
      if (await staged.exists()) await staged.delete();

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
      // Registration failed (e.g. Ollama rejected the GGUF) but the file was
      // already fully downloaded — remove it rather than leaving a dead copy
      // on disk, since retrying without a different file won't help.
      final leftover = File(destination);
      if (await leftover.exists()) {
        await leftover.delete();
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
