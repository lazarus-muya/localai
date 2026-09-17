import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/error/app_exception.dart';
import '../../domain/engine/inference_engine.dart';
import '../../domain/entities/inference_settings.dart';
import '../../domain/entities/message.dart';

const _uuid = Uuid();
const _titleMaxLength = 48;

/// Derives a short conversation title from a user's first prompt, so new
/// chats are labeled by what they're about instead of a generic "New chat".
/// Takes the first non-empty line and truncates it at a word boundary.
String titleFromPrompt(String prompt) {
  final firstLine = prompt
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return 'New chat';
  if (firstLine.length <= _titleMaxLength) return firstLine;

  final truncated = firstLine.substring(0, _titleMaxLength);
  final lastSpace = truncated.lastIndexOf(' ');
  final cut = lastSpace > _titleMaxLength ~/ 2 ? truncated.substring(0, lastSpace) : truncated;
  return '$cut…';
}

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});

class ChatUiState {
  const ChatUiState({this.isSending = false, this.errorMessage, this.isModelWarm});

  final bool isSending;
  final String? errorMessage;

  /// Whether the model was already resident in Ollama's memory when the
  /// in-flight send started. `null` means unknown (checking it failed, e.g.
  /// an older Ollama server without `/api/ps`) — the UI falls back to a
  /// time-based guess in that case.
  final bool? isModelWarm;
}

/// Orchestrates a single conversation's send/stream/cancel lifecycle. Keyed
/// by conversation id; `null` means "not-yet-created" — the first sent
/// message creates the conversation, returns its id immediately for
/// navigation, and hands the actual send/stream off to that id's own
/// controller instance.
class ChatController extends Notifier<ChatUiState> {
  ChatController(this.arg);

  final String? arg;
  CancelSignal? _activeCancelSignal;

  @override
  ChatUiState build() {
    ref.onDispose(() => _activeCancelSignal?.cancel());
    return const ChatUiState();
  }

  /// Sends [text]. Returns the conversation id when a brand-new conversation
  /// was created by this call (so the UI can navigate to it right away),
  /// otherwise null.
  ///
  /// For a brand-new conversation the id is created and returned immediately,
  /// and the actual send/stream is handed off to that conversation's own
  /// controller instance — so the UI can navigate there before the response
  /// starts streaming, instead of only seeing progress once the whole
  /// response has finished.
  Future<String?> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (arg == null) {
      final conversation = await ref
          .read(chatRepositoryProvider)
          .createConversation(title: titleFromPrompt(trimmed));
      unawaited(
        ref.read(chatControllerProvider(conversation.id).notifier)._send(trimmed),
      );
      return conversation.id;
    }

    await _send(trimmed);
    return null;
  }

  Future<void> _send(String trimmed) async {
    final conversationId = arg!;
    final repo = ref.read(chatRepositoryProvider);
    var settings = await repo.getSettings();
    final engine = ref.read(ollamaEngineProvider);
    final baseUrl = settings.ollamaServerUrl;

    var modelName = settings.defaultOllamaModel;

    if (modelName == null || modelName.trim().isEmpty) {
      // No default model chosen yet — fall back to the first model already
      // installed, if any, rather than blocking the chat.
      try {
        final installed = await engine.listModels(baseUrl: baseUrl);
        if (installed.isNotEmpty) {
          modelName = installed.first.name;
          settings = settings.copyWith(defaultOllamaModel: modelName);
          await repo.updateSettings(settings);
        }
      } catch (_) {
        // Ignore — handled by the empty-model check below.
      }
    }

    if (modelName == null || modelName.trim().isEmpty) {
      state = const ChatUiState(
        errorMessage: 'Set a default Ollama model in Settings before starting a chat.',
      );
      return;
    }

    bool? isModelWarm;
    try {
      isModelWarm = await engine.isModelLoaded(baseUrl: baseUrl, model: modelName);
    } catch (_) {
      // Unreachable server — fall back to the UI's own time-based guess
      // instead of failing the send.
    }

    state = ChatUiState(isSending: true, isModelWarm: isModelWarm);

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
      final inferenceSettings = InferenceSettings(
        systemPrompt: settings.globalSystemPrompt,
        keepAliveMinutes: settings.modelKeepAliveMinutes,
      );

      await for (final delta in engine.chatStream(
        baseUrl: baseUrl,
        model: modelName,
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
  }

  void cancel() => _activeCancelSignal?.cancel();
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatUiState, String?>(ChatController.new);
