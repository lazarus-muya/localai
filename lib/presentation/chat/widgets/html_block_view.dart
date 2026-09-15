import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

/// Renders raw HTML from a model response as syntax-highlighted source
/// rather than live-rendering it: LLM-generated HTML is frequently
/// malformed, and live-rendering arbitrary HTML inside a chat bubble opens
/// a UX/security surface (stray styles, scripts-shaped markup) that isn't
/// worth it here. Copy it out if you want to actually render it elsewhere.
class HtmlBlockView extends StatelessWidget {
  const HtmlBlockView({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: isDark ? const Color(0xFF282C34) : const Color(0xFFFAFAFA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('html', style: Theme.of(context).textTheme.labelSmall),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy HTML',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: html));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('HTML copied'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: HighlightView(
                html,
                language: 'xml',
                theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
