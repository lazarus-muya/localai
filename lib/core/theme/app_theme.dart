import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  static ThemeData light() =>
      _build(_isWindows ? AppPalette.windowsLight : AppPalette.light, Brightness.light);

  static ThemeData dark() =>
      _build(_isWindows ? AppPalette.windowsDark : AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final win = _isWindows;
    // Fluent uses small corners; Material's big pills read as "web app".
    final rControl = win ? 4.0 : 8.0;
    final rSurface = win ? 8.0 : 12.0;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.cardBackground,
      onSurface: p.textPrimary,
      error: p.danger,
      outline: p.cardBorder,
      outlineVariant: p.divider,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: win ? 'Segoe UI' : null,
      visualDensity: win ? VisualDensity.compact : VisualDensity.standard,
      splashFactory: win ? NoSplash.splashFactory : null,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      hoverColor: p.textPrimary.withValues(alpha: 0.05),
      highlightColor: win ? p.textPrimary.withValues(alpha: 0.07) : null,
      scrollbarTheme: win
          ? ScrollbarThemeData(
              thickness: const WidgetStatePropertyAll(6),
              radius: const Radius.circular(3),
              thumbColor: WidgetStatePropertyAll(p.mutedText.withValues(alpha: 0.5)),
            )
          : null,
      tooltipTheme: win
          ? TooltipThemeData(
              decoration: BoxDecoration(
                color: p.cardBackground,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: p.cardBorder),
              ),
              textStyle: TextStyle(color: p.textPrimary, fontSize: 12),
              waitDuration: const Duration(milliseconds: 500),
            )
          : null,
      // Swap the Material default zoom/scale page transition (Android's
      // ZoomPageTransitionsBuilder) for a subtle fade+slide. Top-level nav
      // in this app is transition-free (see app_router.dart), so this only
      // covers any route that gets pushed on top of a tab — it should still
      // feel calm rather than scaling in.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: base.textTheme.apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: win ? 20 : 18,
          fontWeight: win ? FontWeight.w600 : FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSurface),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: TextStyle(color: p.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: BorderSide(color: p.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: BorderSide(color: p.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: BorderSide(color: p.accent, width: win ? 2 : 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.accent;
          return win ? Colors.transparent : p.cardBorder;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (!win || states.contains(WidgetState.selected)) return p.onAccent;
          return p.mutedText;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (win && !states.contains(WidgetState.selected)) return p.mutedText;
          return Colors.transparent;
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.cardBackground,
        side: BorderSide(color: p.cardBorder),
        shape: win ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)) : const StadiumBorder(),
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(iconColor: p.mutedText, textColor: p.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: p.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSurface),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(win ? 8 : 10),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.mutedText,
        indicatorColor: p.accent,
        dividerColor: p.divider,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.sidebarBackground,
        indicatorColor: p.accent.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? p.accent : p.mutedText,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.accent : p.mutedText,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.accent;
            return p.inputFill;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.onAccent;
            return p.mutedText;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: p.cardBorder)),
        ),
      ),
    );
  }
}
