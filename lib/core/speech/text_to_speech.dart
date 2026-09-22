import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../di/providers.dart';

/// Public state of the shared text-to-speech session.
class SpeechUiState {
  const SpeechUiState({
    this.isSpeaking = false,
    this.isPaused = false,
    this.speakingKey,
  });

  final bool isSpeaking;
  final bool isPaused;

  /// Opaque identifier for the utterance being read (e.g. the message id),
  /// so widgets can tell whether their own text is what's playing.
  final String? speakingKey;

  SpeechUiState copyWith({bool? isSpeaking, bool? isPaused, String? speakingKey}) {
    return SpeechUiState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isPaused: isPaused ?? this.isPaused,
      speakingKey: speakingKey ?? this.speakingKey,
    );
  }
}

/// Shared text-to-speech session backed by the operating system's voices
/// (via `flutter_tts`). Both the voice chat overlay (reading model replies
/// aloud) and the read-aloud action run through this single engine so they
/// never talk over each other.
class SpeechController extends Notifier<SpeechUiState> {
  FlutterTts? _tts;

  /// Bumped on every [speak] and [stop]. An in-flight [speak] re-checks this
  /// before actually issuing speech so a stop (or a newer speak) requested
  /// while it was still configuring the engine is never swallowed.
  int _epoch = 0;

  @override
  SpeechUiState build() {
    ref.onDispose(() {
      _tts?.stop();
    });
    return const SpeechUiState();
  }

  FlutterTts get _engine {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = FlutterTts();
    tts.setStartHandler(() {
      state = state.copyWith(isSpeaking: true, isPaused: false);
    });
    tts.setCompletionHandler(_onFinished);
    tts.setCancelHandler(_onFinished);
    tts.setErrorHandler((_) => _onFinished());
    tts.setPauseHandler(() {
      state = state.copyWith(isPaused: true);
    });
    tts.setContinueHandler(() {
      state = state.copyWith(isPaused: false);
    });
    _tts = tts;
    return tts;
  }

  void _onFinished() => state = const SpeechUiState();

  /// Lists the voices the operating system offers, each keyed as expected by
  /// [`FlutterTts.setVoice`] (`name`, `locale`, `gender`, `identifier`).
  /// Returns an empty list where enumeration isn't supported.
  Future<List<Map<String, String>>> availableVoices() async {
    try {
      final raw = await _engine.getVoices;
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (entry is Map)
            entry.map((key, value) => MapEntry(key.toString(), value.toString())),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Speaks [text] with the system's default voice, interrupting any speech
  /// already in progress. Empty input is ignored. [key] tags the utterance so
  /// the session state can identify which message is currently being read.
  ///
  /// [voice] overrides the configured default voice; pass an empty map to
  /// explicitly request the platform's default voice for this utterance.
  Future<void> speak(
    String text, {
    String? key,
    Map<String, String>? voice,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final epoch = ++_epoch;
    final tts = _engine;
    state = SpeechUiState(isSpeaking: true, speakingKey: key);
    final effectiveVoice = _effectiveVoice(voice);
    try {
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await _applyVoice(tts, effectiveVoice);
      await tts.stop();
      await tts.awaitSpeakCompletion(true);
      if (epoch != _epoch) return; // superseded by a stop/newer speak
      // The stop() above fires the platform's cancel handler, which resets
      // the state (dropping `key`). Re-assert it so the UI can show the stop
      // control for this utterance right as speech begins.
      state = SpeechUiState(isSpeaking: true, speakingKey: key);
      await tts.speak(trimmed);
    } catch (_) {
      _onFinished();
    }
  }

  Map<String, String>? _effectiveVoice(Map<String, String>? override) {
    if (override != null) return override.isEmpty ? null : override;
    final configured = ref.read(appSettingsProvider).value?.ttsVoice;
    if (configured == null || configured.isEmpty) return null;
    return configured;
  }

  /// Last voice successfully pushed to the platform, so we only clear back to
  /// the system default when one was actually set.
  Map<String, String>? _appliedVoice;

  Future<void> _applyVoice(FlutterTts tts, Map<String, String>? voice) async {
    try {
      if (voice == null) {
        if (_appliedVoice == null) return; // already on the default voice
        await tts.clearVoice();
        _appliedVoice = null;
      } else {
        await tts.setVoice(voice);
        _appliedVoice = voice;
      }
    } catch (_) {
      // Voice selection unsupported on this platform — keep the default.
      _appliedVoice = null;
    }
  }

  /// Stops any speech in progress and cancels anything still being prepared.
  Future<void> stop() async {
    _epoch++;
    try {
      await _tts?.stop();
    } finally {
      _onFinished();
    }
  }

  Future<void> pause() async {
    await _tts?.pause();
    state = state.copyWith(isPaused: true);
  }
}

final speechControllerProvider =
    NotifierProvider<SpeechController, SpeechUiState>(SpeechController.new);

/// Voices the operating system offers for read-aloud, keyed as expected by
/// [FlutterTts.setVoice]. Empty where enumeration isn't supported.
final ttsVoicesProvider = FutureProvider<List<Map<String, String>>>((ref) {
  return ref.watch(speechControllerProvider.notifier).availableVoices();
});