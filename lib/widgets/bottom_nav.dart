import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/app_shadows.dart';

class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class SjBottomNav extends StatelessWidget {
  const SjBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = const [
      BottomNavItem(icon: Symbols.home, label: 'Beranda'),
      BottomNavItem(icon: Symbols.award_star, label: 'Papan Peringkat'),
      BottomNavItem(icon: Symbols.mic, label: 'Latihan Ngomong'),
      BottomNavItem(icon: Symbols.smart_toy, label: 'Tanya Bahasa AI'),
      BottomNavItem(icon: Symbols.settings, label: 'Pengaturan Profil'),
    ],
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: AppColors.gray200, width: 2)),
        boxShadow: AppShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavTile(
                  item: items[i],
                  active: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({required this.item, required this.active, required this.onTap});

  final BottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(
            0,
            widget.active ? -4 : (_pressed ? 2 : 0),
            0,
          ),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.active ? AppColors.primary600 : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.active ? AppShadows.primary(0.30) : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(
                widget.item.icon,
                size: 24,
                color: widget.active ? Colors.white : AppColors.gray500,
              ),
              if (widget.active)
                Positioned(
                  bottom: -8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header aplikasi (dipakai tab Beranda dsb).
class SjMobileHeader extends StatelessWidget {
  const SjMobileHeader({super.key, this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: AppColors.gray200, width: 2)),
        boxShadow: AppShadows.header,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary600,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.primary(0.30),
            ),
            child: const Icon(Symbols.bolt, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SINAU JOWO',
                style: AppFonts.nunito(
                  size: 16,
                  weight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'PLATFORM PASINAON',
                style: AppFonts.nunito(
                  size: 9,
                  weight: FontWeight.w800,
                  color: AppColors.primary600,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
