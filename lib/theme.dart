import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF2196F3);

  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ).copyWith(
        tertiary: const Color(0xFF4CAF50), // Success green
      ),
      useMaterial3: true,
    );
  }
}
