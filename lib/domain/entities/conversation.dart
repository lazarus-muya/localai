class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.systemPromptOverride,
    this.pinned = false,
    this.archivedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? systemPromptOverride;
  final bool pinned;
  final DateTime? archivedAt;
}
