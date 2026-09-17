import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../local/database/app_database.dart';

const _uuid = Uuid();

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._db);

  final AppDatabase _db;

  Conversation _toConversation(ConversationRow row) => Conversation(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        systemPromptOverride: row.systemPromptOverride,
        pinned: row.pinned,
        archivedAt: row.archivedAt,
      );

  ChatMessage _toMessage(MessageRow row) => ChatMessage(
        id: row.id,
        conversationId: row.conversationId,
        role: row.role,
        content: row.content,
        createdAt: row.createdAt,
        status: row.status,
        tokenCount: row.tokenCount,
        generationMs: row.generationMs,
        tokensPerSecond: row.tokensPerSecond,
        errorMessage: row.errorMessage,
      );

  AppSettings _toSettings(SettingsRow row) => AppSettings(
        ollamaBaseUrl: row.ollamaBaseUrl,
        ollamaPort: row.ollamaPort,
        globalSystemPrompt: row.globalSystemPrompt,
        defaultOllamaModel: row.defaultOllamaModel,
        modelKeepAliveMinutes: row.modelKeepAliveMinutes,
      );

  @override
  Stream<List<Conversation>> watchConversations() {
    return _db.watchConversations().map((rows) => rows.map(_toConversation).toList());
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    final row = await _db.getConversation(id);
    return row == null ? null : _toConversation(row);
  }

  @override
  Future<Conversation> createConversation({String title = 'New chat', String? systemPromptOverride}) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    await _db.upsertConversation(ConversationsCompanion.insert(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      systemPromptOverride: Value(systemPromptOverride),
    ));
    return Conversation(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
      systemPromptOverride: systemPromptOverride,
    );
  }

  @override
  Future<void> renameConversation(String id, String title) async {
    final row = await _db.getConversation(id);
    if (row == null) return;
    await _db.upsertConversation(
      row.copyWith(title: title, updatedAt: DateTime.now()).toCompanion(true),
    );
  }

  @override
  Future<void> deleteConversation(String id) => _db.deleteConversation(id);

  @override
  Future<void> deleteAllConversations() => _db.deleteAllConversations();

  @override
  Future<void> touchConversation(String id) async {
    final row = await _db.getConversation(id);
    if (row == null) return;
    await _db.upsertConversation(
      row.copyWith(updatedAt: DateTime.now()).toCompanion(true),
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _db.watchMessages(conversationId).map((rows) => rows.map(_toMessage).toList());
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final rows = await _db.getMessages(conversationId);
    return rows.map(_toMessage).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage message) {
    return _db.upsertMessage(MessagesCompanion.insert(
      id: message.id,
      conversationId: message.conversationId,
      role: message.role,
      content: message.content,
      createdAt: message.createdAt,
      status: message.status,
      tokenCount: Value(message.tokenCount),
      generationMs: Value(message.generationMs),
      tokensPerSecond: Value(message.tokensPerSecond),
      errorMessage: Value(message.errorMessage),
    ));
  }

  @override
  Future<AppSettings> getSettings() async => _toSettings(await _db.getSettings());

  @override
  Stream<AppSettings> watchSettings() => _db.watchSettings().map(_toSettings);

  @override
  Future<void> updateSettings(AppSettings settings) {
    return _db.updateSettings(AppSettingsTableCompanion(
      ollamaBaseUrl: Value(settings.ollamaBaseUrl),
      ollamaPort: Value(settings.ollamaPort),
      globalSystemPrompt: Value(settings.globalSystemPrompt),
      defaultOllamaModel: Value(settings.defaultOllamaModel),
      modelKeepAliveMinutes: Value(settings.modelKeepAliveMinutes),
    ));
  }
}
