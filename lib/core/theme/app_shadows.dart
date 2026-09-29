import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Bayangan (shadow) selaras design system web.
class AppShadows {
  AppShadows._();

  /// Shadow kartu bergaya "3D" (0 4px 0 rgba(15,23,42,.07), 0 2px 4px rgba(15,23,42,.05))
  static List<BoxShadow> get card => const [
        BoxShadow(
          color: Color(0x120F172A),
          offset: Offset(0, 4),
          blurRadius: 0,
        ),
        BoxShadow(
          color: Color(0x0D0F172A),
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
      ];

  static List<BoxShadow> get cardHover => const [
        BoxShadow(
          color: Color(0x170F172A),
          offset: Offset(0, 6),
          blurRadius: 0,
        ),
        BoxShadow(
          color: Color(0x0F0F172A),
          offset: Offset(0, 3),
          blurRadius: 10,
        ),
      ];

  static List<BoxShadow> get sm => const [
        BoxShadow(
          color: Color(0x0D000000),
          offset: Offset(0, 1),
          blurRadius: 2,
        ),
      ];

  static List<BoxShadow> get md => const [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 4),
          blurRadius: 6,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: Color(0x0F000000),
          offset: Offset(0, 2),
          blurRadius: 4,
          spreadRadius: -1,
        ),
      ];

  static List<BoxShadow> get lg => const [
        BoxShadow(
          color: Color(0x1A000000),
          offset: Offset(0, 10),
          blurRadius: 15,
          spreadRadius: -3,
        ),
        BoxShadow(
          color: Color(0x0F000000),
          offset: Offset(0, 4),
          blurRadius: 6,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get header => const [
        BoxShadow(
          color: Color(0x0A000000),
          offset: Offset(0, 1),
          blurRadius: 8,
        ),
      ];

  static List<BoxShadow> get bottomNav => const [
        BoxShadow(
          color: Color(0x14000000),
          offset: Offset(0, -4),
          blurRadius: 24,
        ),
      ];

  static List<BoxShadow> primary([double opacity = 0.30]) => [
        BoxShadow(
          color: AppColors.primary600.withValues(alpha: opacity),
          offset: const Offset(0, 4),
          blurRadius: 10,
          spreadRadius: -2,
        ),
      ];
}
