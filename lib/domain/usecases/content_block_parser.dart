import '../entities/content_block.dart';

/// Splits a raw model response into ordered, independently-copyable blocks.
///
/// Deliberately line/regex based rather than walking `package:markdown`'s
/// AST: that AST is HTML-render-oriented and doesn't preserve markdown
/// source spans, which makes re-serializing "everything that isn't a
/// code/html/image block" back to markdown unreliable. A line scanner keeps
/// exactly the ordering and fidelity needed for fenced code, standalone raw
/// HTML blocks, and standalone images, while leaving normal prose/lists/
/// tables untouched for a markdown widget to render as-is.
class ContentBlockParser {
  const ContentBlockParser();

  static final _fenceStart = RegExp(r'^(```|~~~)\s*([A-Za-z0-9_+-]*)\s*$');
  static final _standaloneImage = RegExp(r'^!\[[^\]]*\]\((\S+?)(?:\s+"[^"]*")?\)$');
  static final _blockHtmlTag = RegExp(
    r'^<\s*(div|table|thead|tbody|tr|td|th|iframe|section|article|figure|video|audio|svg|style|details|summary|form)\b',
    caseSensitive: false,
  );

  List<ContentBlock> parse(String raw) {
    if (raw.trim().isEmpty) return const [];
    final lines = raw.split('\n');
    final blocks = <ContentBlock>[];
    final textBuffer = <String>[];

    void flushText() {
      final text = textBuffer.join('\n').trim();
      if (text.isNotEmpty) blocks.add(TextBlock(text));
      textBuffer.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final fenceMatch = _fenceStart.firstMatch(line.trim());

      if (fenceMatch != null) {
        final fence = fenceMatch.group(1)!;
        final languageGroup = fenceMatch.group(2)!;
        final language = languageGroup.isEmpty ? null : languageGroup;
        final code = <String>[];
        var j = i + 1;
        while (j < lines.length && lines[j].trim() != fence) {
          code.add(lines[j]);
          j++;
        }
        flushText();
        blocks.add(CodeBlock(language: language, code: code.join('\n')));
        i = j + 1;
        continue;
      }

      final imageMatch = _standaloneImage.firstMatch(line.trim());
      if (imageMatch != null) {
        flushText();
        blocks.add(_imageBlockFromSrc(imageMatch.group(1)!));
        i++;
        continue;
      }

      if (_blockHtmlTag.hasMatch(line.trim())) {
        final html = <String>[];
        var j = i;
        while (j < lines.length && lines[j].trim().isNotEmpty) {
          html.add(lines[j]);
          j++;
        }
        flushText();
        blocks.add(HtmlBlock(html.join('\n')));
        i = j;
        continue;
      }

      textBuffer.add(line);
      i++;
    }

    flushText();
    return blocks;
  }

  ImageBlock _imageBlockFromSrc(String src) {
    if (src.startsWith('data:image')) {
      final commaIndex = src.indexOf(',');
      final data = commaIndex == -1 ? src : src.substring(commaIndex + 1);
      return ImageBlock(sourceType: ImageSourceType.base64, data: data);
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return ImageBlock(sourceType: ImageSourceType.network, data: src);
    }
    return ImageBlock(sourceType: ImageSourceType.file, data: src);
  }
}
