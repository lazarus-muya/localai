class AppSettings {
  const AppSettings({
    required this.ollamaBaseUrl,
    required this.ollamaPort,
    this.globalSystemPrompt,
    this.defaultOllamaModel,
  });

  final String ollamaBaseUrl;
  final int ollamaPort;
  final String? globalSystemPrompt;
  final String? defaultOllamaModel;

  String get ollamaServerUrl => '$ollamaBaseUrl:$ollamaPort';

  AppSettings copyWith({
    String? ollamaBaseUrl,
    int? ollamaPort,
    String? globalSystemPrompt,
    String? defaultOllamaModel,
  }) {
    return AppSettings(
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      globalSystemPrompt: globalSystemPrompt ?? this.globalSystemPrompt,
      defaultOllamaModel: defaultOllamaModel ?? this.defaultOllamaModel,
    );
  }
}
