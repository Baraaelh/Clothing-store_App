import 'package:flutter/material.dart';

/// ألوان الهوية، نفس متغيرات `:root` في المتجر الإلكتروني (live-store.css).
abstract final class AppColors {
  /// الأصفر الذهبي الأساسي: الأزرار والعناصر المختارة.
  static const accent = Color(0xFFF0B81C);
  static const accentLight = Color(0xFFF8D548);

  /// لون الضغط/التمرير على الأصفر.
  static const accentDark = Color(0xFFDCA312);

  /// الكلام فوق الأصفر (تباين 7.6:1).
  static const onAccent = Color(0xFF3B2A05);

  /// اسم المتجر/التطبيق (ذهبي أفتح ينقرأ على الأبيض بخط كبير).
  static const brandName = Color(0xFFB8860B);

  /// الذهبي الغامق للكلام الملوّن الصغير على الأبيض (أسعار، روابط).
  static const brand = Color(0xFF94702F);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: const Color(0xFFFBEBB5),
      onPrimaryContainer: AppColors.onAccent,
      secondary: AppColors.brand,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFBEBB5),
      onSecondaryContainer: AppColors.onAccent,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      // الأزرار المحددة (TextButton/OutlinedButton) بالذهبي الغامق: الأصفر لا ينقرأ ككلام على الأبيض.
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.brand)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: AppColors.brand)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brand),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
      ),
    );
  }
}
