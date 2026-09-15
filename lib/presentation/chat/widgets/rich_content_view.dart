import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../domain/entities/content_block.dart';
import '../../../domain/usecases/content_block_parser.dart';
import 'code_block_view.dart';
import 'html_block_view.dart';
import 'image_block_view.dart';

const _parser = ContentBlockParser();

/// Renders a raw model response as ordered blocks — markdown text, fenced
/// code (syntax highlighted), raw HTML, and images — each independently
/// copyable via its own widget.
class RichContentView extends StatelessWidget {
  const RichContentView({super.key, required this.content, required this.textColor});

  final String content;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final blocks = _parser.parse(content);
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final block in blocks) _buildBlock(context, block)],
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: switch (block) {
        TextBlock(:final markdown) => MarkdownBody(
            data: markdown,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: TextStyle(color: textColor),
            ),
          ),
        CodeBlock(:final language, :final code) => CodeBlockView(language: language, code: code),
        HtmlBlock(:final html) => HtmlBlockView(html: html),
        ImageBlock() => ImageBlockView(block: block),
      },
    );
  }
}
