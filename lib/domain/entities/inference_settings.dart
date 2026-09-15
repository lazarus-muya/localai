/// Per-request inference parameters. A full settings UI (temperature, top_p,
/// top_k, repeat penalty, seed, stop sequences, GPU layers, etc.) lands in a
/// later phase; today only [temperature], [contextLength] and [systemPrompt]
/// are actually surfaced and wired end-to-end.
class InferenceSettings {
  const InferenceSettings({
    this.temperature = 0.7,
    this.topP,
    this.topK,
    this.repeatPenalty,
    this.maxTokens,
    this.contextLength = 4096,
    this.seed,
    this.stopSequences = const [],
    this.systemPrompt,
  });

  final double temperature;
  final double? topP;
  final int? topK;
  final double? repeatPenalty;
  final int? maxTokens;
  final int contextLength;
  final int? seed;
  final List<String> stopSequences;
  final String? systemPrompt;
}
