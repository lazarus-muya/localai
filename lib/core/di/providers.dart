import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download/model_downloader.dart';
import '../../data/hardware/hardware_detector.dart';
import '../../data/hardware/hardware_detector_android.dart';
import '../../data/hardware/hardware_detector_windows.dart';
import '../../data/local/database/app_database.dart';
import '../../data/local/local_model_store.dart';
import '../../data/remote/huggingface/huggingface_api_client.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/engine/inference_engine.dart';
import '../../domain/engine/llama_cpp_engine.dart';
import '../../domain/engine/ollama_engine.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/hardware_profile.dart';
import '../../domain/repositories/chat_repository.dart';
import '../speech/speech_recognition.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(appDatabaseProvider));
});

/// Live app settings, shared across screens so a change made in one place
/// (e.g. switching engine mode in Settings) is immediately reflected
/// anywhere else that watches it, including screens kept alive in the
/// adaptive shell's [StatefulShellRoute.indexedStack].
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(chatRepositoryProvider).watchSettings();
});

final dioProvider = Provider<Dio>((ref) => Dio());

final ollamaEngineProvider = Provider<OllamaEngine>((ref) {
  return OllamaEngine(ref.watch(dioProvider));
});

final llamaCppEngineProvider = Provider<LlamaCppEngine>((ref) {
  final engine = LlamaCppEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final localModelStoreProvider = Provider<LocalModelStore>((ref) {
  return const LocalModelStore();
});

/// The `InferenceEngine` matching the active backend. Defaults to the remote
/// (Ollama) engine until settings load, mirroring the persisted default.
final activeEngineProvider = Provider<InferenceEngine>((ref) {
  final backend = ref
      .watch(appSettingsProvider)
      .maybeWhen(data: (s) => s.backend, orElse: () => InferenceBackend.remote);
  return backend == InferenceBackend.onDevice
      ? ref.watch(llamaCppEngineProvider)
      : ref.watch(ollamaEngineProvider);
});

/// Loads the on-device model once at startup: the saved default (last used)
/// model, or the first downloaded one if there is no default or it was
/// deleted. Watched from the app root; failures are swallowed because the
/// first chat will load the model and report any real error itself.
final startupModelPreloadProvider = FutureProvider<void>((ref) async {
  final settings = await ref.read(appSettingsProvider.future);
  if (settings.backend != InferenceBackend.onDevice) return;

  try {
    final engine = ref.read(llamaCppEngineProvider);
    final baseUrl = settings.ollamaServerUrl;
    final installed = await engine.listModels(baseUrl: baseUrl);
    if (installed.isEmpty) return;

    var model = settings.defaultLocalModel;
    if (model == null || !installed.any((m) => m.name == model)) {
      model = installed.first.name;
      await ref
          .read(chatRepositoryProvider)
          .updateSettings(settings.copyWith(defaultLocalModel: model));
    }
    await engine.preloadModel(baseUrl: baseUrl, model: model);
  } catch (_) {}
});

final huggingFaceApiClientProvider = Provider<HuggingFaceApiClient>((ref) {
  return HuggingFaceApiClient(ref.watch(dioProvider));
});

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  return ModelDownloader(ref.watch(dioProvider));
});

final hardwareDetectorProvider = Provider<HardwareDetector>((ref) {
  if (Platform.isWindows) return WindowsHardwareDetector();
  if (Platform.isAndroid) return AndroidHardwareDetector();
  return _NullHardwareDetector();
});

final speechRecognitionProvider = Provider<SpeechRecognitionService>((ref) {
  return SpeechRecognitionService();
});

class _NullHardwareDetector implements HardwareDetector {
  @override
  Future<HardwareProfile> detect() async {
    return HardwareProfile(platform: AppPlatform.other, cpuCores: Platform.numberOfProcessors);
  }
}
