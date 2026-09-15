class HuggingFaceModelSummary {
  const HuggingFaceModelSummary({
    required this.id,
    required this.downloads,
    required this.likes,
    required this.tags,
  });

  /// Repo id, e.g. `"TheBloke/Mistral-7B-Instruct-v0.2-GGUF"`.
  final String id;
  final int downloads;
  final int likes;
  final List<String> tags;

  factory HuggingFaceModelSummary.fromJson(Map<String, dynamic> json) {
    return HuggingFaceModelSummary(
      id: (json['id'] ?? json['modelId'] ?? '') as String,
      downloads: (json['downloads'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }
}

class HuggingFaceFile {
  const HuggingFaceFile({required this.path, this.sizeBytes});

  final String path;
  final int? sizeBytes;
}
