import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/entities.dart';

/// Header'dagi ob-havo effekti (TZ S01): bir vaqtda faqat bittasi.
enum SkyScene { clear, clouds, rain, snow, fog }

/// WMO kodi → sahna. Momaqaldiroq yomg'ir sifatida (chaqmoq chaqnashi yo'q — fotosensitivlik).
SkyScene sceneFor(int code) {
  if (code == 45 || code == 48) return SkyScene.fog;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return SkyScene.snow;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95) return SkyScene.rain;
  if (code == 2 || code == 3) return SkyScene.clouds;
  return SkyScene.clear;
}

/// Bog' manzarasi (litsenziyasiz, kod bilan chiziladi — rasm yuklanmasa ham bo'sh joy qolmaydi)
/// va ob-havo effekti. Animatsiya: ilova fonga o'tganda yoki ekran ko'rinmaganda to'xtaydi,
/// "harakatni kamaytirish" yoqilgan bo'lsa statik kadr.
class LandscapeBackdrop extends StatefulWidget {
  const LandscapeBackdrop({super.key, required this.weather});
  final Weather? weather;

  @override
  State<LandscapeBackdrop> createState() => _LandscapeBackdropState();
}

class _LandscapeBackdropState extends State<LandscapeBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  late final AppLifecycleListener _life;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: (s) {
      _foreground = s == AppLifecycleState.resumed;
      _sync();
    });
  }

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _sync() {
    if (!mounted) return;
    final run = _foreground && !_reduce && widget.weather != null;
    if (run && !_ctl.isAnimating) {
      _ctl.repeat();
    } else if (!run && _ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LandscapeBackdrop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _life.dispose();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    final hour = DateTime.now().hour;
    final night = w != null ? !w.isDay : (hour < 6 || hour >= 19);
    final scene = w == null ? SkyScene.clear : sceneFor(w.code);
    // Statik kadr uchun t = 0.3 (bulut/tomchilar kadr ichida ko'rinadi)
    final anim = _reduce ? const AlwaysStoppedAnimation<double>(0.3) : _ctl;
    return ExcludeSemantics(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _SkyPainter(anim, scene, night, effects: w != null)),
        RepaintBoundary(child: CustomPaint(painter: _LandPainter(night, scene))),
        if (w != null && (scene == SkyScene.rain || scene == SkyScene.snow || scene == SkyScene.fog))
          CustomPaint(painter: _PrecipPainter(anim, scene, night)),
      ]),
    );
  }
}

