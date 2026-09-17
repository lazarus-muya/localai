import 'package:flutter/material.dart';

/// Design tokens borrowed from LM Studio's desktop UI: a three-tier dark
/// surface hierarchy (sidebar / content / card), a bright accent blue for
/// selection, and muted secondary text. Not fully expressed by Flutter's
/// [ColorScheme], so it lives as a separate [ThemeExtension].
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.sidebarBackground,
    required this.sidebarBorder,
    required this.cardBackground,
    required this.cardBorder,
    required this.inputFill,
    required this.divider,
    required this.textPrimary,
    required this.mutedText,
    required this.groupLabel,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.warning,
  });

  final Color background;
  final Color sidebarBackground;
  final Color sidebarBorder;
  final Color cardBackground;
  final Color cardBorder;
  final Color inputFill;
  final Color divider;
  final Color textPrimary;
  final Color mutedText;
  final Color groupLabel;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color success;
  final Color warning;

  static const dark = AppPalette(
    background: Color(0xFF0F1115),
    sidebarBackground: Color(0xFF0A0B0E),
    sidebarBorder: Color(0xFF1F2126),
    cardBackground: Color(0xFF17191F),
    cardBorder: Color(0xFF262932),
    inputFill: Color(0xFF1B1D23),
    divider: Color(0xFF24262C),
    textPrimary: Color(0xFFE7E9EE),
    mutedText: Color(0xFF9198A6),
    groupLabel: Color(0xFF6E7480),
    accent: Color(0xFF3373F2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFE5484D),
    success: Color(0xFF3DD68C),
    warning: Color(0xFFF2A93B),
  );

  static const light = AppPalette(
    background: Color(0xFFF6F7F9),
    sidebarBackground: Color(0xFFFFFFFF),
    sidebarBorder: Color(0xFFE6E7EB),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE3E5E9),
    inputFill: Color(0xFFF2F3F5),
    divider: Color(0xFFE9EAEE),
    textPrimary: Color(0xFF14161A),
    mutedText: Color(0xFF666C78),
    groupLabel: Color(0xFF8A8F99),
    accent: Color(0xFF2F6FED),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD8353B),
    success: Color(0xFF1FA971),
    warning: Color(0xFFB2790A),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? sidebarBackground,
    Color? sidebarBorder,
    Color? cardBackground,
    Color? cardBorder,
    Color? inputFill,
    Color? divider,
    Color? textPrimary,
    Color? mutedText,
    Color? groupLabel,
    Color? accent,
    Color? onAccent,
    Color? danger,
    Color? success,
    Color? warning,
  }) {
    return AppPalette(
      background: background ?? this.background,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      inputFill: inputFill ?? this.inputFill,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      mutedText: mutedText ?? this.mutedText,
      groupLabel: groupLabel ?? this.groupLabel,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      groupLabel: Color.lerp(groupLabel, other.groupLabel, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
