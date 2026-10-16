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

  /// Font aksara Jawa (Noto Sans Javanese) — GoogleFonts dengan fallback NotoSansJavanese.
  static TextStyle javanese({
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    try {
      return GoogleFonts.notoSansJavanese(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: 'NotoSansJavanese',
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
    }
  }

  /// Preload font aksara Jawa agar langsung siap digunakan tanpa jeda kotak-kotak (tofu).
  static Future<void> preloadJavanese() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSansJavanese(fontWeight: FontWeight.w400),
        GoogleFonts.notoSansJavanese(fontWeight: FontWeight.w700),
      ]);
    } catch (_) {}
  }
}