// ---------- Osmon: gradient, quyosh yoki oy+yulduzlar, bulutlar ----------
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t, this.scene, this.night, {required this.effects}) : super(repaint: t);
  final Animation<double> t;
  final SkyScene scene;
  final bool night, effects;

  @override
  void paint(Canvas canvas, Size s) {
    final colors = night
        ? (scene == SkyScene.clear ? const [Color(0xFF0E1A2B), Color(0xFF2E3A58)] : const [Color(0xFF1A2230), Color(0xFF3A4252)])
        : switch (scene) {
            SkyScene.clear => const [Color(0xFFF7E9C9), Color(0xFFF2C487)],
            SkyScene.clouds => const [Color(0xFFE9E5D8), Color(0xFFE2D3B4)],
            SkyScene.rain => const [Color(0xFFC9CDC6), Color(0xFFB9BDB2)],
            SkyScene.snow => const [Color(0xFFE6E9EC), Color(0xFFD6DCE0)],
            SkyScene.fog => const [Color(0xFFE7E4DB), Color(0xFFDAD6CB)],
          };
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(rect));
    final v = t.value;
    final celestial = Offset(s.width * 0.72, s.height * 0.70);
    if (night) {
      _moon(canvas, celestial, s);
      if (scene == SkyScene.clear) _stars(canvas, s, effects ? v : 0.3);
    } else if (scene == SkyScene.clear || scene == SkyScene.clouds) {
      // Quyosh nuri — sekin "jilva" (faqat ochiq osmonda)
      final pulse = scene == SkyScene.clear && effects ? 0.5 + 0.5 * math.sin(v * 2 * math.pi * 8) : 0.5;
      final r = s.height * (0.22 + 0.03 * pulse);
      canvas.drawCircle(
          celestial,
          r * 2.2,
          Paint()
            ..shader = RadialGradient(colors: [const Color(0xFFFFE6A8).withValues(alpha: 0.75), const Color(0x00FFE6A8)])
                .createShader(Rect.fromCircle(center: celestial, radius: r * 2.2)));
      canvas.drawCircle(celestial, s.height * 0.085, Paint()..color = const Color(0xFFFFF4D6));
    }
    if (scene == SkyScene.clouds || scene == SkyScene.rain || scene == SkyScene.snow) {
      final cloud = night ? const Color(0xFF59627A) : (scene == SkyScene.clouds ? const Color(0xFFFFFFFF) : const Color(0xFFE9ECEA));
      final drift = scene == SkyScene.clouds && effects ? v : 0.3;
      for (final (x0, y, k, sp) in const [(0.05, 0.42, 1.0, 1.0), (0.45, 0.30, 0.8, 2.0), (0.8, 0.48, 1.2, 1.0)]) {
        final span = s.width + 240;
        final x = ((x0 * span + drift * sp * span) % span) - 120;
        _cloud(canvas, Offset(x, s.height * y), s.height * 0.07 * k, cloud.withValues(alpha: 0.85));
      }
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 5.2, height: r * 1.6), p);
    canvas.drawCircle(c.translate(-r * 0.9, -r * 0.35), r * 0.9, p);
    canvas.drawCircle(c.translate(r * 0.4, -r * 0.6), r * 1.15, p);
  }

  void _moon(Canvas canvas, Offset c, Size s) {
    final r = s.height * 0.07;
    canvas.drawCircle(c, r * 3, Paint()..shader = RadialGradient(colors: [const Color(0x55F3EEDD), const Color(0x00F3EEDD)]).createShader(Rect.fromCircle(center: c, radius: r * 3)));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c.translate(r * 0.45, -r * 0.25), radius: r * 0.9)),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF3EEDD));
  }

  void _stars(Canvas canvas, Size s, double v) {
    final rnd = math.Random(11);
    for (var i = 0; i < 9; i++) {
      final p = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * 0.5);
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin((v * 10 + i / 9) * 2 * math.pi));
      canvas.drawCircle(p, 1.2 + rnd.nextDouble(), Paint()..color = Color.fromRGBO(243, 238, 221, tw));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter o) => o.scene != scene || o.night != night || o.effects != effects || o.t != t;
}

// ---------- Tepaliklar va olma bog'i (statik) ----------
class _LandPainter extends CustomPainter {
  _LandPainter(this.night, this.scene);
  final bool night;
  final SkyScene scene;

  Color _c(int day, int nightC) => Color(night ? nightC : day);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Uzoq tog'lar
    final far = Path()..moveTo(0, h * 0.70);
    for (var x = 0.0; x <= w; x += w / 12) {
      far.lineTo(x, h * (0.62 + 0.07 * math.sin(x / w * math.pi * 2.3 + 0.6)) - (x > w * 0.35 && x < w * 0.75 ? h * 0.08 * math.sin((x - w * 0.35) / (w * 0.4) * math.pi) : 0));
    }
    far
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = _c(0xFFB3A58A, 0xFF27324A));
    // Yaqin tepalik
    final mid = Path()..moveTo(0, h * 0.78);
    mid.cubicTo(w * 0.25, h * 0.70, w * 0.55, h * 0.80, w, h * 0.72);
    mid
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(mid, Paint()..color = _c(0xFF9AA868, 0xFF25352A));
    // Maysa
    final ground = Path()..moveTo(0, h * 0.86);
    ground.quadraticBezierTo(w * 0.5, h * 0.80, w, h * 0.84);
    ground
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = _c(0xFF6F8A3A, 0xFF1D2B1F));

    // Daraxt qatorlari: orqadan oldinga, kattalashib boradi
    final rnd = math.Random(7);
    final rows = [(0.80, 0.022, 0.7), (0.86, 0.034, 0.85), (0.95, 0.055, 1.0)];
    final apples = scene != SkyScene.snow;
    for (final (y, r, shade) in rows) {
      final step = h * r * 2.6;
      for (var x = -step * rnd.nextDouble(); x < w + step; x += step * (0.85 + rnd.nextDouble() * 0.3)) {
        // Markaziy qismda (quyosh ostida) oldingi qator siyrak — manzara ochiq ko'rinsin
        if (shade == 1.0 && x > w * 0.28 && x < w * 0.62) continue;
        _tree(canvas, Offset(x, h * y), h * r, shade, rnd, apples);
      }
    }
  }

  void _tree(Canvas canvas, Offset base, double r, double shade, math.Random rnd, bool apples) {
    canvas.drawRect(Rect.fromCenter(center: base.translate(0, -r * 0.4), width: r * 0.22, height: r * 0.9), Paint()..color = _c(0xFF5B4630, 0xFF1B1712));
    final crown = base.translate(0, -r * 1.25);
    final leaf = Color.lerp(_c(0xFF7F9A3E, 0xFF2C3F27), _c(0xFF4E6B27, 0xFF1F2E1C), shade)!;
    final p = Paint()..color = leaf;
    canvas.drawCircle(crown, r, p);
    canvas.drawCircle(crown.translate(-r * 0.6, r * 0.2), r * 0.7, p);
    canvas.drawCircle(crown.translate(r * 0.6, r * 0.2), r * 0.7, p);
    canvas.drawCircle(crown.translate(-r * 0.3, -r * 0.35), r * 0.55, Paint()..color = Color.lerp(leaf, Colors.white, night ? 0.04 : 0.12)!);
    if (!apples || r < 4) return;
    final fruit = Paint()..color = _c(0xFFC8442B, 0xFF6E2A1E);
    for (var i = 0; i < 5; i++) {
      final a = rnd.nextDouble() * math.pi * 2, d = rnd.nextDouble() * r * 0.85;
      canvas.drawCircle(crown.translate(math.cos(a) * d, math.sin(a) * d * 0.8), r * 0.13, fruit);
    }
  }

  @override
  bool shouldRepaint(covariant _LandPainter o) => o.night != night || o.scene != scene;
}

