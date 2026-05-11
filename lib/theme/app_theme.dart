import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── Brand colors ───────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF5F80F8);
  static const Color primaryTeal = Color(0xFF1CE6DA);
  static const Color accentBlue  = Color(0xFF0084FF);
  static const Color seedBlue    = Color(0xFF00529B);

  // ── Background colors ──────────────────────────────────────────────────────
  static const Color mainBackground = Color(0xFFF2F4FF); // for MainAppBar screens
  static const Color surfaceGrey    = Color(0xFFF3F4F6);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryTeal],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientDiagonal = LinearGradient(
    colors: [primaryBlue, primaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // functionBackground gradient — use on body Container for FunctionAppBar screens:
  // body: Container(decoration: BoxDecoration(gradient: AppTheme.functionBackground), ...)
  static const LinearGradient functionBackground = LinearGradient(
    colors: [primaryBlue, primaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Text colors ────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1A1A2E);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFFE3E3E3);
  static const Color textOnGradient = Colors.white;

  // ── Text theme ─────────────────────────────────────────────────────────────
  static const TextTheme appTextTheme = TextTheme(
    titleLarge:  TextStyle(fontSize: 20, fontWeight: FontWeight.bold,   color: textPrimary),   // Section heads, input labels, card titles
    bodyLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.normal, color: textPrimary),   // Main body text, descriptions
    bodyMedium:  TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: textSecondary), // Secondary text, filter chips, subtitles
    bodySmall:   TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textSecondary), // Captions, timestamps, metadata
    labelLarge:  TextStyle(fontSize: 16, fontWeight: FontWeight.w600,   color: Colors.white),  // Button labels
  );

  // ── Themes ─────────────────────────────────────────────────────────────────

  // Use for screens with MainAppBar
  static ThemeData get mainTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: mainBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedBlue,
      brightness: Brightness.light,
    ),
    textTheme: appTextTheme,
  );

  // Use for screens with FunctionAppBar
  // Set scaffoldBackgroundColor to transparent, then wrap body in:
  // Container(decoration: BoxDecoration(gradient: AppTheme.functionBackground))
  static ThemeData get functionTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedBlue,
      brightness: Brightness.light,
    ),
    textTheme: appTextTheme,
  );
}
