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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 10),
              blurRadius: 25,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gambar Reaksi Ekspresi Jawaban
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: benar ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset(
                benar
                    ? 'asset/ekpresi_jawaban/Benar.png'
                    : 'asset/ekpresi_jawaban/Salah.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    benar ? '🥳' : '😔',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Status Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: benar ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
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
            const SizedBox(height: 8),

            // Judul
            Text(
              data.title ?? (benar ? 'Jawabanmu Bener!' : 'Jawaban Kurang Tepat'),
              textAlign: TextAlign.center,
              style: AppFonts.epilogue(
                size: 20,
                weight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),

            // Ringkasan Statistik Tiles
            Row(
              children: [
                _statTile(
                  label: 'SKOR',
                  value: '${data.skor}',
                  bg: AppColors.primaryFixed.withValues(alpha: 0.4),
                  valueColor: AppColors.primary950,
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'HADIAH',
                  value: '+${data.expDidapat} XP',
                  bg: const Color(0xFFFEFCE8),
                  border: const Color(0xFFFDE68A),
                  valueColor: const Color(0xFFB45309),
                  leading: Icon(Symbols.star, size: 15, color: const Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 8),
                _statTile(
                  label: 'STREAK',
                  value: '${data.currentStreak} Dina',
                  bg: AppColors.primaryFixed.withValues(alpha: 0.4),
                  valueColor: AppColors.primary950,
                  leading: const Text('🔥', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Penjelasan / Kunci Jawaban (jika salah atau disediakan)
            if (data.kunciDisplay != null && data.kunciDisplay!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _kunciBox(data.kunciDisplay!, data.keterangan),
            ],

            // Banner Level Selesai
            if (data.levelSelesai) ...[
              const SizedBox(height: 12),
              _levelSelesaiBanner(data),
            ],

            const SizedBox(height: 14),

            // Tombol Aksi Utama
            _primaryAction(
              label: data.levelSelesai ? 'Mulai Level Berikutnya' : 'Soal Selanjutnya',
              icon: data.levelSelesai ? Symbols.military_tech : Symbols.arrow_forward,
              color: AppColors.primary600,
              onTap: onNext,
            ),
            const SizedBox(height: 8),

            // Tombol Beranda
            GestureDetector(
              onTap: onHome,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'Bali Menyang Beranda',
                  style: AppFonts.epilogue(
                    size: 12,
                    weight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
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
    required Color valueColor,
    Color? border,
    Widget? leading,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppFonts.epilogue(
                size: 10,
                weight: FontWeight.w800,
                color: AppColors.primary600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 3)],
                Text(
                  value,
                  style: AppFonts.epilogue(
                    size: 14,
                    weight: FontWeight.w900,
                    color: valueColor,
                  ),
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
        color: AppColors.primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.info, size: 14, color: AppColors.primary700),
              const SizedBox(width: 4),
              Text(
                'KUNCI JAWABAN:',
                style: AppFonts.epilogue(
                  size: 10,
                  weight: FontWeight.w800,
                  color: AppColors.primary700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            kunci,
            textAlign: TextAlign.center,
            style: AppFonts.epilogue(
              size: 13,
              weight: FontWeight.w900,
              color: AppColors.primary950,
              height: 1.25,
            ),
          ),
          if (keterangan != null && keterangan.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.primary700,
              ),
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
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Symbols.military_tech,
                size: 18,
                color: Color(0xFF059669),
                fill: 1.0,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Level Rampung! +${data.rewardExp} Bonus XP!',
                  textAlign: TextAlign.center,
                  style: AppFonts.epilogue(
                    size: 13,
                    weight: FontWeight.w900,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            data.levelBerikutnya != null
                ? 'Level sabanjure saiki wis kabukak.'
                : 'Kabeh materi ing level iki wis rampung 100%!',
            textAlign: TextAlign.center,
            style: AppFonts.manrope(
              size: 11,
              weight: FontWeight.w600,
              color: const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                offset: Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppFonts.epilogue(
                  size: 14,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
