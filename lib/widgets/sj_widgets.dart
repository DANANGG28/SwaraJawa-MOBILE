import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/app_shadows.dart';

/// Kartu putih dengan sudut membulat + shadow 3D, selaras `sj-card` web.
class SjCard extends StatelessWidget {
  const SjCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.color = AppColors.surfaceContainerLowest,
    this.borderColor = AppColors.gray200,
    this.borderWidth = 2,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
        boxShadow: shadow ? AppShadows.card : null,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Tombol pill "Duolingo style" — border bawah tebal & turun saat ditekan.
class SjButton extends StatefulWidget {
  const SjButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.primary600,
    this.foregroundColor = Colors.white,
    this.radius = 16,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.fontSize = 14,
    this.fontWeight = FontWeight.w800,
    this.upper = false,
    this.borderColor,
    this.borderWidth = 0,
    this.expand = true,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double radius;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FontWeight fontWeight;
  final bool upper;
  final Color? borderColor;
  final double borderWidth;
  final bool expand;
  final bool enabled;
  final bool loading;

  @override
  State<SjButton> createState() => _SjButtonState();
}

class _SjButtonState extends State<SjButton> {
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isEnabled ? widget.backgroundColor : widget.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.borderColor ?? Colors.transparent, width: widget.borderWidth),
        boxShadow: _pressed || !_isEnabled
            ? null
            : [
                BoxShadow(
                  color: _darker(widget.backgroundColor),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          else ...[
            if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.fontSize + 5, color: widget.foregroundColor),
              const SizedBox(width: 8),
            ],
            Text(
              widget.upper ? widget.label.toUpperCase() : widget.label,
              style: AppFonts.epilogue(
                size: widget.fontSize,
                weight: widget.fontWeight,
                color: widget.foregroundColor,
                letterSpacing: widget.upper ? 0.6 : 0,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      child: GestureDetector(
        onTapDown: _isEnabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _isEnabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _isEnabled ? () => setState(() => _pressed = false) : null,
        onTap: _isEnabled ? widget.onPressed : null,
        child: content,
      ),
    );
  }

  Color _darker(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }
}

/// Bar progres membulat.
class SjProgressBar extends StatelessWidget {
  const SjProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary600,
    this.trackColor = AppColors.gray200,
    this.height = 12,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: trackColor,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color),
        ),
      ),
    );
  }
}

/// Label kecil uppercase (text-label-upper).
class SjLabelUpper extends StatelessWidget {
  const SjLabelUpper(
    this.text, {
    super.key,
    this.color = AppColors.gray500,
    this.size = 11,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = 0.5,
    this.nunito = false,
  });

  final String text;
  final Color color;
  final double size;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool nunito;

  @override
  Widget build(BuildContext context) {
    final style = nunito
        ? AppFonts.nunito(
            size: size,
            weight: fontWeight,
            color: color,
            letterSpacing: letterSpacing,
          )
        : AppFonts.manrope(
            size: size,
            weight: fontWeight,
            color: color,
            letterSpacing: letterSpacing,
          );
    return Text(text.toUpperCase(), style: style);
  }
}
