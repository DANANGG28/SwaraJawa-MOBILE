import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../models/soal.dart';

class SusunView extends StatefulWidget {
  const SusunView({
    super.key,
    required this.soal,
    required this.result,
    required this.onChanged,
    this.puzzle = false,
    this.onTts,
  });

  final Soal soal;
  final dynamic result;
  final ValueChanged<dynamic> onChanged;
  final bool puzzle;
  final VoidCallback? onTts;

  @override
  State<SusunView> createState() => _SusunViewState();
}

class _SusunViewState extends State<SusunView> {
  late List<_Token> _tokens;
  final List<int> _placed = [];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant SusunView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.soal.id != widget.soal.id) _reset();
  }

  void _reset() {
    final words = widget.soal.opsiKata;
    _tokens = [
      for (var i = 0; i < words.length; i++) _Token(uid: i, word: words[i]),
    ];
    _placed.clear();
  }

  void _place(int uid) {
    if (widget.result != null) return;
    setState(() {
      if (_placed.contains(uid)) {
        _placed.remove(uid);
      } else {
        _placed.add(uid);
      }
    });
    if (_placed.isEmpty) {
      widget.onChanged(null);
    } else {
      widget.onChanged([
        for (final uid in _placed) _tokens.firstWhere((t) => t.uid == uid).word,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placedTokens = _placed.map((uid) => _tokens.firstWhere((t) => t.uid == uid)).toList();
    final bankTokens = _tokens.where((t) => !_placed.contains(t.uid)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.puzzle ? Symbols.checkroom : Symbols.segment, size: 18, color: AppColors.primary700),
              const SizedBox(width: 6),
              Text(
                (widget.puzzle ? 'Puzzle Pakaian Adat' : 'Susun Ukara').toUpperCase(),
                style: AppFonts.manrope(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.primary700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.soal.pertanyaan,
          style: AppFonts.epilogue(size: 22, weight: FontWeight.w800, height: 1.3),
        ),
        if (!widget.puzzle) ...[
          const SizedBox(height: 14),
          _ttsCard(),
        ],
        const SizedBox(height: 22),
        Column(
          children: [
            if (placedTokens.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pencet tembung ing ngisor iki kanggo nyusun ukara...',
                    style: AppFonts.manrope(size: 15, color: AppColors.gray400),
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.gray200, width: 2),
                  bottom: BorderSide(color: AppColors.gray200, width: 2),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in placedTokens) _chip(t, inZona: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in bankTokens) _chip(t, inZona: false),
          ],
        ),
      ],
    );
  }

  Widget _chip(_Token t, {required bool inZona}) {
    return GestureDetector(
      onTap: () => _place(t.uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: inZona ? AppColors.primaryFixed.withValues(alpha: 0.4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inZona ? AppColors.primary600 : AppColors.gray200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: inZona ? AppColors.primary700 : AppColors.gray200,
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          t.word,
          style: AppFonts.manrope(size: 16, weight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _ttsCard() {
    return GestureDetector(
      onTap: widget.onTts,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
          ],
        ),
        child: Row(
          children: [
            const Icon(Symbols.volume_up, size: 28, color: AppColors.primary600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.soal.pertanyaan,
                    style: AppFonts.epilogue(size: 17, weight: FontWeight.w800, color: AppColors.primary600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 0,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.primary400, width: 3)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Token {
  const _Token({required this.uid, required this.word});

  final int uid;
  final String word;
}
