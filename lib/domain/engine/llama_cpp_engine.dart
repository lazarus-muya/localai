import 'dart:async';
import 'dart:io';

import 'package:llm_llamacpp/llm_llamacpp.dart';

import '../../core/error/app_exception.dart';
import '../../data/local/local_model_store.dart';
import '../entities/inference_settings.dart';
import '../entities/message.dart' show ChatRole;
import 'inference_engine.dart';

/// On-device inference backend: llama.cpp embedded in the app through FFI.
///
/// Unlike [OllamaEngine] there is no HTTP server and no Android foreground
/// service — model files are loaded straight from disk and tokens are
/// generated in a background isolate managed by `llm_llamacpp`. The engine
/// only exposes the subset of [InferenceEngine] that makes sense on-device:
/// listing/deleting downloaded GGUFs and streaming chat. Pulling models by
/// Ollama tag is not applicable (models are acquired as GGUF files through
/// the model library), so those methods throw [EngineException].
class LlamaCppEngine implements InferenceEngine {
  LlamaCppEngine();

  final LocalModelStore _store = const LocalModelStore();

  /// Loaded model path plus the context length it was loaded with, so a
  /// context-length change forces a reload.
  String? _loadedPath;
  int? _loadedContextLength;

  LlamaCppChatRepository? _chat;

  /// Path of the GGUF currently held resident by the inference isolate (set by
  /// preload or the first chat). Unlike [_loadedPath] it survives a context
  /// length change, which only rebuilds the cheap per-request context.
  String? _residentPath;

  /// Serialises access to the single on-device model/context. llama.cpp can
  /// only have one generation in flight, and the model has to be swapped when
  /// the selected model changes.
  final _gate = _AsyncGate();

  LlamaCppChatRepository _repositoryFor(LocalModelFile model, int contextLength) {
    final nGpuLayers = _recommendedGpuLayers();
    if (_chat != null &&
        _loadedPath == model.path &&
        _loadedContextLength == contextLength) {
      return _chat!;
    }
    _chat?.dispose();
    _chat = LlamaCppChatRepository.withModelPath(
      model.path,
      contextSize: contextLength,
      nGpuLayers: nGpuLayers,
    );
    _loadedPath = model.path;
    _loadedContextLength = contextLength;
    return _chat!;
  }

  /// How many layers to offload to a GPU backend.
  ///
  /// Deliberately conservative: the `llm_llamacpp` prebuilt bundles exactly
  /// one GPU backend per platform, and `BackendDetector` (which
  /// `LlamaCppRepository.recommendedGpuLayers` wraps) misreports on Windows —
  /// it finds `nvidia-smi` and returns 99 CUDA layers even though the
  /// prebuilt ships no `ggml-cuda` at all. Asking llama.cpp to offload 99
  /// layers to a backend that does not exist aborts the process mid-generation,
  /// which is exactly the Windows crash this guards against.
  ///
  /// Only Apple platforms ship a GPU backend we can rely on being present
  /// (Metal), so offload there. Windows/Linux/Android fall back to CPU, which
  /// always works and is what the bundled CPU/Vulkan selection would pick
  /// anyway for a CPU-mapped model.
  int _recommendedGpuLayers() {
    if (Platform.isMacOS || Platform.isIOS) return 99;
    return 0;
  }

