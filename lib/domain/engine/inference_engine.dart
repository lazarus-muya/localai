import 'dart:async';

import '../entities/inference_settings.dart';
import '../entities/message.dart' show ChatRole;

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

/// Cooperative cancellation token, owned by the domain layer so engines
/// (which may be backed by dio, an FFI call, etc.) don't leak their
/// transport-specific cancellation type into calling code.
class CancelSignal {
  bool _cancelled = false;
  final StreamController<void> _controller = StreamController<void>.broadcast();

  bool get isCancelled => _cancelled;

  Stream<void> get onCancel => _controller.stream;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _controller.add(null);
  }

  void dispose() => _controller.close();
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

  Future<void> pullModel({
    required String baseUrl,
    required String model,
    void Function(PullProgress progress)? onProgress,
  });

  Future<bool> testConnection({required String baseUrl});
}
