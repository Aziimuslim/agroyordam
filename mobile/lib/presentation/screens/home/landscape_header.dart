import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// Jonli bog' manzarasi — Tabiiy Agro dizayni: haqiqiy bog' surati ([orchardAsset]) ustida harakat.
/// Surat keng joyda (eni balandligidan ≥1,6 marta) ishlatiladi; tor joyda yoki surat/shader
/// yuklanmaguncha kod bilan chizilgan manzara ko'rinadi — bo'sh joy qolmaydi.
///
/// Harakat: daraxtlar shamolda tebranadi (surat to'r ustida egiladi), bulutlar suzadi, kunduzi qushlar uchadi va quyosh
/// nurlari aylanadi; tunda yulduzlar miltillaydi, ba'zan yulduz uchadi, bog'da yaltiroq qo'ng'izlar;
/// yomg'ir (tomchi + sachrash), qor yoki tuman — ob-havoga qarab.
/// Ilova fonga o'tganda to'xtaydi, "harakatni kamaytirish" yoqilgan bo'lsa statik kadr.
///
/// [skyTop] — manzaraning ko'rinadigan qismi boshlanadigan joy (px). Undan yuqorisi [topColor]
/// bilan to'ldiriladi (matn ostida kontrast), harakatlanuvchi narsalar faqat pastda.
class LandscapeBackdrop extends StatefulWidget {
  const LandscapeBackdrop({super.key, required this.weather, this.skyTop = 0, this.topColor});
  final Weather? weather;
  final double skyTop;
  final Color? topColor;

  @override
  State<LandscapeBackdrop> createState() => _LandscapeBackdropState();
}

class _LandscapeBackdropState extends State<LandscapeBackdrop> with SingleTickerProviderStateMixin {
  // Barcha harakatlar shu siklga butun marta sig'adi — sikl chegarasida sakrash bo'lmaydi
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  late final AppLifecycleListener _life;
  final _trees = _TreeCache();
  bool _foreground = true;
  ui.Image? _photo;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() => _photo = info.image);
  }, onError: (_, __) {});

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
    // Ob-havosiz (kirish ekrani) — statik kadr
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
    final stream = const AssetImage(orchardAsset).resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void didUpdateWidget(covariant LandscapeBackdrop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _life.dispose();
    _ctl.dispose();
    _trees.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    final hour = DateTime.now().hour;
    final night = w != null ? !w.isDay : (hour < 6 || hour >= 19);
    final scene = w == null ? SkyScene.clear : sceneFor(w.code);
    final warm = w == null || w.temperature >= 14;
    // Statik kadr: bulut, qush va tomchilar kadr ichida ko'rinadigan lahza
    final anim = _reduce ? const AlwaysStoppedAnimation<double>(0.27) : _ctl;
    final cfg = _Cfg(scene: scene, night: night, warm: warm, skyTop: widget.skyTop, topColor: widget.topColor);
    final photo = _photo;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(builder: (context, box) {
          final bandH = box.maxHeight - widget.skyTop;
          final wide = box.maxWidth.isFinite && bandH > 0 && box.maxWidth / bandH >= 1.6;
          final painter = photo != null && wide
              ? _PhotoPainter(anim, cfg, _trees, photo)
              : _ScenePainter(anim, cfg, _trees);
          return CustomPaint(painter: painter, size: Size.infinite);
        }),
      ),
    );
  }
}

class _Cfg {
  const _Cfg({required this.scene, required this.night, required this.warm, required this.skyTop, this.topColor});
  final SkyScene scene;
  final bool night, warm;
  final double skyTop;
  final Color? topColor;

  @override
  bool operator ==(Object o) =>
      o is _Cfg && o.scene == scene && o.night == night && o.warm == warm && o.skyTop == skyTop && o.topColor == topColor;
  @override
  int get hashCode => Object.hash(scene, night, warm, skyTop, topColor);
}

/// Daraxt qatorlari tayyor rasm (Picture) sifatida saqlanadi — har kadrda faqat egiladi.
class _TreeCache {
  Object? _key;
  List<_TreeLayer> layers = const [];
  ui.Picture? hills;

  void ensure(Size s, _Cfg cfg, double top) {
    final key = (s, cfg.night, cfg.scene, top);
    if (key == _key) return;
    dispose();
    _key = key;
    final band = Rect.fromLTRB(0, top, s.width, s.height);
    hills = _record((c) => _paintHills(c, band, cfg));
    layers = _buildTrees(band, cfg);
  }

  void dispose() {
    hills?.dispose();
    for (final l in layers) {
      l.picture.dispose();
    }
    hills = null;
    layers = const [];
    _key = null;
  }
}

class _TreeLayer {
  _TreeLayer(this.picture, this.baseY, this.height, this.phase, this.amp);
  final ui.Picture picture;
  final double baseY, height, phase, amp;
}

ui.Picture _record(void Function(Canvas) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  return rec.endRecording();
}

Color _pick(bool night, int day, int nightC) => Color(night ? nightC : day);