  @override
  Stream<ChatDelta> chatStream({
    required String baseUrl,
    required String model,
    required List<ChatTurn> messages,
    required InferenceSettings settings,
    CancelSignal? cancelSignal,
  }) {
    final controller = StreamController<ChatDelta>();

    Future<void> run() async {
      await _gate.acquire();
      var cancelled = false;
      StreamSubscription<void>? cancelSub;
      try {
        if (cancelSignal != null) {
          cancelSub = cancelSignal.onCancel.listen((_) => cancelled = true);
        }

        final file = await _store.resolve(model);
        if (file == null) {
          throw EngineException(
            'On-device model "$model" was not found. Download it from the '
            'Models tab, or pick a different model in Settings.',
          );
        }

        final contextLength = settings.contextLength;
        final wasResident = _residentPath == file.path;
        final repo = _repositoryFor(file, contextLength);
        _residentPath = file.path;

        final llmMessages = <LLMMessage>[
          if (settings.systemPrompt != null && settings.systemPrompt!.isNotEmpty)
            LLMMessage(role: LLMRole.system, content: settings.systemPrompt),
          for (final turn in messages)
            LLMMessage(role: _role(turn.role), content: turn.content),
        ];

    final generation = GenerationOptions(
      temperature: settings.temperature,
      topP: settings.topP ?? 0.9,
      topK: settings.topK ?? 40,
      maxTokens: settings.maxTokens ?? 2048,
      seed: settings.seed,
      repeatPenalty: settings.repeatPenalty,
    );

    var evalCount = 0;
    final stopwatch = Stopwatch()..start();

    // The first request pays the one-time cost of loading the GGUF into memory
    // (multi-GB reads for a large quant), during which llama.cpp emits no
    // tokens. Surface that as a loading indication so the UI does not look
    // hung before generation starts.
    // Only the cold path: once the model is resident in the isolate, later
    // messages must not claim to be loading it again.
    if (!wasResident) {
      controller.add(const ChatDelta(contentDelta: '', done: false, loading: true));
    }

    await for (final chunk
        in repo.streamChatWithGenerationOptions(
      model,
      messages: llmMessages,
      generationOptions: generation,
    )) {
      if (cancelled) break;
      final content = chunk.message?.content ?? '';
      if (chunk.done == true) {
            stopwatch.stop();
            evalCount = chunk.evalCount ?? evalCount;
            final seconds = stopwatch.elapsedMilliseconds / 1000.0;
            controller.add(ChatDelta(
              contentDelta: content,
              done: true,
              evalCount: evalCount,
              tokensPerSecond: seconds > 0 ? evalCount / seconds : null,
            ));
          } else if (content.isNotEmpty) {
            controller.add(ChatDelta(contentDelta: content, done: false));
          }
        }

        if (!controller.isClosed) await controller.close();
      } on AppException catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(EngineException(_friendly(e.toString())));
          await controller.close();
        }
      } finally {
        await cancelSub?.cancel();
        _gate.release();
      }
    }

    unawaited(run());
    return controller.stream;
  }

  LLMRole _role(ChatRole role) => switch (role) {
        ChatRole.user => LLMRole.user,
        ChatRole.assistant => LLMRole.assistant,
        ChatRole.system => LLMRole.system,
      };

  String _friendly(String raw) {
    if (raw.contains('Model file not found') || raw.contains('No model loaded')) {
      return 'The on-device model could not be loaded. Re-download it from the '
          'Models tab and try again.';
    }
    if (raw.contains('context') && raw.contains('Failed to create')) {
      return 'Not enough memory to load this model. Try a smaller quantisation '
          'or reduce the context length in Settings.';
    }
    return raw;
  }

  @override
  Future<List<EngineModelInfo>> listModels({required String baseUrl}) async {
    final models = await _store.list();
    return [
      for (final m in models)
        EngineModelInfo(name: m.name, sizeBytes: m.sizeBytes),
    ];
  }

  @override
  Future<bool> isModelLoaded({required String baseUrl, required String model}) async {
    final file = await _store.resolve(model);
    return file != null && file.path == _residentPath;
  }

  @override
  Future<void> preloadModel({required String baseUrl, required String model}) async {
    await _gate.acquire();
    try {
      final file = await _store.resolve(model);
      if (file == null) return;
      if (_residentPath == file.path) return;
      final ok = await LlamaCppChatRepository.preloadResidentModel(
        file.path,
        nGpuLayers: _recommendedGpuLayers(),
      );
      if (ok) _residentPath = file.path;
    } finally {
      _gate.release();
    }
  }

  @override
  Future<void> deleteModel({required String baseUrl, required String model}) async {
    // Wait for any in-flight generation, then release the model the isolate
    // keeps resident: it holds the GGUF open, which blocks deletion on Windows.
    await _gate.acquire();
    try {
      final file = await _store.resolve(model);
      if (file != null && file.path == _residentPath) {
        _chat?.dispose();
        _chat = null;
        _residentPath = null;
        _loadedPath = null;
        _loadedContextLength = null;
        await LlamaCppChatRepository.unloadResidentModel();
      }
      await _store.delete(model);
    } finally {
      _gate.release();
    }
  }

  @override
  Future<void> pullModel({
    required String baseUrl,
    required String model,
    void Function(PullProgress progress)? onProgress,
  }) async {
    throw const EngineException(
      'The on-device engine does not pull Ollama models. Download GGUF files '
      'from the Models tab instead.',
    );
  }

  @override
  Future<bool> testConnection({required String baseUrl}) async {
    // The on-device engine has no server to reach; it is always "available".
    // Report whether at least one model is downloaded so the UI can nudge the
    // user to get one.
    return (await _store.list()).isNotEmpty;
  }

  /// Releases the loaded model/context. Called when the engine provider is
  /// disposed.
  void dispose() {
    _chat?.dispose();
    _chat = null;
    _residentPath = null;
    _loadedPath = null;
    _loadedContextLength = null;
  }
}

/// Minimal FIFO async mutex: only one on-device generation may touch
/// llama.cpp at a time, so callers queue behind a chain of completers.
class _AsyncGate {
  Future<void> _tail = Future.value();

  /// The completer held by the caller that is currently inside the critical
  /// section; [release] completes exactly this one.
  Completer<void>? _holder;

  Future<void> acquire() async {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    await previous;
    _holder = completer;
  }

  void release() {
    final completer = _holder;
    _holder = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
