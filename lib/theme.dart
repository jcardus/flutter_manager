import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF2196F3);

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
      ).copyWith(
        tertiary: const Color(0xFF4CAF50), // Success green for light mode
      ),
      useMaterial3: true,
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        tertiary: const Color(0xFF81C784), // Success green for dark mode
      ),
      useMaterial3: true,
    );
  }
}