// ---------- Uzoq tog'lar, tepalik, maysa (statik) ----------
void _paintHills(Canvas canvas, Rect b, _Cfg cfg) {
  final w = b.width, top = b.top, h = b.height;
  double y(double f) => top + h * f;
  final snow = cfg.scene == SkyScene.snow;
  final far = Path()..moveTo(0, y(0.58));
  for (var x = 0.0; x <= w + 1; x += w / 24) {
    final f = x / w;
    final peak = f > 0.30 && f < 0.78 ? 0.16 * math.sin((f - 0.30) / 0.48 * math.pi) : 0.0;
    far.lineTo(x, y(0.56 + 0.05 * math.sin(f * math.pi * 3.1 + 0.6) - peak));
  }
  far
    ..lineTo(w, b.bottom)
    ..lineTo(0, b.bottom)
    ..close();
  canvas.drawPath(far, Paint()..color = _pick(cfg.night, snow ? 0xFFD9DCDD : 0xFFBFAE8E, snow ? 0xFF3A4458 : 0xFF2A3550));
  // Tog' cho'qqisidagi qor (qishda — kengroq)
  final cap = Path();
  for (var x = w * 0.42; x <= w * 0.66; x += w / 48) {
    final f = x / w;
    final yy = y(0.56 + 0.05 * math.sin(f * math.pi * 3.1 + 0.6) - 0.16 * math.sin((f - 0.30) / 0.48 * math.pi));
    x == w * 0.42 ? cap.moveTo(x, yy) : cap.lineTo(x, yy);
  }
  for (var x = w * 0.66; x >= w * 0.42; x -= w / 48) {
    final f = x / w;
    final yy = y(0.56 + 0.05 * math.sin(f * math.pi * 3.1 + 0.6) - 0.16 * math.sin((f - 0.30) / 0.48 * math.pi));
    cap.lineTo(x, yy + h * (snow ? 0.07 : 0.035) * (0.6 + 0.4 * math.sin(f * 40)));
  }
  cap.close();
  canvas.drawPath(cap, Paint()..color = Color(cfg.night ? 0xFF8C93A6 : 0xFFF6F3EA).withValues(alpha: 0.9));

  final mid = Path()..moveTo(0, y(0.70));
  mid.cubicTo(w * 0.25, y(0.62), w * 0.55, y(0.74), w, y(0.64));
  mid
    ..lineTo(w, b.bottom)
    ..lineTo(0, b.bottom)
    ..close();
  canvas.drawPath(mid, Paint()..color = _pick(cfg.night, snow ? 0xFFCBD1CC : 0xFF9AA868, snow ? 0xFF323C46 : 0xFF25352A));
  final ground = Path()..moveTo(0, y(0.84));
  ground.quadraticBezierTo(w * 0.5, y(0.77), w, y(0.82));
  ground
    ..lineTo(w, b.bottom + 2)
    ..lineTo(0, b.bottom + 2)
    ..close();
  canvas.drawPath(ground, Paint()..color = _pick(cfg.night, snow ? 0xFFE9ECEA : 0xFF6F8A3A, snow ? 0xFF3B4550 : 0xFF1D2B1F));
}

// ---------- Olma bog'i: 3 qator, har biri 2 qatlam (har xil fazada tebranadi) ----------
List<_TreeLayer> _buildTrees(Rect b, _Cfg cfg) {
  final rnd = math.Random(7);
  final out = <_TreeLayer>[];
  final rows = [(0.72, 0.034, 0.7), (0.84, 0.050, 0.85), (0.99, 0.078, 1.0)];
  for (final (fy, fr, shade) in rows) {
    final baseY = b.top + b.height * fy;
    final r = math.max(3.0, b.height * fr);
    final step = r * 2.5;
    final recA = ui.PictureRecorder(), recB = ui.PictureRecorder();
    final ca = Canvas(recA), cb = Canvas(recB);
    var i = 0;
    for (var x = -step * rnd.nextDouble(); x < b.width + step; x += step * (0.85 + rnd.nextDouble() * 0.3)) {
      final cv = (i++).isEven ? ca : cb;
      _tree(cv, Offset(x, baseY), r * (0.9 + rnd.nextDouble() * 0.2), shade, rnd, cfg);
    }
    final amp = 0.022 + 0.012 * shade; // oldingi qator ko'proq tebranadi
    out
      ..add(_TreeLayer(recA.endRecording(), baseY, r * 2.3, rnd.nextDouble(), amp))
      ..add(_TreeLayer(recB.endRecording(), baseY, r * 2.3, rnd.nextDouble(), amp * 0.85));
  }
  return out;
}

