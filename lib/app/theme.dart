import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// ألوان الشعار الرسمي (انظر brand/README.md).
  static const Color brand = Color(0xFF1B2A5C);
  static const Color gold = Color(0xFFC9A24A);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: brand, primary: brand, secondary: gold);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    );
  }
}
