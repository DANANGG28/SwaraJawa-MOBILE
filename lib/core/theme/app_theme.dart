import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary600,
        brightness: Brightness.light,
        primary: AppColors.primary600,
        surface: AppColors.surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: GoogleFontsTextTheme.manrope(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppFonts.epilogue(
          size: 18,
          weight: FontWeight.w800,
          color: AppColors.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: AppFonts.manrope(size: 14, color: AppColors.gray500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
        ),
      ),
      iconTheme: const IconThemeData(size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary600,
      ),
    );
  }

  static IconData icon(String materialSymbol) {
    // Helper tidak dipakai runtime; ikon ditulis langsung via Symbols.*
    return Symbols.circle;
  }
}

/// Text theme memakai Manrope sebagai font body default.
class GoogleFontsTextTheme {
  static TextTheme manrope(TextTheme base) {
    return base.apply(
      fontFamily: AppFonts.manrope().fontFamily,
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );
  }
}