void _tree(Canvas canvas, Offset base, double r, double shade, math.Random rnd, _Cfg cfg) {
  final night = cfg.night, snow = cfg.scene == SkyScene.snow;
  canvas.drawRect(Rect.fromCenter(center: base.translate(0, -r * 0.4), width: r * 0.22, height: r * 0.9), Paint()..color = _pick(night, 0xFF5B4630, 0xFF1B1712));
  final crown = base.translate(0, -r * 1.25);
  final leaf = Color.lerp(_pick(night, 0xFF7F9A3E, 0xFF2C3F27), _pick(night, 0xFF4E6B27, 0xFF1F2E1C), shade)!;
  final p = Paint()..color = leaf;
  canvas.drawCircle(crown, r, p);
  canvas.drawCircle(crown.translate(-r * 0.6, r * 0.2), r * 0.7, p);
  canvas.drawCircle(crown.translate(r * 0.6, r * 0.2), r * 0.7, p);
  canvas.drawCircle(crown.translate(-r * 0.3, -r * 0.35), r * 0.55, Paint()..color = Color.lerp(leaf, Colors.white, night ? 0.04 : 0.12)!);
  if (snow) {
    // Qor qalpoqchasi
    final cap = Paint()..color = Color(night ? 0xFFB9C0CC : 0xFFFFFFFF).withValues(alpha: 0.92);
    canvas.drawOval(Rect.fromCenter(center: crown.translate(0, -r * 0.72), width: r * 1.3, height: r * 0.45), cap);
    canvas.drawOval(Rect.fromCenter(center: crown.translate(-r * 0.75, -r * 0.2), width: r * 0.7, height: r * 0.28), cap);
    return;
  }
  if (r < 4) return;
  final fruit = Paint()..color = _pick(night, 0xFFC8442B, 0xFF6E2A1E);
  for (var i = 0; i < 5; i++) {
    final a = rnd.nextDouble() * math.pi * 2, d = rnd.nextDouble() * r * 0.85;
    canvas.drawCircle(crown.translate(math.cos(a) * d, math.sin(a) * d * 0.8), r * 0.13, fruit);
  }
}

