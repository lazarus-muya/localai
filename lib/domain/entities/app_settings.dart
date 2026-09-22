class AppSettings {
  const AppSettings({
    required this.ollamaBaseUrl,
    required this.ollamaPort,
    this.globalSystemPrompt,
    this.defaultOllamaModel,
    this.modelKeepAliveMinutes = 20,
    this.ttsVoice,
  });

  final String ollamaBaseUrl;
  final int ollamaPort;
  final String? globalSystemPrompt;
  final String? defaultOllamaModel;

  /// How long Ollama keeps a model resident in memory after the last
  /// request before unloading it. `0` means "never unload".
  final int modelKeepAliveMinutes;

  /// The text-to-speech voice used when reading messages aloud, keyed as
  /// reported by `flutter_tts` (`name`, `locale`, `identifier`). `null`
  /// (or empty) means "use the system default voice".
  final Map<String, String>? ttsVoice;

  String get ollamaServerUrl => '$ollamaBaseUrl:$ollamaPort';

  AppSettings copyWith({
    String? ollamaBaseUrl,
    int? ollamaPort,
    String? globalSystemPrompt,
    String? defaultOllamaModel,
    int? modelKeepAliveMinutes,
    Map<String, String>? ttsVoice,
  }) {
    return AppSettings(
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      globalSystemPrompt: globalSystemPrompt ?? this.globalSystemPrompt,
      defaultOllamaModel: defaultOllamaModel ?? this.defaultOllamaModel,
      modelKeepAliveMinutes: modelKeepAliveMinutes ?? this.modelKeepAliveMinutes,
      ttsVoice: ttsVoice ?? this.ttsVoice,
    );
  }
}
