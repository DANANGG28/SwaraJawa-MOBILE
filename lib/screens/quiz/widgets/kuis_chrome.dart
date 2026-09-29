import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class KuisHeader extends StatelessWidget {
  const KuisHeader({
    super.key,
    required this.nomor,
    required this.total,
    required this.onClose,
    required this.muted,
    required this.onToggleSound,
    this.trailing,
  });

  final int nomor;
  final int total;
  final VoidCallback onClose;
  final bool muted;
  final VoidCallback onToggleSound;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final persen = total > 0 ? (nomor / total) : 0.0;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        border: Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Symbols.close, size: 26, color: AppColors.gray500),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 14,
                            color: AppColors.surfaceContainerHigh,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: persen.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary600, AppColors.primary400],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$nomor/$total',
                        style: AppFonts.manrope(
                          size: 12,
                          weight: FontWeight.w700,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (trailing != null) trailing!,
                GestureDetector(
                  onTap: onToggleSound,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      muted ? Symbols.volume_off : Symbols.volume_up,
                      size: 24,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
