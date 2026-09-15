import '../entities/app_settings.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract class ChatRepository {
  Stream<List<Conversation>> watchConversations();
  Future<Conversation?> getConversation(String id);
  Future<Conversation> createConversation({String title, String? systemPromptOverride});
  Future<void> renameConversation(String id, String title);
  Future<void> deleteConversation(String id);
  Future<void> touchConversation(String id);

  Stream<List<ChatMessage>> watchMessages(String conversationId);
  Future<List<ChatMessage>> getMessages(String conversationId);
  Future<void> saveMessage(ChatMessage message);

  Future<AppSettings> getSettings();
  Stream<AppSettings> watchSettings();
  Future<void> updateSettings(AppSettings settings);
}
