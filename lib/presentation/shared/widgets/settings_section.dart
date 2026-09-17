import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// A labeled group of related settings, rendered as a small caps heading
/// above a bordered card — mirrors LM Studio's settings page layout.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Text(
                title!,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.divider),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row inside a [SettingsSection]: a title/subtitle on the left and
/// an arbitrary trailing control on the right (switch, dropdown, button…).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingWidth,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double? trailingWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: palette.mutedText, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            if (trailingWidth != null)
              SizedBox(width: trailingWidth, child: trailing)
            else
              trailing!,
          ],
        ],
      ),
    );
  }
}

/// A row that spans the full card width below its label — for multiline
/// inputs (system prompt) that don't fit the label/trailing pattern.
class SettingsBlockRow extends StatelessWidget {
  const SettingsBlockRow({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(color: palette.mutedText, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
