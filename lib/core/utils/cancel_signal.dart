import 'dart:async';

/// Cooperative cancellation token, kept transport-agnostic so callers never
/// need to depend on e.g. dio's `CancelToken` directly. Shared by the
/// inference engine and the model downloader.
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
