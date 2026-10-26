import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_fonts.dart';
import '../models/progres.dart';
import '../models/siswa.dart';
import '../state/app_state.dart';

/// Menampilkan pop-up streak harian yang identik dengan modal web SwaraJawa.
Future<void> showStreakModal(
  BuildContext context, {
  required Siswa? siswa,
  List<WeekStreakDay>? weekStreak,
  VoidCallback? onContinue,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x800F172A),
    builder: (ctx) => _StreakDialog(
      siswa: siswa,
      weekStreak: weekStreak,
      onContinue: onContinue,
    ),
  );
}

class _StreakDialog extends StatefulWidget {
  const _StreakDialog({
    required this.siswa,
    this.weekStreak,
    this.onContinue,
  });

  final Siswa? siswa;
  final List<WeekStreakDay>? weekStreak;
  final VoidCallback? onContinue;

  @override
  State<_StreakDialog> createState() => _StreakDialogState();
}

class _StreakDialogState extends State<_StreakDialog> {
  late List<WeekStreakDay> _days;

  @override
  void initState() {
    super.initState();
    final currentStreak = widget.siswa?.currentStreak ?? 0;
    _days = (widget.weekStreak != null && widget.weekStreak!.isNotEmpty)
        ? widget.weekStreak!
        : WeekStreakDay.generateFallback(
            currentStreak: currentStreak,
            lastActivityDate: widget.siswa?.strek.lastActivityDate,
          );

    // Ambil data terbaru di latar belakang tanpa menghambat pembukaan modal
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.weekStreak != null && widget.weekStreak!.isNotEmpty) return;
      try {
        final progres = await context.read<AppState>().progres.ambil();
        if (mounted && progres.weekStreak.isNotEmpty) {
          setState(() {
            _days = progres.weekStreak;
          });
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentStreak = widget.siswa?.currentStreak ?? 0;
    final highestStreak = widget.siswa?.highestStreak ?? currentStreak;
    final days = _days;
    final activeCount = days.where((d) => d.aktif).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFDDD6FE), width: 2),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER: Icon Api + Judul + Tombol X
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Symbols.local_fire_department,
                    size: 22,
                    color: Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Streak Belajar Aktif!',
                        style: AppFonts.nunito(
                          size: 16,
                          weight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rekapitulasi Konsistensi Belajar',
                        style: AppFonts.nunito(
                          size: 11,
                          weight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.close,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // HERO CARD: Current Streak + Highest Streak
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentStreak',
                        style: AppFonts.nunito(
                          size: 32,
                          weight: FontWeight.w900,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hari Berturut-turut!',
                        style: AppFonts.nunito(
                          size: 17,
                          weight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: AppFonts.nunito(
                        size: 12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                      children: [
                        const TextSpan(text: 'Rekor Tertinggi: '),
                        TextSpan(
                          text: '$highestStreak Hari',
                          style: AppFonts.nunito(
                            size: 12,
                            weight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // WEEKLY CALENDAR: "Minggu Ini"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Minggu Ini',
                  style: AppFonts.nunito(
                    size: 12,
                    weight: FontWeight.w800,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  '$activeCount dari 7 Hari Selesai',
                  style: AppFonts.nunito(
                    size: 11,
                    weight: FontWeight.w900,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 7 Days Grid/Row
            Row(
              children: [
                for (int i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(child: _buildDayItem(days[i])),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // QUOTE CARD MOTIVASI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                '“Belajar sethithik saben dina luwih apik tinimbang akeh nanging mung sedhela. Pertahankan streak-mu!”',
                textAlign: TextAlign.center,
                style: AppFonts.nunito(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF475569),
                  height: 1.45,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),

            // FOOTER BUTTONS: "Tutup" & "Lanjutkan Belajar"
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Tutup',
                          style: AppFonts.nunito(
                            size: 13,
                            weight: FontWeight.w900,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onContinue?.call();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brand600,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x337C3AED),
                              offset: Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          'Lanjutkan Belajar',
                          style: AppFonts.nunito(
                            size: 13,
                            weight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayItem(WeekStreakDay day) {
    Color bg;
    Border? border;
    Color labelColor;

    if (day.isToday) {
      bg = const Color(0xFFFFEDD5);
      border = Border.all(color: const Color(0xFFFB923C), width: 2);
      labelColor = const Color(0xFF431407);
    } else if (day.aktif) {
      bg = const Color(0xFFECFDF5);
      border = Border.all(color: const Color(0xFFA7F3D0));
      labelColor = const Color(0xFF065F46);
    } else {
      bg = const Color(0xFFF8FAFC);
      border = Border.all(color: const Color(0xFFE2E8F0));
      labelColor = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day.label.toUpperCase(),
            style: AppFonts.nunito(
              size: 10,
              weight: FontWeight.w900,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 6),
          if (day.aktif)
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.check,
                size: 14,
                color: Colors.white,
                weight: 700,
              ),
            )
          else if (day.isToday)
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF97316),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.local_fire_department,
                size: 14,
                color: Colors.white,
              ),
            )
          else
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                day.isFuture ? '+10' : '·',
                style: AppFonts.nunito(
                  size: day.isFuture ? 9 : 14,
                  weight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
