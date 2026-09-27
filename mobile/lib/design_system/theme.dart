import 'package:flutter/material.dart';

import 'colors.dart';

/// Espaciado y radios del sistema de diseño EquaHome.
class EquaSpace {
  EquaSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class EquaRadius {
  EquaRadius._();

  static const double card = 18;
  static const double control = 14;
}

ThemeData buildEquaTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: EquaColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: EquaColors.primaryDark,
    secondary: EquaColors.secondary,
    surface: EquaColors.surface,
    onSurface: EquaColors.ink,
    outline: EquaColors.divider,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: EquaColors.background,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: EquaColors.ink),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: EquaColors.ink),
      bodyMedium: TextStyle(fontSize: 16, color: EquaColors.ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: EquaColors.inkSoft, height: 1.35),
    ),
  );

  return base.copyWith(
    cardTheme: CardThemeData(
      color: EquaColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EquaRadius.card),
        side: const BorderSide(color: EquaColors.divider),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EquaColors.primary,
        foregroundColor: EquaColors.ink,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EquaRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EquaColors.primaryDark,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: EquaColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EquaRadius.control),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EquaColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EquaSpace.md,
        vertical: EquaSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EquaRadius.control),
        borderSide: const BorderSide(color: EquaColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EquaRadius.control),
        borderSide: const BorderSide(color: EquaColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EquaRadius.control),
        borderSide: const BorderSide(color: EquaColors.primary, width: 1.6),
      ),
    ),
    dividerTheme: const DividerThemeData(color: EquaColors.divider, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
