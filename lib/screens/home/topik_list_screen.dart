import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_shadows.dart';
import '../../models/topik.dart';

/// Daftar topik berbentuk kartu (hierarki kurikulum tingkat atas).
class TopikListContent extends StatelessWidget {
  const TopikListContent({
    super.key,
    required this.topiks,
    required this.activeId,
    this.onSelect,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
    this.headerTitle = 'Pilih Topik',
    this.headerSubtitle = 'Pilih bagian pasinaon sing arep disinaoni.',
  });

  final List<Topik> topiks;
  final int? activeId;
  final ValueChanged<Topik>? onSelect;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final String headerTitle;
  final String headerSubtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        _header(),
        const SizedBox(height: 18),
        if (onBack != null) ...[
          _kembaliCard(),
          const SizedBox(height: 14),
        ],
        if (topiks.isEmpty)
          _emptyCard()
        else
          for (final topik in topiks) ...[
            _topikCard(topik, aktif: topik.id == activeId),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        if (onBack != null) ...[
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gray200, width: 2),
              ),
              child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.gray500),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerTitle,
                style: AppFonts.nunito(size: 24, weight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                headerSubtitle,
                style: AppFonts.nunito(size: 13, weight: FontWeight.w700, color: AppColors.gray500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kembaliCard() {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.gray200, width: 2),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Symbols.arrow_back, size: 20, color: AppColors.gray500),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kembali', style: AppFonts.nunito(size: 17, weight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    'Bali menyang topik sadurunge (ora ngganti topik).',
                    style: AppFonts.nunito(size: 12, weight: FontWeight.w700, color: AppColors.gray500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topikCard(Topik topik, {required bool aktif}) {
    final statusColor = topik.selesai
        ? const Color(0xFF059669)
        : (topik.berjalan ? AppColors.brand600 : AppColors.gray500);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gray200, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BAGIAN ${topik.urutan}',
                      style: AppFonts.nunito(
                        size: 11,
                        weight: FontWeight.w900,
                        color: AppColors.brand600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topik.nama,
                      style: AppFonts.nunito(size: 22, weight: FontWeight.w900, height: 1.15),
                    ),
                    if ((topik.deskripsi ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        topik.deskripsi!,
                        style: AppFonts.nunito(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.gray500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (aktif) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brand600,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'AKTIF',
                    style: AppFonts.nunito(
                      size: 10,
                      weight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${topik.totalUnit} Unit · ${topik.lulusCount}/${topik.totalSoal} soal',
                style: AppFonts.nunito(size: 12, weight: FontWeight.w700, color: AppColors.gray500),
              ),
              Text(
                '${topik.persen}%',
                style: AppFonts.nunito(size: 12, weight: FontWeight.w900, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: AppColors.gray100,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (topik.persen / 100).clamp(0.0, 1.0),
                  child: Container(color: const Color(0xFF10B981)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onSelect == null ? null : () => onSelect!(topik),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: aktif ? AppColors.brand600 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: aktif ? AppColors.brand600 : const Color(0xFFD5CCFC),
                  width: 2,
                ),
                boxShadow: aktif ? AppShadows.primary(0.30) : null,
              ),
              child: Center(
                child: Text(
                  aktif ? 'Lanjutkan' : 'Pilih Topik Iki',
                  style: AppFonts.nunito(
                    size: 14,
                    weight: FontWeight.w900,
                    color: aktif ? Colors.white : AppColors.brand600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gray200, width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Center(
        child: Text(
          'Belum ana topik. Hubungi guru utawa admin.',
          textAlign: TextAlign.center,
          style: AppFonts.nunito(size: 14, weight: FontWeight.w800, color: AppColors.gray500),
        ),
      ),
    );
  }
}

/// Layar penuh untuk memilih topik. Mengembalikan [Topik] yang dipilih,
/// atau `null` bila siswa kembali tanpa memilih.
class TopikPickerScreen extends StatelessWidget {
  const TopikPickerScreen({super.key, required this.topiks, this.activeId});

  final List<Topik> topiks;
  final int? activeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        bottom: false,
        child: TopikListContent(
          topiks: topiks,
          activeId: activeId,
          onSelect: (topik) => Navigator.of(context).pop(topik),
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
