import 'package:flutter/material.dart';

class AppColors {
  // ── Primary palette: deep navy + gold ─────────────────────────────────────
  static const primary      = Color(0xFF1A3557);   // deep navy
  static const primaryDark  = Color(0xFF0F2040);   // darker navy
  static const primaryLight = Color(0xFF2A4F7C);   // mid navy

  static const accent       = Color(0xFFC9A84C);   // warm gold
  static const accentLight  = Color(0xFFE2C97E);   // soft gold

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background   = Color(0xFFF4F6FA);   // cool off-white
  static const surface      = Color(0xFFFFFFFF);
  static const surfaceWarm  = Color(0xFFEEF2F8);   // light blue-grey
  static const divider      = Color(0xFFDDE3EE);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF0F2040);
  static const textSecondary = Color(0xFF5A6A85);
  static const textLight     = Color(0xFF9BAABF);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const income  = Color(0xFF1E8A5E);   // emerald green
  static const expense = Color(0xFFD64045);   // clean red
  static const warning = Color(0xFFC9A84C);   // gold (same as accent)
  static const error   = Color(0xFFD64045);
  static const success = Color(0xFF1E8A5E);

  // ── Member colors (navy family + contrast) ─────────────────────────────────
  static const member1 = Color(0xFF1A3557);   // navy
  static const member2 = Color(0xFFC9A84C);   // gold
  static const member3 = Color(0xFF1E8A5E);   // emerald
  static const member4 = Color(0xFF7B4FAF);   // purple
  static const member5 = Color(0xFFD64045);   // red

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const gradientNavy = LinearGradient(
    colors: [Color(0xFF0F2040), Color(0xFF1A3557)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFC9A84C), Color(0xFFE2C97E)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  // Card hero gradient — navy to rich navy-blue
  static const gradientCard = LinearGradient(
    colors: [Color(0xFF0F2040), Color(0xFF1A3A6B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary:   AppColors.primary,
      secondary: AppColors.accent,
      surface:   AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins', fontSize: 18,
        fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWarm,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Poppins'),
      hintStyle: const TextStyle(color: AppColors.textLight, fontFamily: 'Poppins'),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceWarm,
      selectedColor: AppColors.primary.withOpacity(0.12),
      labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
      side: const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}