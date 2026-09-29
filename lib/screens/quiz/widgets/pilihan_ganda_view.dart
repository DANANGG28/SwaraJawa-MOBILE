import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../models/quiz_result.dart';
import '../../../models/soal.dart';

class PilihanGandaView extends StatefulWidget {
  const PilihanGandaView({
    super.key,
    required this.soal,
    required this.nomor,
    required this.total,
    required this.result,
    required this.onChanged,
  });

  final Soal soal;
  final int nomor;
  final int total;
  final JawabanResult? result;
  final ValueChanged<dynamic> onChanged;

  @override
  State<PilihanGandaView> createState() => _PilihanGandaViewState();
}

class _PilihanGandaViewState extends State<PilihanGandaView> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = null;
  }

  String? get _kunciLabel {
    final detail = widget.result?.detail;
    if (detail != null && detail['kunci_label'] != null) {
      return detail['kunci_label'].toString();
    }
    if (widget.result?.kunciDisplay.startsWith(RegExp(r'^[A-Z]\.')) == true) {
      return widget.result!.kunciDisplay.substring(0, 1);
    }
    return widget.result?.kunciDisplay;
  }

  @override
  Widget build(BuildContext context) {
    final opsi = widget.soal.opsiPilihan;
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LATIHAN ${widget.nomor} DARI ${widget.total}',
          style: AppFonts.manrope(
            size: 13,
            weight: FontWeight.w800,
            color: AppColors.primary600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.soal.pertanyaan,
          style: AppFonts.epilogue(size: 22, weight: FontWeight.w800, height: 1.3),
        ),
        const SizedBox(height: 20),
        for (final o in opsi) ...[
          _opsiCard(o, result),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _opsiCard(OpsiPilihan o, JawabanResult? result) {
    final selected = _selected == o.label;
    final kunciLabel = _kunciLabel;

    Color border = AppColors.gray200;
    Color bg = Colors.white;
    Color badgeBg = AppColors.surfaceContainerHigh;
    Color badgeFg = AppColors.onSurfaceVariant;
    IconData? mark;
    Color? markColor;

    if (result == null) {
      if (selected) {
        border = AppColors.primary600;
        bg = AppColors.primaryFixed.withValues(alpha: 0.4);
        badgeBg = AppColors.primary600;
        badgeFg = Colors.white;
        mark = Symbols.radio_button_checked;
        markColor = AppColors.primary600;
      }
    } else {
      final isCorrect = kunciLabel != null && o.label == kunciLabel;
      final isWrongSelected = selected && !result.benar;
      if (isCorrect) {
        border = const Color(0xFF22C55E);
        bg = const Color(0xFF22C55E).withValues(alpha: 0.1);
        badgeBg = const Color(0xFF22C55E);
        badgeFg = Colors.white;
        mark = Symbols.check_circle;
        markColor = const Color(0xFF22C55E);
      } else if (isWrongSelected) {
        border = AppColors.error;
        bg = AppColors.errorContainer.withValues(alpha: 0.4);
        badgeBg = AppColors.error;
        badgeFg = Colors.white;
        mark = Symbols.cancel;
        markColor = AppColors.error;
      }
    }

    return GestureDetector(
      onTap: result != null
          ? null
          : () {
              setState(() => _selected = o.label);
              widget.onChanged(o.label);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                o.label,
                style: AppFonts.epilogue(size: 18, weight: FontWeight.w800, color: badgeFg),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                o.teks,
                style: AppFonts.epilogue(size: 16, weight: FontWeight.w700, height: 1.25),
              ),
            ),
            if (mark != null) ...[
              const SizedBox(width: 8),
              Icon(mark, size: 24, color: markColor),
            ],
          ],
        ),
      ),
    );
  }
}

class KuisRewardChip extends StatelessWidget {
  const KuisRewardChip({super.key, required this.exp});

  final int exp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.yellow300.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.star, size: 20, color: AppColors.orange500),
          const SizedBox(width: 6),
          Text(
            'Hadiah: +$exp XP',
            style: AppFonts.manrope(size: 14, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Tombol periksa jawaban (3D).
class PeriksaButton extends StatelessWidget {
  const PeriksaButton({
    super.key,
    required this.enabled,
    required this.onTap,
    this.label = 'Periksa Jawaban',
    this.icon = Symbols.arrow_forward,
    this.loading = false,
  });

  final bool enabled;
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        decoration: BoxDecoration(
          color: active ? AppColors.primary600 : AppColors.primary600.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? const [BoxShadow(color: AppColors.primary700, offset: Offset(0, 4), blurRadius: 0)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            else ...[
              Text(
                label.toUpperCase(),
                style: AppFonts.epilogue(
                  size: 14,
                  weight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu data kosong (belum ada soal).
class KuisEmptyCard extends StatelessWidget {
  const KuisEmptyCard({super.key, required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gray200, width: 2),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.gray500),
          const SizedBox(height: 12),
          Text(title, style: AppFonts.epilogue(size: 22, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.manrope(size: 15, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }
}