// ---------- Yomg'ir, qor, tuman: faqat header ichida ----------
class _PrecipPainter extends CustomPainter {
  _PrecipPainter(this.t, this.scene, this.night) : super(repaint: t);
  final Animation<double> t;
  final SkyScene scene;
  final bool night;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Offset.zero & s);
    final v = t.value;
    final rnd = math.Random(3);
    switch (scene) {
      case SkyScene.rain:
        final p = Paint()
          ..color = (night ? const Color(0xFFA9C8EC) : const Color(0xFF5E6E7A)).withValues(alpha: 0.45)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        final n = (s.width / 9).clamp(30, 140).toInt();
        for (var i = 0; i < n; i++) {
          final x0 = rnd.nextDouble() * (s.width + 40);
          final speed = 45 + rnd.nextInt(16); // butun son — sikl chegarasida sakrash bo'lmaydi
          final y = ((rnd.nextDouble() + v * speed) % 1.0) * (s.height + 30) - 20;
          final x = x0 - y * 0.18;
          canvas.drawLine(Offset(x, y), Offset(x - 3, y + 14), p);
        }
      case SkyScene.snow:
        final p = Paint()..color = (night ? const Color(0xFFE8ECF0) : const Color(0xFFFFFFFF)).withValues(alpha: 0.9);
        final n = (s.width / 12).clamp(24, 110).toInt();
        for (var i = 0; i < n; i++) {
          final x0 = rnd.nextDouble() * s.width;
          final speed = 8 + rnd.nextInt(8);
          final y = ((rnd.nextDouble() + v * speed) % 1.0) * (s.height + 10) - 5;
          final x = x0 + math.sin((v * speed + i) * 2 * math.pi) * 6;
          canvas.drawCircle(Offset(x, y), 1.4 + rnd.nextDouble() * 1.8, p);
        }
      case SkyScene.fog:
        for (var i = 0; i < 3; i++) {
          final y = s.height * (0.55 + i * 0.13);
          final dx = math.sin((v + i / 3) * 2 * math.pi) * s.width * 0.08;
          canvas.drawRect(
            Rect.fromLTWH(-s.width * 0.2 + dx, y - s.height * 0.06, s.width * 1.4, s.height * 0.12),
            Paint()
              ..color = (night ? const Color(0xFF9DA391) : const Color(0xFFF4F1EA)).withValues(alpha: 0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
          );
        }
      case SkyScene.clear || SkyScene.clouds:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PrecipPainter o) => o.scene != scene || o.night != night || o.t != t;
}
