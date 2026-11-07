import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/di/providers.dart';
import '../../data/local/models_directory.dart';
import '../../data/remote/huggingface/huggingface_models.dart';
import '../../domain/entities/app_settings.dart' show InferenceBackend;
import '../../domain/entities/hardware_profile.dart';
import '../../domain/usecases/model_recommendation_service.dart';

const modelRecommendationService = ModelRecommendationService();

final hardwareProfileProvider = FutureProvider<HardwareProfile>((ref) {
  return ref.watch(hardwareDetectorProvider).detect();
});

/// Live snapshot of models available on the active backend. For the remote
/// (Ollama) backend this lists models registered on the server; for the
/// on-device backend it lists downloaded GGUF files. No separate registry is
/// kept, so this can never drift out of sync with reality.
final installedModelsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final settings = await repo.getSettings();
  final engine = settings.backend == InferenceBackend.onDevice
      ? ref.watch(llamaCppEngineProvider)
      : ref.watch(ollamaEngineProvider);
  return engine.listModels(baseUrl: settings.ollamaServerUrl);
});

/// GGUF models downloaded to the device for the embedded engine.
final localModelsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(localModelStoreProvider).list();
});

class ModelActions {
  ModelActions(this._ref);

  final Ref _ref;

  Future<(String baseUrl, bool isOnDevice)> _activeBackend() async {
    final repo = _ref.read(chatRepositoryProvider);
    final settings = await repo.getSettings();
    return (
      settings.ollamaServerUrl,
      settings.backend == InferenceBackend.onDevice,
    );
  }

  Future<void> deleteModel(String name) async {
    final (baseUrl, isOnDevice) = await _activeBackend();
    final engine = isOnDevice
        ? _ref.read(llamaCppEngineProvider)
        : _ref.read(ollamaEngineProvider);
    await engine.deleteModel(baseUrl: baseUrl, model: name);
    _ref.invalidate(installedModelsProvider);
    _ref.invalidate(localModelsProvider);
  }

  Future<void> deleteAllModels() async {
    final (baseUrl, isOnDevice) = await _activeBackend();
    final engine = isOnDevice
        ? _ref.read(llamaCppEngineProvider)
        : _ref.read(ollamaEngineProvider);
    final models = await engine.listModels(baseUrl: baseUrl);
    for (final m in models) {
      await engine.deleteModel(baseUrl: baseUrl, model: m.name);
    }
    _ref.invalidate(installedModelsProvider);
    _ref.invalidate(localModelsProvider);
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

/// Tracks in-flight HuggingFace/remote-URL downloads.
///
/// On the remote (Ollama) backend the GGUF is staged in the shared local
/// models directory just long enough to hash and upload it to the Ollama
/// server via `/api/create`, then deleted — Ollama keeps its own copy once the
/// model is registered. On the on-device backend the file is simply kept in
/// that directory, where the embedded engine loads it directly.
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

      if (settings.backend == InferenceBackend.onDevice) {
        // Keep the GGUF on-device for the embedded engine. Rename it to a
        // stable `<modelName>.gguf` so the model's display name matches the
        // file it was registered under.
        final finalPath = p.join(modelsDir.path, '$modelName.gguf');
        final staged = File(destination);
        if (destination != finalPath) {
          final target = File(finalPath);
          if (await target.exists()) await target.delete();
          if (await staged.exists()) await staged.rename(finalPath);
        }
      } else {
        final engine = ref.read(ollamaEngineProvider);
        await engine.createModelFromGguf(
          baseUrl: settings.ollamaServerUrl,
          modelName: modelName,
          ggufPath: destination,
        );

        // The staged download is redundant once Ollama has its own copy.
        final staged = File(destination);
        if (await staged.exists()) await staged.delete();
      }

      final finalState = state[key];
      if (finalState != null) {
        state = {...state, key: finalState.copyWith(done: true)};
      }
      ref.invalidate(installedModelsProvider);
      ref.invalidate(localModelsProvider);
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
