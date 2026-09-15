import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' as hl;

class CodeBlockView extends StatelessWidget {
  const CodeBlockView({super.key, this.language, required this.code});

  final String? language;
  final String code;

  bool _isSupportedLanguage(String lang) {
    try {
      hl.highlight.parse('', language: lang);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveLanguage =
        (language != null && _isSupportedLanguage(language!)) ? language : null;

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
                  child: Text(
                    language?.isNotEmpty == true ? language! : 'code',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy code',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: effectiveLanguage != null
                  ? HighlightView(
                      code,
                      language: effectiveLanguage,
                      theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    )
                  : SelectableText(
                      code,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
