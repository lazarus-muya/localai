/// Which inference backend chat requests are routed to.
enum InferenceBackend {
  /// llama.cpp embedded in the app via FFI. No server or foreground service
  /// required; inference runs directly on the device's CPU/GPU.
  onDevice,

  /// An Ollama server hosted locally (on this device or the LAN) or remotely.
  remote,
}

class AppSettings {
  const AppSettings({
    this.backend = InferenceBackend.remote,
    required this.ollamaBaseUrl,
    required this.ollamaPort,
    this.globalSystemPrompt,
    this.defaultOllamaModel,
    this.defaultLocalModel,
    this.localContextLength = 4096,
    this.modelKeepAliveMinutes = 20,
    this.ttsVoice,
  });

  /// The active backend. New installs default to [InferenceBackend.remote] to
  /// preserve the pre-existing Ollama behaviour; users opt into on-device
  /// inference explicitly from Settings.
  final InferenceBackend backend;

  final String ollamaBaseUrl;
  final int ollamaPort;
  final String? globalSystemPrompt;

  /// Model used for new chats when the remote (Ollama) backend is active.
  final String? defaultOllamaModel;

  /// Model used for new chats when the on-device (llama.cpp) backend is
  /// active. Matches an installed model's name (its GGUF filename).
  final String? defaultLocalModel;

  /// Context window (tokens) requested from the on-device engine. Kept
  /// modest by default because context memory is allocated up front on mobile.
  final int localContextLength;

  /// How long Ollama keeps a model resident in memory after the last
  /// request before unloading it. `0` means "never unload". Ignored by the
  /// on-device engine, which unloads on demand.
  final int modelKeepAliveMinutes;

  /// The text-to-speech voice used when reading messages aloud, keyed as
  /// reported by `flutter_tts` (`name`, `locale`, `identifier`). `null`
  /// (or empty) means "use the system default voice".
  final Map<String, String>? ttsVoice;

  String get ollamaServerUrl => '$ollamaBaseUrl:$ollamaPort';

  /// The model new chats should start with for the currently active backend.
  String? get activeDefaultModel =>
      backend == InferenceBackend.onDevice ? defaultLocalModel : defaultOllamaModel;

  AppSettings copyWith({
    InferenceBackend? backend,
    String? ollamaBaseUrl,
    int? ollamaPort,
    String? globalSystemPrompt,
    String? defaultOllamaModel,
    String? defaultLocalModel,
    int? localContextLength,
    int? modelKeepAliveMinutes,
    Map<String, String>? ttsVoice,
  }) {
    return AppSettings(
      backend: backend ?? this.backend,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      globalSystemPrompt: globalSystemPrompt ?? this.globalSystemPrompt,
      defaultOllamaModel: defaultOllamaModel ?? this.defaultOllamaModel,
      defaultLocalModel: defaultLocalModel ?? this.defaultLocalModel,
      localContextLength: localContextLength ?? this.localContextLength,
      modelKeepAliveMinutes: modelKeepAliveMinutes ?? this.modelKeepAliveMinutes,
      ttsVoice: ttsVoice ?? this.ttsVoice,
    );
  }
}
