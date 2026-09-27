import 'package:flutter/material.dart';

/// EquaHome pastel palette — the single source of truth for color.
/// Widgets must use these tokens (via ThemeData), never hard-coded colors.
class EquaColors {
  EquaColors._();

  static const Color primary = Color(0xFFB4A7D6); // lavanda
  static const Color primaryDark = Color(0xFF7E6BA8); // lavanda profunda (texto/acento)
  static const Color success = Color(0xFFA9CBA1); // verde salvia
  static const Color info = Color(0xFFA8C8E8); // azul cielo
  static const Color secondary = Color(0xFFE8B9C9); // rosa
  static const Color warningSoft = Color(0xFFF2E3B6); // amarillo crema
  static const Color background = Color(0xFFFAF6EF); // blanco cálido
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF403B52); // ciruela oscura (texto)
  static const Color inkSoft = Color(0xFF6E6884); // texto secundario
  static const Color divider = Color(0xFFEDE7DC);
}
