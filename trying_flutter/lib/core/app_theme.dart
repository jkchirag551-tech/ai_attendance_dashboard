import 'package:flutter/material.dart';

class AppColors {
  // Pure Monochrome Light Palette
  static const bgTop = Color(0xFFFFFFFF);    // Pure White
  static const bgMid = Color(0xFFF8F9FA);    // Near White
  static const bgBottom = Color(0xFFFFFFFF); // Pure White
  
  // High Contrast Surfaces for Light Theme
  static const card = Color(0x0D000000);      // Very Translucent Black
  static const cardBorder = Color(0x1A000000); // Subtle Black Border
  
  // Monochrome Accents
  static const accent = Color(0xFF000000);    // Pure Black
  static const secondary = Color(0xFF475569); // Slate 600
  static const textMuted = Color(0xFF64748B); // Slate 500
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bgTop,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.secondary,
      surface: AppColors.bgMid,
      onSurface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: const Color(0xFF000000),
      displayColor: Colors.black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
