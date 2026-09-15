enum ChatRole { user, assistant, system }

enum MessageStatus { pending, streaming, complete, error, cancelled }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.status,
    this.tokenCount,
    this.generationMs,
    this.tokensPerSecond,
    this.errorMessage,
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final int? tokenCount;
  final int? generationMs;
  final double? tokensPerSecond;
  final String? errorMessage;

  ChatMessage copyWith({
    String? content,
    MessageStatus? status,
    int? tokenCount,
    int? generationMs,
    double? tokensPerSecond,
    String? errorMessage,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      status: status ?? this.status,
      tokenCount: tokenCount ?? this.tokenCount,
      generationMs: generationMs ?? this.generationMs,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
