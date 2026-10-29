import 'package:flutter/material.dart';

abstract final class AppTheme {
  /// اللون الأساسي للمتجر (royal indigo).
  static const Color brand = Color(0xFF4F46E5);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: brand);
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
