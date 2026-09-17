class AppSettings {
  const AppSettings({
    required this.ollamaBaseUrl,
    required this.ollamaPort,
    this.globalSystemPrompt,
    this.defaultOllamaModel,
    this.modelKeepAliveMinutes = 20,
  });

  final String ollamaBaseUrl;
  final int ollamaPort;
  final String? globalSystemPrompt;
  final String? defaultOllamaModel;

  /// How long Ollama keeps a model resident in memory after the last
  /// request before unloading it. `0` means "never unload".
  final int modelKeepAliveMinutes;

  String get ollamaServerUrl => '$ollamaBaseUrl:$ollamaPort';

  AppSettings copyWith({
    String? ollamaBaseUrl,
    int? ollamaPort,
    String? globalSystemPrompt,
    String? defaultOllamaModel,
    int? modelKeepAliveMinutes,
  }) {
    return AppSettings(
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      globalSystemPrompt: globalSystemPrompt ?? this.globalSystemPrompt,
      defaultOllamaModel: defaultOllamaModel ?? this.defaultOllamaModel,
      modelKeepAliveMinutes: modelKeepAliveMinutes ?? this.modelKeepAliveMinutes,
    );
  }
}
