import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Callbacks fired while a listening session is active.
typedef SpeechTranscript = void Function(String text, bool isFinal);
typedef SpeechSoundLevel = void Function(double level);
typedef SpeechErrorStatus = void Function(String message, bool permanent);

/// Wraps `speech_to_text` so the voice chat overlay has a single place to
/// start/stop listening and adapt its behavioural details. The underlying
/// engine is the device's own speech recognition service, so availability
/// depends on the platform — initialization failing simply reports that.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  SpeechTranscript? _onTranscript;
  SpeechSoundLevel? _onSoundLevel;
  SpeechErrorStatus? _onErrorStatus;
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  String? _lastError;
  String? get lastError => _lastError;

  /// Prepares the recognizer, attaching the callbacks used by [listen].
  /// Returns whether recognition is available on this platform.
  Future<bool> initialize({
    required SpeechTranscript onTranscript,
    required SpeechSoundLevel onSoundLevel,
    SpeechErrorStatus? onErrorStatus,
  }) async {
    _onTranscript = onTranscript;
    _onSoundLevel = onSoundLevel;
    _onErrorStatus = onErrorStatus;
    if (_initialized) return true;

    final ready = await _speech.initialize(
      onStatus: (_) {},
      onError: _onError,
    );
    _initialized = ready;
    return _initialized;
  }

  void _onResult(SpeechRecognitionResult result) {
    _onTranscript?.call(result.recognizedWords, result.finalResult);
  }

  void _handleSoundLevel(double level) => _onSoundLevel?.call(level);

  void _onError(dynamic error) {
    _lastError = error is SpeechRecognitionError ? error.errorMsg : '$error';
    final permanent = error is SpeechRecognitionError && error.permanent;
    _onErrorStatus?.call(_lastError ?? 'Speech recognition error', permanent);
  }

  /// Starts listening against the device recognizer. Results and sound level
  /// are delivered through the callbacks passed to [initialize].
  Future<void> listen() async {
    if (!_initialized) return;
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _handleSoundLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        onDevice: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  /// Ends the current listening session, delivering a final result. Safe to
  /// call when nothing is listening.
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {
      await cancel();
    }
  }

  /// Cancels the current listening session without reporting a final result.
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // Ignore — the recognizer is already idle.
    }
  }
}