// ---------- Butun sahna: osmon → tog'lar → daraxtlar → effektlar ----------
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t, this.cfg, this.cache) : super(repaint: t);
  final Animation<double> t;
  final _Cfg cfg;
  final _TreeCache cache;

  static const _tau = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final top = cfg.skyTop.clamp(0.0, s.height * 0.7);
    final band = Rect.fromLTRB(0, top, s.width, s.height);
    final v = t.value;
    canvas.clipRect(Offset.zero & s);
    _sky(canvas, s, band);
    _celestial(canvas, band, v);
    _clouds(canvas, band, v);
    if (!cfg.night && (cfg.scene == SkyScene.clear || cfg.scene == SkyScene.clouds)) _birds(canvas, band, v);

    cache.ensure(s, cfg, top);
    canvas.drawPicture(cache.hills!);
    // Shamol: yomg'ir/qorda kuchliroq; o'zgaruvchan "shamol esishi" (gust)
    final wind = switch (cfg.scene) { SkyScene.rain => 1.8, SkyScene.snow => 1.2, SkyScene.fog => 0.5, _ => 1.0 };
    final gust = 0.65 + 0.35 * math.sin(v * _tau * 3);
    for (final l in cache.layers) {
      final k = l.amp * wind * gust * math.sin((v * 20 + l.phase) * _tau);
      canvas.save();
      canvas.translate(0, l.baseY);
      canvas.transform(Float64List.fromList([1, 0, 0, 0, -k, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]));
      canvas.translate(0, -l.baseY);
      canvas.drawPicture(l.picture);
      canvas.restore();
    }

    if (cfg.night && cfg.scene == SkyScene.clear && cfg.warm) _fireflies(canvas, band, v);
    switch (cfg.scene) {
      case SkyScene.rain:
        _rain(canvas, band, v);
      case SkyScene.snow:
        _snow(canvas, band, v);
      case SkyScene.fog:
        _fog(canvas, band, v);
      case SkyScene.clear || SkyScene.clouds:
        break;
    }
  }

  // Osmon gradienti. topColor berilsa, skyTop'gacha shu rang, keyin osmonga silliq o'tadi.
  void _sky(Canvas canvas, Size s, Rect band) {
    final sky = cfg.night
        ? (cfg.scene == SkyScene.clear ? const [Color(0xFF14213A), Color(0xFF2B3A5E), Color(0xFF4A4F72)] : const [Color(0xFF1E2633), Color(0xFF353E50), Color(0xFF474E5E)])
        : switch (cfg.scene) {
            SkyScene.clear => const [Color(0xFFCFE3EE), Color(0xFFF3E6C8), Color(0xFFF2C487)],
            SkyScene.clouds => const [Color(0xFFDCE3E6), Color(0xFFE9E5D8), Color(0xFFE2D3B4)],
            SkyScene.rain => const [Color(0xFFB4BBBD), Color(0xFFC9CDC6), Color(0xFFB9BDB2)],
            SkyScene.snow => const [Color(0xFFD9E0E6), Color(0xFFE6E9EC), Color(0xFFD6DCE0)],
            SkyScene.fog => const [Color(0xFFDDDBD4), Color(0xFFE7E4DB), Color(0xFFDAD6CB)],
          };
    final rect = Offset.zero & s;
    final tc = cfg.topColor;
    final colors = <Color>[];
    final stops = <double>[];
    if (tc != null && band.top > 0) {
      final fadeA = ((band.top - 18) / s.height).clamp(0.0, 1.0), fadeB = ((band.top + 46) / s.height).clamp(0.0, 1.0);
      colors.addAll([tc, tc]);
      stops.addAll([0, fadeA]);
      // Yorug' fondan tungi osmonga to'g'ridan-to'g'ri o'tish kulrang "tuman" beradi — oraliq shafaq rangi
      if (cfg.night && tc.computeLuminance() > 0.5) {
        colors.add(const Color(0xFFB7A6B8));
        stops.add((fadeA + fadeB) / 2);
      }
      colors.addAll(sky);
      stops.addAll([fadeB, fadeB + (1 - fadeB) * 0.45, 1]);
    } else {
      colors.addAll(sky);
      stops.addAll([0, 0.55, 1]);
    }
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops).createShader(rect));
  }

  Offset _sunPos(Rect b) => Offset(b.width * 0.80, b.top + b.height * 0.30);

  void _celestial(Canvas canvas, Rect b, double v) {
    final c = _sunPos(b);
    final r = math.max(8.0, b.height * 0.085);
    if (cfg.night) {
      if (cfg.scene == SkyScene.clear) {
        _stars(canvas, b, v);
        _shootingStar(canvas, b, v);
      }
      if (cfg.scene != SkyScene.rain && cfg.scene != SkyScene.snow) _moon(canvas, c, r * 0.9, v);
      return;
    }
    if (cfg.scene != SkyScene.clear && cfg.scene != SkyScene.clouds) return;
    final pulse = 0.5 + 0.5 * math.sin(v * _tau * 6);
    final glowR = r * (3.2 + 0.25 * pulse);
    canvas.drawCircle(c, glowR, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFE6A8).withValues(alpha: 0.8), const Color(0x00FFE6A8)]).createShader(Rect.fromCircle(center: c, radius: glowR)));
    // Aylanuvchi nurlar
    if (cfg.scene == SkyScene.clear) {
      final ray = Paint()
        ..color = const Color(0xFFFFF1C9).withValues(alpha: 0.55)
        ..strokeWidth = math.max(1.5, r * 0.12)
        ..strokeCap = StrokeCap.round;
      final rot = v * _tau * 2;
      for (var i = 0; i < 12; i++) {
        final a = rot + i * _tau / 12;
        final len = i.isEven ? 0.55 : 0.35;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 1.35, c + Offset(math.cos(a), math.sin(a)) * r * (1.35 + len), ray);
      }
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFF4D6));
    canvas.drawCircle(c, r * 0.78, Paint()..color = const Color(0xFFFFE49A));
  }

  void _moon(Canvas canvas, Offset c, double r, double v) {
    final glow = 0.30 + 0.08 * math.sin(v * _tau * 4);
    canvas.drawCircle(c, r * 3.2, Paint()..shader = RadialGradient(colors: [const Color(0xFFF3EEDD).withValues(alpha: glow), const Color(0x00F3EEDD)]).createShader(Rect.fromCircle(center: c, radius: r * 3.2)));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(Rect.fromCircle(center: c.translate(r * 0.45, -r * 0.25), radius: r * 0.9)),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF3EEDD));
  }

  void _stars(Canvas canvas, Rect b, double v) {
    final rnd = math.Random(11);
    final n = (b.width / 22).clamp(14, 70).toInt();
    for (var i = 0; i < n; i++) {
      final p = Offset(rnd.nextDouble() * b.width, b.top + 6 + rnd.nextDouble() * b.height * 0.48);
      final speed = 3 + rnd.nextInt(6);
      final tw = 0.25 + 0.75 * (0.5 + 0.5 * math.sin((v * speed + rnd.nextDouble()) * _tau));
      final big = rnd.nextDouble() < 0.18;
      canvas.drawCircle(p, big ? 1.8 : 1.1, Paint()..color = Color.fromRGBO(243, 238, 221, tw));
      if (big && tw > 0.8) {
        final sp = Paint()
          ..color = Color.fromRGBO(243, 238, 221, (tw - 0.8) * 3)
          ..strokeWidth = 0.8;
        canvas.drawLine(p.translate(-4, 0), p.translate(4, 0), sp);
        canvas.drawLine(p.translate(0, -4), p.translate(0, 4), sp);
      }
    }
  }

  // Har 15 soniyada bir marta, ~0,7 s davomida
  void _shootingStar(Canvas canvas, Rect b, double v) {
    final k = (v * 4) % 1.0;
    if (k > 0.047) return;
    final p = k / 0.047;
    final idx = (v * 4).floor();
    final x0 = b.width * (0.15 + 0.17 * idx), y0 = b.top + b.height * 0.08;
    final head = Offset(x0 + b.width * 0.16 * p, y0 + b.height * 0.16 * p);
    final tail = head - Offset(b.width * 0.06, b.height * 0.06);
    final a = math.sin(p * math.pi);
    canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [const Color(0x00FFFFFF), Colors.white.withValues(alpha: a)]).createShader(Rect.fromPoints(tail, head)));
  }

  void _clouds(Canvas canvas, Rect b, double v) {
    final List<(double, double, double, int, double)> list = switch (cfg.scene) {
      // (x0, y, o'lcham, tezlik, shaffoflik)
      SkyScene.clear => [(0.10, 0.18, 0.7, 1, 0.55), (0.55, 0.10, 0.5, 2, 0.45)],
      SkyScene.clouds => [(0.02, 0.22, 1.0, 1, 0.9), (0.40, 0.10, 0.8, 2, 0.85), (0.70, 0.30, 1.2, 1, 0.9), (0.88, 0.14, 0.7, 3, 0.8)],
      SkyScene.rain || SkyScene.snow => [(0.0, 0.08, 1.4, 1, 0.92), (0.30, 0.18, 1.2, 2, 0.9), (0.62, 0.06, 1.5, 1, 0.92), (0.85, 0.20, 1.1, 2, 0.88)],
      SkyScene.fog => const [],
    };
    if (list.isEmpty) return;
    final base = cfg.night
        ? const Color(0xFF5C6680)
        : switch (cfg.scene) { SkyScene.rain => const Color(0xFF9AA2A6), SkyScene.snow => const Color(0xFFF0F2F4), _ => const Color(0xFFFFFFFF) };
    for (final (x0, fy, k, sp, a) in list) {
      final r = math.max(6.0, b.height * 0.075 * k);
      final span = b.width + r * 7;
      final x = ((x0 + v * sp) * span) % span - r * 3.5;
      _cloud(canvas, Offset(x, b.top + b.height * fy + r), r, base.withValues(alpha: a));
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 5.2, height: r * 1.6), p);
    canvas.drawCircle(c.translate(-r * 0.9, -r * 0.35), r * 0.9, p);
    canvas.drawCircle(c.translate(r * 0.4, -r * 0.6), r * 1.15, p);
  }

  // Uchta qush: chapdan o'ngga, qanot qoqib
  void _birds(Canvas canvas, Rect b, double v) {
    final p = Paint()
      ..color = const Color(0xFF3D3A30).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final size = (b.height * 0.03).clamp(4.0, 8.0);
    for (final (i, dx, dy) in const [(0, 0.0, 0.0), (1, -0.035, 0.04), (2, -0.06, -0.03)]) {
      final run = (v * 3 + i * 0.01) % 1.0; // 20 soniyada ekranni kesib o'tadi
      final x = -40 + (b.width + 80) * run + b.width * dx;
      final y = b.top + b.height * (0.20 + dy) + math.sin(run * _tau * 2 + i) * 4;
      final flap = math.sin((v * 240 + i * 0.3) * _tau); // ~4 marta/soniya
      final wy = size * 0.7 * flap;
      final path = Path()
        ..moveTo(x - size, y - wy)
        ..quadraticBezierTo(x - size * 0.4, y - wy * 0.2 - 2, x, y)
        ..quadraticBezierTo(x + size * 0.4, y - wy * 0.2 - 2, x + size, y - wy);
      canvas.drawPath(path, p);
    }
  }

  void _fireflies(Canvas canvas, Rect b, double v) {
    final rnd = math.Random(5);
    final n = (b.width / 60).clamp(6, 22).toInt();
    for (var i = 0; i < n; i++) {
      final cx = rnd.nextDouble() * b.width, cy = b.top + b.height * (0.70 + rnd.nextDouble() * 0.25);
      final fx = 1 + rnd.nextInt(3), fy = 2 + rnd.nextInt(3), ph = rnd.nextDouble();
      final p = Offset(cx + math.sin((v * fx + ph) * _tau) * 16, cy + math.cos((v * fy + ph) * _tau) * 7);
      final glow = 0.5 + 0.5 * math.sin((v * (6 + rnd.nextInt(5)) + ph) * _tau);
      if (glow < 0.15) continue;
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFF6E27A).withValues(alpha: 0.18 * glow));
      canvas.drawCircle(p, 1.6, Paint()..color = const Color(0xFFFFF3A8).withValues(alpha: glow));
    }
  }

  void _rain(Canvas canvas, Rect b, double v) {
    canvas.save();
    canvas.clipRect(b);
    final rnd = math.Random(3);
    final p = Paint()
      ..color = (cfg.night ? const Color(0xFFA9C8EC) : const Color(0xFFDDE6EC)).withValues(alpha: 0.62)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final n = (b.width / 5).clamp(40, 260).toInt();
    for (var i = 0; i < n; i++) {
      final x0 = rnd.nextDouble() * (b.width + 40);
      final speed = 45 + rnd.nextInt(16);
      final y = b.top + ((rnd.nextDouble() + v * speed) % 1.0) * (b.height + 30) - 20;
      final x = x0 - (y - b.top) * 0.18;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 14), p);
    }
    // Yerga tushgan tomchilar sachrashi — kengayib so'nadigan halqa
    final sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final m = (b.width / 40).clamp(8, 40).toInt();
    for (var i = 0; i < m; i++) {
      final x = rnd.nextDouble() * b.width, y = b.top + b.height * (0.86 + rnd.nextDouble() * 0.12);
      final k = (rnd.nextDouble() + v * (30 + rnd.nextInt(10))) % 1.0;
      if (k > 0.4) continue;
      final q = k / 0.4;
      sp.color = (cfg.night ? const Color(0xFFC8DCF2) : const Color(0xFFE8EEF0)).withValues(alpha: 0.7 * (1 - q));
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 3 + 10 * q, height: 1 + 3 * q), sp);
    }
    canvas.restore();
  }

  void _snow(Canvas canvas, Rect b, double v) {
    canvas.save();
    canvas.clipRect(b);
    final rnd = math.Random(4);
    final p = Paint()..color = (cfg.night ? const Color(0xFFE8ECF0) : const Color(0xFFFFFFFF)).withValues(alpha: 0.92);
    final n = (b.width / 10).clamp(24, 130).toInt();
    for (var i = 0; i < n; i++) {
      final x0 = rnd.nextDouble() * b.width;
      final speed = 6 + rnd.nextInt(8);
      final y = b.top + ((rnd.nextDouble() + v * speed) % 1.0) * (b.height + 10) - 5;
      final x = x0 + math.sin((v * speed * 2 + i / n) * _tau) * 7;
      canvas.drawCircle(Offset(x, y), 1.3 + rnd.nextDouble() * 1.9, p);
    }
    canvas.restore();
  }

  void _fog(Canvas canvas, Rect b, double v) {
    canvas.save();
    canvas.clipRect(b);
    for (var i = 0; i < 4; i++) {
      final y = b.top + b.height * (0.40 + i * 0.16);
      final dx = math.sin((v * 2 + i / 4) * _tau) * b.width * 0.08;
      canvas.drawRect(
        Rect.fromLTWH(-b.width * 0.2 + dx, y - b.height * 0.07, b.width * 1.4, b.height * 0.14),
        Paint()
          ..color = (cfg.night ? const Color(0xFF9DA391) : const Color(0xFFF4F1EA)).withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) => o.cfg != cfg || o.t != t || o.cache != cache;
}

/// Bosh sahifa manzarasi surati (Tabiiy Agro maketi). Almashtirish uchun shu faylni yangilash kifoya;
/// [_sunAt] — suratdagi quyosh joyi (0..1).
const orchardAsset = 'assets/images/orchard.jpg';
const _sunAt = Offset(0.145, 0.24);

/// Ob-havo va tun uchun rang: (ko'paytma rgb, to'yinganlik, qo'shimcha rgb, tuman rgba).
({List<double> mul, double sat, List<double> add, List<double> haze}) _grade(_Cfg cfg) {
  var mul = [1.02, 1.0, 0.97], add = [0.0, 0.0, 0.0], haze = [0.0, 0.0, 0.0, 0.0];
  var sat = 1.05;
  switch (cfg.scene) {
    case SkyScene.clear:
      break;
    case SkyScene.clouds:
      mul = [0.95, 0.97, 1.0];
      sat = 0.78;
      add = [0.02, 0.02, 0.03];
    case SkyScene.rain:
      mul = [0.78, 0.84, 0.92];
      sat = 0.58;
    case SkyScene.snow:
      mul = [1.0, 1.02, 1.06];
      sat = 0.35;
      add = [0.08, 0.08, 0.10];
    case SkyScene.fog:
      sat = 0.65;
      haze = [0.93, 0.92, 0.89, 0.45];
  }
  if (cfg.night) {
    mul = [mul[0] * 0.34, mul[1] * 0.40, mul[2] * 0.60];
    sat *= 0.7;
    add = [add[0] * 0.3, add[1] * 0.3 + 0.01, add[2] * 0.3 + 0.04];
    haze = [haze[0] * 0.35, haze[1] * 0.38, haze[2] * 0.5, haze[3] * 0.6];
  }
  return (mul: mul, sat: sat, add: add, haze: haze);
}

class _PhotoPainter extends _ScenePainter {
  _PhotoPainter(super.t, super.cfg, super.cache, this.image);
  final ui.Image image;

  static const _fade = 0.26;

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final top = cfg.skyTop.clamp(0.0, s.height * 0.7);
    final band = Rect.fromLTRB(0, top, s.width, s.height);
    final v = t.value;
    canvas.clipRect(Offset.zero & s);

    // Fon: matn ostida bir xil rang (dizayndagidek), aks holda osmon gradienti
    final tc = cfg.topColor;
    if (tc != null) {
      canvas.drawRect(Offset.zero & s, Paint()..color = tc);
    } else {
      _sky(canvas, s, band);
    }

    // Surat: "cover", pastga tekislangan + sekin "nafas olish" (Ken Burns)
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    // Keng ekranda (kompyuter) surat haddan ortiq kattalashmaydi — yonlari ko'zgu kabi davom etadi
    final scale = math.min(math.max(band.width / iw, band.height / ih), band.height / ih * 1.25);
    final zoom = 1.0 + 0.035 * (0.5 - 0.5 * math.cos(v * _ScenePainter._tau));
    final sw = band.width / scale / zoom, sh = band.height / scale / zoom;
    final pan = math.sin(v * _ScenePainter._tau) * (iw - sw) * 0.04;
    // Chapga yaqin tekislanadi — suratdagi quyosh kadrda qoladi
    final sx = sw >= iw ? (iw - sw) / 2 : ((iw - sw) * 0.3 + pan).clamp(0.0, iw - sw), sy = ih - sh;
    final src = Rect.fromLTWH(sx, sy, sw, sh);
    _photo(canvas, band, src, v);

    // Kunduzi ochiq osmon: suratdagi quyosh ustida jilva va aylanuvchi nurlar
    final sun = Offset(band.left + (iw * _sunAt.dx - src.left) / src.width * band.width, band.top + (ih * _sunAt.dy - src.top) / src.height * band.height);
    final r = math.max(8.0, band.height * 0.07);
    if (!cfg.night && cfg.scene == SkyScene.clear) {
      _sunGlare(canvas, sun, r, v);
    } else if (cfg.night) {
      if (cfg.scene == SkyScene.clear) _starsIn(canvas, Rect.fromLTRB(band.left, band.top + band.height * _fade * 0.5, band.right, band.top + band.height * 0.36), v);
      if (cfg.scene != SkyScene.rain && cfg.scene != SkyScene.snow) _moon(canvas, sun, r * 0.85, v);
    }
    _softClouds(canvas, band, v);
    if (!cfg.night && (cfg.scene == SkyScene.clear || cfg.scene == SkyScene.clouds)) {
      _birds(canvas, Rect.fromLTRB(band.left, band.top + band.height * 0.05, band.right, band.bottom), v);
      _leaves(canvas, band, v);
    }
    if (cfg.night && cfg.scene == SkyScene.clear && cfg.warm) _fireflies(canvas, band, v);
    switch (cfg.scene) {
      case SkyScene.rain:
        _rain(canvas, band, v);
      case SkyScene.snow:
        _snow(canvas, band, v);
      case SkyScene.fog:
        _fog(canvas, band, v);
      case SkyScene.clear || SkyScene.clouds:
        break;
    }
  }

  // Surat to'r (mesh) ustida chiziladi: tugunlarning tekstura nuqtalari shamol bilan siljiydi —
  // barglar tebranadi, chetlarda bo'sh joy ochilmaydi. Har platformada bir xil ishlaydi.
  void _photo(Canvas canvas, Rect band, Rect src, double v) {
    final g = _grade(cfg);
    const cols = 26, rows = 10;
    const tau = _ScenePainter._tau;
    final t = v * tau;
    final wind = switch (cfg.scene) { SkyScene.rain => 1.9, SkyScene.snow => 1.2, SkyScene.fog => 0.5, _ => 1.0 } * (0.7 + 0.3 * math.sin(t * 3));
    final px = src.width / band.width; // 1 ekran pikseli = shuncha surat pikseli
    final pos = Float32List((cols + 1) * (rows + 1) * 2), tex = Float32List((cols + 1) * (rows + 1) * 2);
    var k = 0;
    for (var j = 0; j <= rows; j++) {
      final fy = j / rows;
      for (var i = 0; i <= cols; i++) {
        final fx = i / cols;
        pos[k] = band.left + fx * band.width;
        pos[k + 1] = band.top + fy * band.height;
        final edge = 0.55 + 0.45 * _smooth(0.45, 1.0, (fx - 0.5).abs() * 2);
        final m = _smooth(0.28, 0.9, fy) * edge * wind;
        final dx = 0.6 * math.sin(t * 19 + fy * 14 + fx * 4) + 0.4 * math.sin(t * 33 + fx * 23 + fy * 5);
        final dy = 0.35 * math.sin(t * 24 + fx * 17);
        tex[k] = src.left + fx * src.width + dx * m * 2.4 * px;
        tex[k + 1] = (src.top + fy * src.height + dy * m * 2.4 * px).clamp(0.0, image.height.toDouble());
        k += 2;
      }
    }
    final idx = Uint16List(cols * rows * 6);
    k = 0;
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final a = j * (cols + 1) + i, b = a + 1, c = a + cols + 1, d = c + 1;
        idx.setAll(k, [a, b, c, b, d, c]);
        k += 6;
      }
    }
    final verts = ui.Vertices.raw(VertexMode.triangles, pos, textureCoordinates: tex, indices: idx);
    canvas.saveLayer(band, Paint());
    canvas.drawVertices(
        verts,
        BlendMode.srcOver,
        Paint()
          ..shader = ImageShader(image, TileMode.mirror, TileMode.clamp, Matrix4.identity().storage, filterQuality: FilterQuality.medium)
          ..colorFilter = ColorFilter.matrix(_matrix(g)));
    verts.dispose();
    if (g.haze[3] > 0) {
      canvas.drawRect(
          band,
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Color.from(alpha: g.haze[3], red: g.haze[0], green: g.haze[1], blue: g.haze[2]),
              Color.from(alpha: g.haze[3] * 0.45, red: g.haze[0], green: g.haze[1], blue: g.haze[2]),
            ]).createShader(band));
    }
    // Tepadan silliq paydo bo'lish — fon rangiga qo'shilib ketadi
    canvas.drawRect(
        band,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xFF000000)], stops: [0, _fade])
              .createShader(band));
    canvas.restore();
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  List<double> _matrix(({List<double> mul, double sat, List<double> add, List<double> haze}) g) {
    const lr = 0.299, lg = 0.587, lb = 0.114;
    final s = g.sat;
    final m = <double>[];
    for (var row = 0; row < 3; row++) {
      final k = g.mul[row];
      final base = [lr * (1 - s), lg * (1 - s), lb * (1 - s)];
      base[row] += s;
      m.addAll([base[0] * k, base[1] * k, base[2] * k, 0, g.add[row] * 255]);
    }
    m.addAll([0, 0, 0, 1, 0]);
    return m;
  }

  void _sunGlare(Canvas canvas, Offset c, double r, double v) {
    final pulse = 0.5 + 0.5 * math.sin(v * _ScenePainter._tau * 6);
    final glowR = r * (3.6 + 0.4 * pulse);
    canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(colors: [const Color(0xFFFFF1C4).withValues(alpha: 0.75 + 0.2 * pulse), const Color(0x00FFE6A8)]).createShader(Rect.fromCircle(center: c, radius: glowR)));
    final ray = Paint()
      ..blendMode = BlendMode.screen
      ..strokeCap = StrokeCap.round;
    final rot = v * _ScenePainter._tau * 2;
    for (var i = 0; i < 14; i++) {
      final a = rot + i * _ScenePainter._tau / 14;
      final len = r * (i.isEven ? 2.6 : 1.7) * (0.85 + 0.15 * math.sin(v * _ScenePainter._tau * 9 + i));
      final dir = Offset(math.cos(a), math.sin(a));
      ray
        ..strokeWidth = math.max(1.2, r * (i.isEven ? 0.16 : 0.1))
        ..shader = LinearGradient(colors: [const Color(0xAAFFF3CF), const Color(0x00FFF3CF)]).createShader(Rect.fromPoints(c + dir * r * 0.9, c + dir * (r * 0.9 + len)));
      canvas.drawLine(c + dir * r * 0.9, c + dir * (r * 0.9 + len), ray);
    }
    // Linza yolqini — quyoshdan pastga-o'ngga, nafas oladi
    for (final (k, rr, a) in const [(1.8, 0.35, 0.22), (2.9, 0.6, 0.14), (4.2, 0.25, 0.2)]) {
      final p = c + Offset(r * k * 1.4, r * k * 0.55);
      canvas.drawCircle(p, r * rr, Paint()
        ..blendMode = BlendMode.screen
        ..color = const Color(0xFFFFE9B0).withValues(alpha: a * (0.6 + 0.4 * pulse)));
    }
  }

  void _starsIn(Canvas canvas, Rect area, double v) {
    final rnd = math.Random(11);
    final n = (area.width / 26).clamp(10, 60).toInt();
    for (var i = 0; i < n; i++) {
      final p = Offset(area.left + rnd.nextDouble() * area.width, area.top + rnd.nextDouble() * area.height);
      final speed = 3 + rnd.nextInt(6);
      final tw = 0.2 + 0.8 * (0.5 + 0.5 * math.sin((v * speed + rnd.nextDouble()) * _ScenePainter._tau));
      canvas.drawCircle(p, rnd.nextDouble() < 0.2 ? 1.6 : 1.0, Paint()..color = Color.fromRGBO(243, 238, 221, tw));
    }
    _shootingStar(canvas, area, v);
  }

  // Yumshoq (xira) bulutlar suratning osmon qismida suzadi
  void _softClouds(Canvas canvas, Rect b, double v) {
    final List<(double, double, double, int, double)> list = switch (cfg.scene) {
      SkyScene.clear => [(0.30, 0.10, 0.7, 1, 0.35), (0.75, 0.04, 0.5, 2, 0.28)],
      SkyScene.clouds => [(0.0, 0.10, 1.1, 1, 0.75), (0.35, 0.02, 0.9, 2, 0.7), (0.62, 0.16, 1.2, 1, 0.75), (0.9, 0.06, 0.8, 3, 0.65)],
      SkyScene.rain || SkyScene.snow => [(0.0, -0.04, 1.6, 1, 0.9), (0.28, 0.06, 1.4, 2, 0.85), (0.55, -0.06, 1.7, 1, 0.9), (0.8, 0.08, 1.3, 2, 0.85)],
      SkyScene.fog => const [],
    };
    if (list.isEmpty) return;
    final base = cfg.night
        ? const Color(0xFF4E566C)
        : switch (cfg.scene) { SkyScene.rain => const Color(0xFF7A8388), SkyScene.snow => const Color(0xFFE9ECEF), _ => const Color(0xFFFFFFFF) };
    for (final (x0, fy, k, sp, a) in list) {
      final r = math.max(8.0, b.height * 0.09 * k);
      final span = b.width + r * 8;
      final x = ((x0 + v * sp) * span) % span - r * 4;
      final c = Offset(x, b.top + b.height * (fy + 0.12) + r);
      final p = Paint()
        ..color = base.withValues(alpha: a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35);
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 5.4, height: r * 1.5), p);
      canvas.drawCircle(c.translate(-r * 0.9, -r * 0.3), r * 0.85, p);
      canvas.drawCircle(c.translate(r * 0.5, -r * 0.55), r * 1.1, p);
    }
  }

  // Shamolda uchayotgan barglar (kunduzi)
  void _leaves(Canvas canvas, Rect b, double v) {
    final rnd = math.Random(9);
    final n = (b.width / 90).clamp(3, 12).toInt();
    final colors = [const Color(0xFF7FA03A), const Color(0xFFA8B845), const Color(0xFFC9A23C)];
    for (var i = 0; i < n; i++) {
      final speed = 2 + rnd.nextInt(3);
      final k = (rnd.nextDouble() + v * speed) % 1.0;
      final x = b.left - 20 + (b.width + 40) * ((rnd.nextDouble() + k * 0.6) % 1.0);
      final y = b.top + b.height * (0.25 + 0.75 * k) + math.sin((k * 3 + i) * _ScenePainter._tau) * 6;
      final a = (k < 0.1 ? k / 0.1 : (k > 0.9 ? (1 - k) / 0.1 : 1.0)) * 0.9;
      final size = 3.0 + rnd.nextDouble() * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((v * speed * 6 + i) * _ScenePainter._tau);
      canvas.scale(1, 0.45 + 0.55 * math.cos((v * speed * 8 + i) * _ScenePainter._tau).abs());
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size * 2, height: size), Paint()..color = colors[i % 3].withValues(alpha: a));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) => o is! _PhotoPainter || o.image != image || super.shouldRepaint(o);
}
