import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/lang.dart';
import '../i18n/i18n.dart';
import '../theme/app_colors.dart';

/// "Tilni tanlang" oynasi (bayroqlar bilan). Tanlansa ilova darhol shu tilga o'tadi.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<AppLang>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (ctx) => _LangSheet(current: ref.read(langProvider)),
  );
  if (picked != null && picked != ref.read(langProvider)) await ref.read(langProvider.notifier).set(picked);
}

class _LangSheet extends StatelessWidget {
  const _LangSheet({required this.current});
  final AppLang current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(tr('Tilni tanlang'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (final l in AppLang.values)
        Semantics(
          selected: l == current,
          button: true,
          child: Material(
            color: l == current ? c.primaryLight : Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(children: [
                  FlagIcon(l),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      l.label,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: l == current ? FontWeight.w800 : FontWeight.w600,
                        color: l == current ? c.primary : c.text,
                      ),
                    ),
                  ),
                  if (l == current) Icon(Icons.check_circle_rounded, color: c.primary, size: 26),
                ]),
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
    ]);
  }
}

/// Dumaloq bayroq (rasm faylsiz, chizib olinadi — internet va shriftga bog'liq emas).
class FlagIcon extends StatelessWidget {
  const FlagIcon(this.lang, {super.key, this.size = 40});
  final AppLang lang;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.c.border),
        ),
        child: ClipOval(child: CustomPaint(painter: _FlagPainter(lang))),
      );
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.lang);
  final AppLang lang;

  void _bands(Canvas canvas, Size s, List<(Color, double)> bands) {
    var y = 0.0;
    for (final (color, h) in bands) {
      canvas.drawRect(Rect.fromLTWH(0, y, s.width, s.height * h), Paint()..color = color);
      y += s.height * h;
    }
  }

  void _crescent(Canvas canvas, Size s, Color bg) {
    final r = s.height * 0.11;
    final o = Offset(s.width * 0.3, s.height * 0.17);
    canvas.drawCircle(o, r, Paint()..color = Colors.white);
    canvas.drawCircle(o + Offset(r * 0.38, 0), r * 0.85, Paint()..color = bg);
  }

  @override
  void paint(Canvas canvas, Size s) {
    switch (lang) {
      case AppLang.uz || AppLang.uzCyrl:
        const blue = Color(0xFF0099B5);
        _bands(canvas, s, [(blue, 0.32), (const Color(0xFFCE1126), 0.03), (Colors.white, 0.30), (const Color(0xFFCE1126), 0.03), (const Color(0xFF1EB53A), 0.32)]);
        _crescent(canvas, s, blue);
      case AppLang.kaa:
        const blue = Color(0xFF0072CE);
        _bands(canvas, s, [(blue, 0.32), (Colors.white, 0.03), (const Color(0xFFFFD100), 0.30), (Colors.white, 0.03), (const Color(0xFF009A44), 0.32)]);
        _crescent(canvas, s, blue);
      case AppLang.ru:
        _bands(canvas, s, [(Colors.white, 1 / 3), (const Color(0xFF0039A6), 1 / 3), (const Color(0xFFD52B1E), 1 / 3)]);
      case AppLang.en:
        const blue = Color(0xFF012169), red = Color(0xFFC8102E);
        canvas.drawRect(Offset.zero & s, Paint()..color = blue);
        final w = s.width, h = s.height;
        void line(Offset a, Offset b, Color c, double t) => canvas.drawLine(a, b, Paint()
          ..color = c
          ..strokeWidth = t);
        line(Offset.zero, Offset(w, h), Colors.white, h * 0.2);
        line(Offset(w, 0), Offset(0, h), Colors.white, h * 0.2);
        line(Offset.zero, Offset(w, h), red, h * 0.07);
        line(Offset(w, 0), Offset(0, h), red, h * 0.07);
        line(Offset(w / 2, 0), Offset(w / 2, h), Colors.white, h * 0.32);
        line(Offset(0, h / 2), Offset(w, h / 2), Colors.white, h * 0.32);
        line(Offset(w / 2, 0), Offset(w / 2, h), red, h * 0.18);
        line(Offset(0, h / 2), Offset(w, h / 2), red, h * 0.18);
    }
    // Yengil yaltiroq — bayroq tekis ko'rinmasin
    canvas.drawCircle(
      Offset(s.width / 2, s.height / 2),
      s.width / 2,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
          stops: const [0, 0.7],
          transform: const GradientRotation(math.pi / 8),
        ).createShader(Offset.zero & s),
    );
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.lang != lang;
}
