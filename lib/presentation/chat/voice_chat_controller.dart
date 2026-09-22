import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/speech/text_to_speech.dart';
import '../../domain/entities/message.dart';
import 'chat_controller.dart';

enum VoiceChatPhase { starting, listening, thinking, speaking, unsupported }

class VoiceChatState {
  const VoiceChatState({
    this.phase = VoiceChatPhase.starting,
    this.micLevel = 0,
    this.transcript = '',
    this.activeConversationId,
  });

  final VoiceChatPhase phase;
  final double micLevel;
  final String transcript;
  final String? activeConversationId;

  VoiceChatState copyWith({
    VoiceChatPhase? phase,
    double? micLevel,
    String? transcript,
    String? activeConversationId,
  }) {
    return VoiceChatState(
      phase: phase ?? this.phase,
      micLevel: micLevel ?? this.micLevel,
      transcript: transcript ?? this.transcript,
      activeConversationId: activeConversationId ?? this.activeConversationId,
    );
  }
}

/// Drives a Gemini Live-style voice session on top of the existing chat
/// pipeline:
///
///  1. Listen with the device's speech recognizer.
///  2. A spoken utterance becomes a regular chat message (same conversation,
///     so it shows up in the chat list and history exactly like a typed one).
///  3. The model's streamed reply is read aloud chunk-by-chunk with the
///     system TTS while continuing to generate (Gemini behaviour).
///  4. When the reply is finished, the microphone is re-armed for the next
///     turn.
///
/// The mic only works where the device recognizer exists (Android/iOS/macOS
/// and, experimentally, Windows); elsewhere the overlay reports it and TTS
/// read-aloud still works.
class VoiceChatController extends Notifier<VoiceChatState> {
  VoiceChatController(this.initialConversationId);

  final String? initialConversationId;

  String? _activeId;
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  ChatMessage? _lastAssistant;
  String? _spokenMessageId;
  int _spokenChars = 0;
  final List<String> _ttsQueue = [];
  bool _ttsWorking = false;
  bool _errorIsPermanent = false;

  @override
  VoiceChatState build() {
    final speech = ref.watch(speechRecognitionProvider);
    ref.onDispose(() {
      _messagesSub?.cancel();
      speech.cancel();
      ref.read(speechControllerProvider.notifier).stop();
    });
    return VoiceChatState(activeConversationId: initialConversationId);
  }

  Future<void> start() async {
    final speech = ref.read(speechRecognitionProvider);
    final available = await speech.initialize(
      onTranscript: _onTranscript,
      onSoundLevel: (level) {
        if (state.phase == VoiceChatPhase.listening) {
          state = state.copyWith(micLevel: level);
        }
      },
      onErrorStatus: (message, permanent) {
        _errorIsPermanent = permanent;
        if (permanent) {
          state = state.copyWith(phase: VoiceChatPhase.unsupported);
        }
      },
    );
    if (!available) {
      state = state.copyWith(phase: VoiceChatPhase.unsupported);
      return;
    }
    final initialId = initialConversationId;
    if (initialId != null) {
      _activeId = initialId;
      _watchMessages(initialId);
    }
    await _beginListening();
  }

  Future<void> _beginListening() async {
    final speech = ref.read(speechRecognitionProvider);
    if (speech.isListening) return;
    state = state.copyWith(phase: VoiceChatPhase.listening, transcript: '', micLevel: 0);
    try {
      await speech.listen();
    } catch (_) {
      state = state.copyWith(phase: VoiceChatPhase.unsupported);
    }
  }

  void _onTranscript(String text, bool isFinal) {
    state = state.copyWith(transcript: text);
    if (isFinal) {
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        unawaited(_submit(trimmed));
      } else {
        unawaited(_beginListening());
      }
    }
  }

  Future<void> _submit(String utterance) async {
    state = state.copyWith(phase: VoiceChatPhase.thinking, transcript: '');
    String? newId;
    try {
      final chat = ref.read(chatControllerProvider(_activeId).notifier);
      newId = await chat.sendMessage(utterance);
    } catch (_) {
      state = state.copyWith(phase: VoiceChatPhase.listening, transcript: '');
      unawaited(_beginListening());
      return;
    }
    if (newId != null) {
      _activeId = newId;
      state = state.copyWith(activeConversationId: newId);
      _watchMessages(newId);
    } else {
      _watchMessages(_activeId!);
    }
  }

  void _watchMessages(String conversationId) {
    _messagesSub?.cancel();
    _spokenMessageId = null;
    _spokenChars = 0;
    _messagesSub = ref
        .read(chatRepositoryProvider)
        .watchMessages(conversationId)
        .listen(_onMessages);
  }

  void _onMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final last = messages.last;
    _lastAssistant = last;
    if (last.role != ChatRole.assistant) return;
    _onAssistantContent();
  }

  void _onAssistantContent() {
    final message = _lastAssistant!;
    if (message.status == MessageStatus.error || message.status == MessageStatus.cancelled) {
      unawaited(_finalizeWhenQuiet());
      return;
    }
    if (message.id != _spokenMessageId) {
      _spokenMessageId = message.id;
      _spokenChars = 0;
    }
    final content = message.content;
    if (content.length > _spokenChars) {
      _ttsQueue.add(content.substring(_spokenChars));
      _spokenChars = content.length;
      state = state.copyWith(phase: VoiceChatPhase.speaking);
      unawaited(_processTtsQueue());
    } else if (message.status == MessageStatus.complete) {
      unawaited(_finalizeWhenQuiet());
    }
  }

  Future<void> _processTtsQueue() async {
    if (_ttsWorking) return;
    _ttsWorking = true;
    try {
      final speech = ref.read(speechControllerProvider.notifier);
      while (_ttsQueue.isNotEmpty) {
        await speech.speak(_ttsQueue.removeAt(0));
      }
    } finally {
      _ttsWorking = false;
    }
    unawaited(_finalizeWhenQuiet());
  }

  Future<void> _finalizeWhenQuiet() async {
    if (_ttsWorking || _ttsQueue.isNotEmpty || _activeId == null) return;
    final last = _lastAssistant;
    final done = last == null ||
        last.status == MessageStatus.complete ||
        last.status == MessageStatus.error ||
        last.status == MessageStatus.cancelled;
    if (!done) return;
    _spokenMessageId = null;
    _spokenChars = 0;
    if (_errorIsPermanent) {
      state = state.copyWith(phase: VoiceChatPhase.unsupported);
      return;
    }
    await _beginListening();
  }
}

final voiceChatControllerProvider =
    NotifierProvider.family<VoiceChatController, VoiceChatState, String?>(
  VoiceChatController.new,
);