/// Ordered, independently-copyable pieces of a parsed model response.
/// See [ContentBlockParser] for how a raw response is split into these.
sealed class ContentBlock {
  const ContentBlock();
}

class TextBlock extends ContentBlock {
  const TextBlock(this.markdown);
  final String markdown;
}

class CodeBlock extends ContentBlock {
  const CodeBlock({this.language, required this.code});
  final String? language;
  final String code;
}

class HtmlBlock extends ContentBlock {
  const HtmlBlock(this.html);
  final String html;
}

enum ImageSourceType { base64, file, network }

class ImageBlock extends ContentBlock {
  const ImageBlock({required this.sourceType, required this.data});
  final ImageSourceType sourceType;

  /// The raw base64 payload, an absolute file path, or a network URL,
  /// depending on [sourceType].
  final String data;
}
