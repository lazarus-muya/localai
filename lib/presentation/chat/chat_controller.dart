import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/error/app_exception.dart';
import '../../domain/engine/inference_engine.dart';
import '../../domain/entities/inference_settings.dart';
import '../../domain/entities/message.dart';

const _uuid = Uuid();

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

class ChatUiState {
  const ChatUiState({this.isSending = false, this.errorMessage});

  final bool isSending;
  final String? errorMessage;
}

/// Orchestrates a single conversation's send/stream/cancel lifecycle. Keyed
/// by conversation id; `null` means "not-yet-created" — the first sent
/// message creates the conversation and the caller navigates to its id.
class ChatController extends Notifier<ChatUiState> {
  ChatController(this.arg);

  final String? arg;
  CancelSignal? _activeCancelSignal;

  @override
  ChatUiState build() {
    ref.onDispose(() => _activeCancelSignal?.cancel());
    return const ChatUiState();
  }

  Future<String> _ensureConversation() async {
    if (arg != null) return arg!;
    final conversation = await ref.read(chatRepositoryProvider).createConversation();
    return conversation.id;
  }

  /// Sends [text]. Returns the conversation id when a brand-new conversation
  /// was created by this call (so the UI can navigate to it), otherwise null.
  Future<String?> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final repo = ref.read(chatRepositoryProvider);
    final engine = ref.read(ollamaEngineProvider);
    final settings = await repo.getSettings();
    final wasNew = arg == null;
    final conversationId = await _ensureConversation();

    if (settings.defaultOllamaModel == null || settings.defaultOllamaModel!.trim().isEmpty) {
      state = const ChatUiState(
        errorMessage: 'Set a default Ollama model in Settings before starting a chat.',
      );
      return wasNew ? conversationId : null;
    }

    state = const ChatUiState(isSending: true);

    final now = DateTime.now();
    await repo.saveMessage(ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: ChatRole.user,
      content: trimmed,
      createdAt: now,
      status: MessageStatus.complete,
    ));

    final history = await repo.getMessages(conversationId);

    var assistantMessage = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      status: MessageStatus.streaming,
    );
    await repo.saveMessage(assistantMessage);

    final cancelSignal = CancelSignal();
    _activeCancelSignal = cancelSignal;

    final turns = history.map((m) => ChatTurn(role: m.role, content: m.content)).toList();
    final buffer = StringBuffer();
    Timer? flushTimer;
    var lastFlushed = '';
    final stopwatch = Stopwatch()..start();

    Future<void> flush() async {
      final current = buffer.toString();
      if (current == lastFlushed) return;
      lastFlushed = current;
      assistantMessage = assistantMessage.copyWith(content: current);
      await repo.saveMessage(assistantMessage);
    }

    String? errorMessage;
    try {
      final inferenceSettings = InferenceSettings(systemPrompt: settings.globalSystemPrompt);

      await for (final delta in engine.chatStream(
        baseUrl: settings.ollamaServerUrl,
        model: settings.defaultOllamaModel!,
        messages: turns,
        settings: inferenceSettings,
        cancelSignal: cancelSignal,
      )) {
        buffer.write(delta.contentDelta);
        flushTimer ??= Timer.periodic(const Duration(milliseconds: 120), (_) => flush());
        if (delta.done) {
          flushTimer.cancel();
          stopwatch.stop();
          assistantMessage = assistantMessage.copyWith(
            content: buffer.toString(),
            status: cancelSignal.isCancelled ? MessageStatus.cancelled : MessageStatus.complete,
            generationMs: stopwatch.elapsedMilliseconds,
            tokensPerSecond: delta.tokensPerSecond,
            tokenCount: delta.evalCount,
          );
          await repo.saveMessage(assistantMessage);
        }
      }
      if (cancelSignal.isCancelled && assistantMessage.status == MessageStatus.streaming) {
        flushTimer?.cancel();
        assistantMessage = assistantMessage.copyWith(
          content: buffer.toString(),
          status: MessageStatus.cancelled,
        );
        await repo.saveMessage(assistantMessage);
      }
    } on AppException catch (e) {
      flushTimer?.cancel();
      assistantMessage = assistantMessage.copyWith(
        content: buffer.toString(),
        status: MessageStatus.error,
        errorMessage: e.message,
      );
      await repo.saveMessage(assistantMessage);
      errorMessage = e.message;
    } catch (e) {
      flushTimer?.cancel();
      assistantMessage = assistantMessage.copyWith(
        content: buffer.toString(),
        status: MessageStatus.error,
        errorMessage: e.toString(),
      );
      await repo.saveMessage(assistantMessage);
      errorMessage = e.toString();
    } finally {
      _activeCancelSignal = null;
      await repo.touchConversation(conversationId);
      state = ChatUiState(isSending: false, errorMessage: errorMessage);
    }

    return wasNew ? conversationId : null;
  }

  void cancel() => _activeCancelSignal?.cancel();
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatUiState, String?>(ChatController.new);
