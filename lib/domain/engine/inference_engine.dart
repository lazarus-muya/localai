import '../../core/utils/cancel_signal.dart';
import '../entities/inference_settings.dart';
import '../entities/message.dart' show ChatRole;

export '../../core/utils/cancel_signal.dart';

class ChatTurn {
  const ChatTurn({required this.role, required this.content});

  final ChatRole role;
  final String content;
}

class ChatDelta {
  const ChatDelta({
    required this.contentDelta,
    required this.done,
    this.evalCount,
    this.tokensPerSecond,
  });

  final String contentDelta;
  final bool done;
  final int? evalCount;
  final double? tokensPerSecond;
}

class EngineModelInfo {
  const EngineModelInfo({required this.name, this.sizeBytes});

  final String name;
  final int? sizeBytes;
}

class PullProgress {
  const PullProgress({required this.status, this.completedBytes, this.totalBytes});

  final String status;
  final int? completedBytes;
  final int? totalBytes;
}

/// Pluggable inference backend. [OllamaEngine] is the only implementation in
/// this phase; a generic OpenAI-compatible `RemoteEngine` and an embedded
/// llama.cpp engine are planned additions that implement this same contract.
abstract class InferenceEngine {
  Stream<ChatDelta> chatStream({
    required String baseUrl,
    required String model,
    required List<ChatTurn> messages,
    required InferenceSettings settings,
    CancelSignal? cancelSignal,
  });

  Future<List<EngineModelInfo>> listModels({required String baseUrl});

  /// Whether [model] is currently resident in the server's memory, per its
  /// running-models endpoint. Used to tell a genuine cold start apart from
  /// an ordinary slow response so the UI doesn't misreport one as the other.
  Future<bool> isModelLoaded({required String baseUrl, required String model});

  Future<void> pullModel({
    required String baseUrl,
    required String model,
    void Function(PullProgress progress)? onProgress,
  });

  Future<void> deleteModel({required String baseUrl, required String model});

  Future<bool> testConnection({required String baseUrl});
}
