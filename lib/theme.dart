// lib/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg       = Color(0xFF0A0E1A);
  static const Color surface  = Color(0xFF111827);
  static const Color card     = Color(0xFF1A2235);
  static const Color border   = Color(0xFF2D3748);
  static const Color accent   = Color(0xFF00C8FF);   // سایان Riot
  static const Color gold     = Color(0xFFC89B3C);   // طلایی LoL
  static const Color purple   = Color(0xFF9B59B6);   // Wild Rift
  static const Color green    = Color(0xFF00D68F);
  static const Color yellow   = Color(0xFFFFD700);
  static const Color red      = Color(0xFFFF4757);
  static const Color textPrim = Color(0xFFECF0F1);
  static const Color textSec  = Color(0xFF8899AA);

  static Color latencyColor(double? ms) {
    if (ms == null)  return red;
    if (ms < 50)     return green;
    if (ms < 100)    return yellow;
    return red;
  }

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary:   accent,
      secondary: gold,
      surface:   surface,
      error:     red,
    ),
    cardColor: card,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrim, fontSize: 18, fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor:   accent,
      unselectedItemColor: textSec,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      labelStyle: const TextStyle(color: textPrim, fontSize: 12),
      selectedColor: accent.withOpacity(0.2),
      checkmarkColor: accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: textPrim),
      bodyMedium: TextStyle(color: textPrim),
      bodySmall:  TextStyle(color: textSec),
    ),
  );
}
