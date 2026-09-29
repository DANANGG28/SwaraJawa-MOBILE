import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font yang dipakai website: Epilogue (heading), Manrope (body), Nunito
/// (khusus Beranda & Pilih Topik yang memang memakai Nunito).
class AppFonts {
  AppFonts._();

  static TextStyle epilogue({
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.epilogue(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle manrope({
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle nunito({
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Font aksara Jawa (Noto Sans Javanese) — opsional, fallback ke Manrope.
  static TextStyle javanese({
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'NotoSansJavanese',
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
