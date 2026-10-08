import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/quiz_result.dart';

class FeedbackModalData {
  const FeedbackModalData({
    required this.benar,
    required this.skor,
    required this.expDidapat,
    required this.currentStreak,
    this.title,
    this.kunciDisplay,
    this.keterangan,
    this.levelSelesai = false,
    this.rewardExp = 0,
    this.levelBerikutnya,
  });

  final bool benar;
  final int skor;
  final int expDidapat;
  final int currentStreak;
  final String? title;
  final String? kunciDisplay;
  final String? keterangan;
  final bool levelSelesai;
  final int rewardExp;
  final String? levelBerikutnya;

  factory FeedbackModalData.fromResult(JawabanResult res, {String? title}) {
    return FeedbackModalData(
      benar: res.benar,
      skor: res.skor,
      expDidapat: res.expDidapat,
      currentStreak: res.currentStreak,
      title: title,
      kunciDisplay: res.kunciDisplay,
      levelSelesai: res.levelSelesai,
      rewardExp: res.rewardExp,
      levelBerikutnya: res.levelBerikutnya,
    );
  }
}

Future<void> showQuizFeedbackModal(
  BuildContext context, {
  required FeedbackModalData data,
  required VoidCallback onNext,
  required VoidCallback onHome,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x990F172A),
    builder: (ctx) => _FeedbackDialog(data: data, onNext: onNext, onHome: onHome),
  );
}

class _FeedbackDialog extends StatelessWidget {
  const _FeedbackDialog({
    required this.data,
    required this.onNext,
    required this.onHome,
  });

  final FeedbackModalData data;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final benar = data.benar;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gray200, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), offset: Offset(0, 6), blurRadius: 0, spreadRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: benar ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: benar ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                benar ? '🥳' : '😔',
                style: const TextStyle(fontSize: 34),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: benar ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  bottom: BorderSide(
                    color: benar ? const Color(0xFF047857) : const Color(0xFFBE123C),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    benar ? Symbols.verified : Symbols.cancel,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    benar ? 'LERES SANGET!' : 'DURUNG PAS!',
                    style: AppFonts.epilogue(
                      size: 11,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.title ?? (benar ? 'Jawabanmu Bener!' : 'Jawaban Kurang Tepat'),
              textAlign: TextAlign.center,
              style: AppFonts.epilogue(size: 19, weight: FontWeight.w900, color: AppColors.black900),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statTile(
                  label: 'SKOR',
                  value: '${data.skor}/100',
                  bg: const Color(0xFFF8FAFC),
                  border: AppColors.gray200,
                  valueColor: AppColors.black900,
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'HADIAH',
                  value: '+${data.expDidapat} XP',
                  bg: const Color(0xFFFEFCE8),
                  border: const Color(0xFFFDE68A),
                  valueColor: const Color(0xFFB45309),
                  leading: const Icon(Symbols.star, size: 15, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'STREAK',
                  value: '${data.currentStreak} Dina',
                  bg: const Color(0xFFFFF7ED),
                  border: const Color(0xFFFED7AA),
                  valueColor: const Color(0xFFC2410C),
                  leading: const Text('🔥', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (data.kunciDisplay != null && data.kunciDisplay!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _kunciBox(data.kunciDisplay!, data.keterangan),
            ],
            if (data.levelSelesai) ...[
              const SizedBox(height: 12),
              _levelSelesaiBanner(data),
            ],
            const SizedBox(height: 14),
            _primaryAction('Soal Selanjutnya', Symbols.arrow_forward, AppColors.primary700, onNext),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onHome,
              child: Text(
                'BALI MENYANG BERANDA',
                style: AppFonts.epilogue(
                  size: 12,
                  weight: FontWeight.w800,
                  color: AppColors.gray500,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required Color bg,
    required Color border,
    required Color valueColor,
    Widget? leading,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppFonts.epilogue(
                size: 9,
                weight: FontWeight.w800,
                color: AppColors.gray400,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 3)],
                Text(
                  value,
                  style: AppFonts.epilogue(size: 14, weight: FontWeight.w900, color: valueColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kunciBox(String kunci, String? keterangan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.info, size: 14, color: Color(0xFFB45309)),
              const SizedBox(width: 5),
              Text(
                'KUNCI JAWABAN:',
                style: AppFonts.epilogue(
                  size: 10,
                  weight: FontWeight.w800,
                  color: const Color(0xFFB45309),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            kunci,
            style: AppFonts.epilogue(size: 13, weight: FontWeight.w800, color: AppColors.black900),
          ),
          if (keterangan != null && keterangan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              keterangan,
              style: AppFonts.manrope(size: 12, color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _levelSelesaiBanner(FeedbackModalData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.military_tech, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Level Rampung! +${data.rewardExp} Bonus XP!',
                  style: AppFonts.epilogue(size: 13, weight: FontWeight.w900, color: const Color(0xFF047857)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            data.levelBerikutnya != null
                ? 'Level sabanjure ${data.levelBerikutnya} saiki wis kabukak.'
                : 'Kabeh materi ing level iki wis rampung 100%!',
            style: AppFonts.manrope(size: 11, weight: FontWeight.w600, color: const Color(0xFF047857)),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border(bottom: BorderSide(color: _darken(color), width: 4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: AppFonts.epilogue(size: 13, weight: FontWeight.w900, color: Colors.white, letterSpacing: 0.6),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }
}
