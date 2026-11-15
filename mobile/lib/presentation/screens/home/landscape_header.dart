import 'dart:async';
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
  // Quyosh balandligi vaqt o'tishi bilan o'zgaradi — manzara yorug'ligi har 2 daqiqada yangilanadi
  late final Timer _clock = Timer.periodic(const Duration(minutes: 2), (_) {
    if (mounted) setState(() {});
  });
  ui.Image? _photo, _near, _sky;
  _DepthGrid? _depth;
  ImageStream? _stream, _nearStream, _skyStream;
  late final ImageStreamListener _skyListener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() => _sky = info.image);
  }, onError: (_, __) {});
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() => _photo = info.image);
  }, onError: (_, __) {});
  late final ImageStreamListener _nearListener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() => _near = info.image);
  }, onError: (_, __) {});

  // Chuqurlik to'ri (kichik PNG): R — chuqurlik, G — oldingi qatlam, B — barg. Bir marta o'qiladi.
  static Future<_DepthGrid?>? _depthLoad;
  Future<_DepthGrid?> _loadDepth() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(orchardDepthAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      final px = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final g = px == null ? null : _DepthGrid(img.width, img.height, px.buffer.asUint8List());
      img.dispose();
      return g;
    } catch (_) {
      return null;
    }
  }

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
    final cfgImg = createLocalImageConfiguration(context);
    final stream = const AssetImage(orchardAsset).resolve(cfgImg);
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
    final ns = const AssetImage(orchardNearAsset).resolve(cfgImg);
    if (ns.key != _nearStream?.key) {
      _nearStream?.removeListener(_nearListener);
      _nearStream = ns..addListener(_nearListener);
    }
    final ss = const AssetImage(orchardSkyAsset).resolve(cfgImg);
    if (ss.key != _skyStream?.key) {
      _skyStream?.removeListener(_skyListener);
      _skyStream = ss..addListener(_skyListener);
    }
    if (_depth == null) {
      (_depthLoad ??= _loadDepth()).then((g) {
        if (mounted && g != null) setState(() => _depth = g);
      });
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
    _nearStream?.removeListener(_nearListener);
    _skyStream?.removeListener(_skyListener);
    _clock.cancel();
    _life.dispose();
    _ctl.dispose();
    _trees.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.weather;
    _clock; // taymerni ishga tushiradi
    final now = landscapeClock();
    // Sinov: --dart-define=AGRO_SUN_ELEV=<gradus> quyosh balandligini qotirib qo'yadi
    final sun = _sunOverride ?? sunElevation(now);
    // Ob-havo "kun/tun" bilan bir xil; ma'lumot bo'lmasa — quyosh balandligi bo'yicha
    final night = w != null ? !w.isDay : sun < -4;
    final scene = w == null ? SkyScene.clear : sceneFor(w.code);
    final warm = w == null || w.temperature >= 14;
    // Statik kadr: bulut, qush va tomchilar kadr ichida ko'rinadigan lahza
    final anim = _reduce ? const AlwaysStoppedAnimation<double>(0.27) : _ctl;
    final cfg = _Cfg(scene: scene, night: night, warm: warm, skyTop: widget.skyTop, topColor: widget.topColor, sun: (sun * 2).roundToDouble() / 2);
    final photo = _photo;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(builder: (context, box) {
          // Surat har qanday nisbatda "cover" bilan to'ldiriladi; yuklanmaguncha — kod bilan chizilgan manzara
          final painter = photo != null ? _PhotoPainter(anim, cfg, _trees, photo, _sky, _near, _depth) : _ScenePainter(anim, cfg, _trees);
          return CustomPaint(painter: painter, size: Size.infinite);
        }),
      ),
    );
  }
}

class _Cfg {
  const _Cfg({required this.scene, required this.night, required this.warm, required this.skyTop, this.topColor, this.sun = 45});
  final SkyScene scene;
  final bool night, warm;
  final double skyTop;
  final Color? topColor;

  /// Quyoshning ufqdan balandligi (gradus): manfiy — ufq ostida (shafaq, tun).
  final double sun;

  @override
  bool operator ==(Object o) =>
      o is _Cfg && o.scene == scene && o.night == night && o.warm == warm && o.skyTop == skyTop && o.topColor == topColor && o.sun == sun;
  @override
  int get hashCode => Object.hash(scene, night, warm, skyTop, topColor, sun);
}

/// Manzara hozir to'qmi (shafaqdan keyin / tun): ustidagi matn oq rangda bo'lishi kerak.
const _sunElevEnv = String.fromEnvironment('AGRO_SUN_ELEV');
final double? _sunOverride = double.tryParse(_sunElevEnv);

bool landscapeIsDark(Weather? w) => (_sunOverride ?? sunElevation(landscapeClock())) < -1;

/// Vaqt manbai (sinovda almashtiriladi).
DateTime Function() landscapeClock = DateTime.now;

/// Quyosh balandligi (gradus), NOAA soddalashtirilgan formulasi. Standart joy — O'zbekiston markazi.
double sunElevation(DateTime t, {double lat = 41.3, double lon = 69.3}) {
  final u = t.toUtc();
  final n = u.difference(DateTime.utc(u.year)).inDays + 1;
  final hour = u.hour + u.minute / 60 + u.second / 3600;
  final g = 2 * math.pi / 365 * (n - 1 + (hour - 12) / 24);
  final eq = 229.18 * (0.000075 + 0.001868 * math.cos(g) - 0.032077 * math.sin(g) - 0.014615 * math.cos(2 * g) - 0.040849 * math.sin(2 * g));
  final decl = 0.006918 - 0.399912 * math.cos(g) + 0.070257 * math.sin(g) - 0.006758 * math.cos(2 * g) + 0.000907 * math.sin(2 * g) -
      0.002697 * math.cos(3 * g) + 0.00148 * math.sin(3 * g);
  final tst = hour * 60 + eq + 4 * lon;
  final ha = (tst / 4 - 180) * math.pi / 180;
  final la = lat * math.pi / 180;
  final cz = (math.sin(la) * math.sin(decl) + math.cos(la) * math.cos(decl) * math.cos(ha)).clamp(-1.0, 1.0);
  return 90 - math.acos(cz) * 180 / math.pi;
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
const orchardAsset = 'assets/images/orchard_land.webp';

/// Suratning o'z osmoni (yer qismi to'ldirilgan) — "oltin soat"da ko'rinadi.
const orchardSkyAsset = 'assets/images/orchard_sky.jpg';

/// Oldingi qatlam (olmali shoxlar, chapdagi daraxt) — shaffof fonli; qushlar shu qatlam ortidan uchadi.
const orchardNearAsset = 'assets/images/orchard_near.webp';

/// Chuqurlik to'ri (MiDaS bilan hisoblangan): R — chuqurlik, G — oldingi qatlam, B — barg.
const orchardDepthAsset = 'assets/images/orchard_depth.png';

class _DepthGrid {
  _DepthGrid(this.w, this.h, this.px);
  final int w, h;
  final Uint8List px;

  /// (chuqurlik, oldingi qatlam, barg) — 0..1, bilinear.
  (double, double, double) at(double u, double v) {
    final x = (u.clamp(0.0, 1.0) * (w - 1)), y = (v.clamp(0.0, 1.0) * (h - 1));
    final x0 = x.floor(), y0 = y.floor(), x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
    final fx = x - x0, fy = y - y0;
    double ch(int c) {
      double p(int xx, int yy) => px[(yy * w + xx) * 4 + c] / 255.0;
      final a = p(x0, y0) + (p(x1, y0) - p(x0, y0)) * fx;
      final b = p(x0, y1) + (p(x1, y1) - p(x0, y1)) * fx;
      return a + (b - a) * fy;
    }
    return (ch(0), ch(1), ch(2));
  }
}
const _sunAt = Offset(0.175, 0.29);

/// Suratning rangi: kun vaqti (quyosh balandligi) va ob-havo. Barcha platformada bir xil ishlashi uchun
/// rang matritsasi emas, oddiy aralashtirish qatlamlari: to'yinganlik, ko'paytma (tus), "screen" (nur), tuman.
typedef _Grade = ({List<double> mul, double sat, List<double> glow, List<double> haze});

// (quyosh balandligi, ko'paytma rgb, to'yinganlik, nur rgba)
const _dayKeys = <(double, List<double>, double, List<double>)>[
  (-18, [0.26, 0.31, 0.50], 0.50, [0.05, 0.07, 0.17, 0.55]), // tun
  (-9, [0.38, 0.41, 0.62], 0.58, [0.10, 0.10, 0.28, 0.50]), // "ko'k soat"
  (-3, [0.74, 0.58, 0.66], 0.80, [0.38, 0.16, 0.30, 0.28]), // shafaq (pushti-binafsha)
  (2, [1.00, 0.78, 0.60], 1.00, [0.60, 0.26, 0.06, 0.24]), // quyosh botishi/chiqishi
  (9, [1.00, 0.92, 0.80], 1.00, [0.40, 0.22, 0.06, 0.13]), // oltin soat
  (20, [1.00, 1.00, 0.98], 1.00, [0.00, 0.00, 0.00, 0.00]), // kun
];

_Grade _grade(_Cfg cfg) {
  final e = cfg.sun;
  var lo = _dayKeys.first, hi = _dayKeys.last;
  if (e <= lo.$1) {
    hi = lo;
  } else if (e >= hi.$1) {
    lo = hi;
  } else {
    for (var i = 0; i < _dayKeys.length - 1; i++) {
      if (e >= _dayKeys[i].$1 && e <= _dayKeys[i + 1].$1) {
        lo = _dayKeys[i];
        hi = _dayKeys[i + 1];
        break;
      }
    }
  }
  final f = hi.$1 == lo.$1 ? 0.0 : (e - lo.$1) / (hi.$1 - lo.$1);
  double l(double a, double b) => a + (b - a) * f;
  var mul = [for (var i = 0; i < 3; i++) l(lo.$2[i], hi.$2[i])];
  var sat = l(lo.$3, hi.$3);
  var glow = [for (var i = 0; i < 4; i++) l(lo.$4[i], hi.$4[i])];
  var haze = [0.0, 0.0, 0.0, 0.0];
  final night = e < -6;
  switch (cfg.scene) {
    case SkyScene.clear:
      break;
    case SkyScene.clouds:
      mul = [mul[0] * 0.95, mul[1] * 0.97, mul[2]];
      sat *= 0.8;
      glow = [glow[0], glow[1], glow[2], glow[3] * 0.6];
    case SkyScene.rain:
      mul = [mul[0] * 0.78, mul[1] * 0.84, mul[2] * 0.92];
      sat *= 0.6;
      glow = [glow[0], glow[1], glow[2], glow[3] * 0.3];
    case SkyScene.snow:
      sat *= 0.4;
      glow = night ? glow : [0.85, 0.88, 0.95, 0.22];
    case SkyScene.fog:
      sat *= 0.65;
      haze = night ? [0.32, 0.35, 0.42, 0.35] : [0.93, 0.92, 0.89, 0.45];
  }
  return (mul: mul, sat: sat, glow: glow, haze: haze);
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Haqiqiy surat asosidagi qatlamli ("2.5D") sahna. Surat uch qatlamga ajratilgan:
///   1) osmon — kod bilan chiziladi (kun vaqtiga qarab rang, quyosh, oy, yulduzlar, bulutlar), "oltin soat"da
///      ustiga suratning o'z osmoni chiqadi;
///   2) yer — tog'lar va daraxtlar (osmon shaffof): quyosh tog' ortidan chiqadi/botadi, yulduzlar faqat osmonda;
///   3) oldingi shoxlar — qushlar shu qatlam ortidan uchadi.
/// To'r (mesh) tugunlari chuqurlik xaritasi bo'yicha siljiydi: kamera sekin aylanganda yaqin narsalar ko'proq
/// suriladi (parallaks), shamol esa daraxtlar bo'ylab to'lqin bo'lib o'tadi.
class _PhotoPainter extends _ScenePainter {
  _PhotoPainter(super.t, super.cfg, super.cache, this.image, this.sky, this.near, this.depth);
  final ui.Image image; // yer (alfa bilan)
  final ui.Image? sky, near;
  final _DepthGrid? depth;

  static const _cols = 48, _rows = 18;
  static const _tau = _ScenePainter._tau;

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final band = Offset.zero & s;
    final v = t.value;
    canvas.clipRect(band);

    // Surat pastga tekislanadi: eni to'liq yoki balandlikning ~2/3 qismi. Tor ekranda quyoshli chap qism ko'rinadi.
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final scale = math.max(band.width / iw, band.height * 0.66 / ih) * 1.05;
    final k = scale * (1.0 + 0.02 * (0.5 - 0.5 * math.cos(v * _tau)));
    final sw = math.min(iw, band.width / k);
    final dh = math.min(band.height, ih * k);
    final sh = dh / k;
    final sx = ((iw - sw) * (sw / iw < 0.7 ? 0.22 : 0.42)).clamp(0.0, math.max(0.0, iw - sw)).toDouble();
    final sy = ((ih - sh) * 0.92).clamp(0.0, math.max(0.0, ih - sh)).toDouble();
    final src = Rect.fromLTWH(sx, sy, sw, sh);
    final photo = Rect.fromLTRB(band.left, band.bottom - dh, band.right, band.bottom);
    Offset at(double u, double w) => Offset(photo.left + (iw * u - src.left) / src.width * photo.width, photo.top + (ih * w - src.top) / src.height * photo.height);
    final mesh = _mesh(photo, src, v);

    final e = cfg.sun;
    final open = cfg.scene == SkyScene.clear || cfg.scene == SkyScene.clouds;
    final day = e > 1 && open;
    final g = _grade(cfg);
    final horizon = at(0.5, _ridgeY).dy;
    // Suratning o'z osmoni: faqat "oltin soat"da (quyosh ufqqa yaqin) to'liq ko'rinadi
    final golden = !open ? 0.0 : _smoothstep(-5, 0, e) * (1 - _smoothstep(5, 13, e)) * (cfg.scene == SkyScene.clouds ? 0.55 : 1.0);

    // ---- 1. Osmon ----
    _procSky(canvas, band, horizon, e);
    final starA = _smoothstep(-4, -11, e) * (cfg.scene == SkyScene.clear ? 1.0 : (cfg.scene == SkyScene.clouds ? 0.35 : 0.0));
    if (starA > 0) _starField(canvas, Rect.fromLTRB(band.left, band.top, band.right, horizon), v, starA);
    final sunBase = at(_sunAt.dx, _sunAt.dy);
    if (open) {
      // Shafaq: quyosh botgan joyda ufq yorishib turadi
      final after = _smoothstep(-13, -2, e) * (1 - golden);
      if (after > 0.01) {
        final c0 = Offset(sunBase.dx, horizon), rr = band.width * 0.75;
        canvas.drawCircle(
            c0,
            rr,
            Paint()
              ..shader = RadialGradient(colors: [
                Color.lerp(const Color(0xFFB04A6A), const Color(0xFFFFA65C), _smoothstep(-10, -2, e))!.withValues(alpha: 0.75 * after),
                const Color(0x00B04A6A),
              ]).createShader(Rect.fromCircle(center: c0, radius: rr)));
      }
      // Quyosh diski: balandlikka qarab ko'tariladi, tog' ortidan chiqadi (yer qatlami ustidan yopadi)
      final discA = e > -3 ? (1 - golden).clamp(0.0, 1.0) : 0.0;
      if (discA > 0.02) {
        final c0 = sunBase + Offset((e - 2.5) * photo.width * 0.0035, -(e - 2.5) * photo.height * 0.017);
        _sunDisc(canvas, c0, math.max(7.0, photo.height * 0.034), e, discA);
      }
      final moonA = _smoothstep(-3, -9, e);
      if (moonA > 0) {
        final mc = Offset(band.left + band.width * 0.62, band.top + (horizon - band.top) * 0.42);
        final mr = math.max(8.0, photo.height * 0.045);
        canvas.saveLayer(Rect.fromCircle(center: mc, radius: mr * 4), Paint()..color = Color.fromRGBO(0, 0, 0, moonA));
        _moon(canvas, mc, mr, v);
        canvas.restore();
      }
    }
    final skyImg = sky;
    if (golden > 0.01 && skyImg != null && skyImg.width == image.width) {
      final fadeTop = photo.top > band.top + 0.5;
      canvas.saveLayer(photo, Paint()..color = Color.fromRGBO(0, 0, 0, golden));
      canvas.drawVertices(mesh, BlendMode.srcOver, _imgPaint(skyImg));
      if (fadeTop) {
        final f = Rect.fromLTRB(photo.left, photo.top, photo.right, photo.top + photo.height * 0.2);
        canvas.drawRect(
            f,
            Paint()
              ..blendMode = BlendMode.dstIn
              ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xFF000000)]).createShader(f));
      }
      canvas.restore();
    }
    _softClouds(canvas, Rect.fromLTRB(band.left, band.top, band.right, horizon), v, 1 - golden * 0.8);

    // ---- 2. Yer: tog'lar va daraxtlar ----
    canvas.saveLayer(photo, Paint());
    canvas.drawVertices(mesh, BlendMode.srcOver, _imgPaint(image));
    _gradeAtop(canvas, photo, g);
    canvas.restore();

    if (day) _flock(canvas, photo, v, front: false);

    // ---- 3. Oldingi shoxlar ----
    final n = near;
    if (n != null && n.width == image.width) {
      canvas.saveLayer(photo, Paint());
      canvas.drawVertices(mesh, BlendMode.srcOver, _imgPaint(n));
      _gradeAtop(canvas, photo, g);
      canvas.restore();
    }
    mesh.dispose();

    if (day) _flock(canvas, photo, v, front: true);
    // Past quyosh: linza ustidagi iliq yog'du (daraxtlar orasidan "to'kiladi")
    final bloom = (cfg.scene == SkyScene.clear ? 1.0 : 0.0) * _smoothstep(-2, 2, e) * (1 - _smoothstep(10, 22, e));
    if (bloom > 0.01) {
      final pulse = 0.5 + 0.5 * math.sin(v * _tau * 5);
      final rr = photo.height * (0.55 + 0.04 * pulse);
      canvas.drawCircle(
          sunBase,
          rr,
          Paint()
            ..blendMode = BlendMode.screen
            ..shader = RadialGradient(colors: [
              const Color(0xFFFFD08A).withValues(alpha: (0.55 + 0.1 * pulse) * bloom),
              const Color(0xFFFFB25C).withValues(alpha: 0.18 * bloom),
              const Color(0x00FFB25C),
            ], stops: const [0, 0.45, 1]).createShader(Rect.fromCircle(center: sunBase, radius: rr)));
    }
    if (day) _leaves(canvas, photo, v);
    if (e < -8 && cfg.scene == SkyScene.clear && cfg.warm) _fireflies(canvas, photo, v);
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

    // Matn ostida yengil tuman va pastda sahifaga silliq o'tish
    final tc = cfg.topColor;
    if (tc != null) {
      final dark = e < -1;
      final top = dark ? const Color(0xFF0C1220) : tc;
      final textEnd = (cfg.skyTop / band.height).clamp(0.2, 0.75);
      canvas.drawRect(
          band,
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              top.withValues(alpha: dark ? 0.5 : 0.84),
              top.withValues(alpha: dark ? 0.3 : 0.66),
              top.withValues(alpha: 0.0),
              tc.withValues(alpha: 0.0),
              tc,
            ], stops: [0, textEnd * 0.62, textEnd + 0.06, 0.88, 1]).createShader(band));
    }
  }

  Paint _imgPaint(ui.Image img) =>
      Paint()..shader = ImageShader(img, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage, filterQuality: FilterQuality.medium);

  /// Suratdagi tog' cho'qqilari chizig'ining o'rtacha balandligi (0..1) — ufq.
  static const _ridgeY = 0.33;

  /// To'r: tugunlar ekranda qo'zg'almas, tekstura nuqtalari chuqurlik (parallaks) va shamol bilan siljiydi.
  ui.Vertices _mesh(Rect band, Rect src, double v) {
    final t = v * _tau;
    final px = src.width / band.width; // 1 ekran pikseli = shuncha surat pikseli
    final iw = image.width.toDouble(), ih = image.height.toDouble();
    final camX = math.sin(t), camY = 0.5 * math.sin(t * 2 + 1.3);
    final par = (band.width * 0.011).clamp(4.0, 16.0);
    final dolly = 0.016 * math.sin(t + 0.6);
    final wind = switch (cfg.scene) { SkyScene.rain => 1.8, SkyScene.snow => 1.1, SkyScene.fog => 0.4, _ => 1.0 };
    final pos = Float32List((_cols + 1) * (_rows + 1) * 2), tex = Float32List((_cols + 1) * (_rows + 1) * 2);
    var k = 0;
    for (var j = 0; j <= _rows; j++) {
      final fy = j / _rows;
      for (var i = 0; i <= _cols; i++) {
        final fx = i / _cols;
        pos[k] = band.left + fx * band.width;
        pos[k + 1] = band.top + fy * band.height;
        final u = src.left + fx * src.width, w = src.top + fy * src.height;
        final un = u / iw, wn = w / ih;
        final (d, nearW, leaf) = depth?.at(un, wn) ?? (0.25 + 0.6 * fy, 0.0, _smoothstep(0.3, 0.9, fy));
        // Parallaks: uzoq (d≈0) va yaqin (d≈1) qarama-qarshi tomonga siljiydi
        final z = d - 0.4;
        var dx = -camX * z * par + (fx - 0.5) * band.width * dolly * z;
        var dy = -camY * z * par * 0.5 + (fy - 0.5) * band.height * dolly * z;
        // Shamol. (a) shiddat — bog' bo'ylab chapdan o'ngga sekin o'tadigan to'lqin;
        // (b) shox tebranishi — har daraxt o'z fazasida, sekin (4–7 s); (c) barg titrashi — mayda va tez.
        final gust = 0.5 + 0.5 * math.sin(t * 4 - un * 9.0) * math.sin(t * 3 + un * 4.0 + 1.0);
        final amp = leaf * (0.3 + 0.7 * d) * wind * (0.35 + 0.65 * gust);
        final tree = un * 31.0 + wn * 7.0; // qo'shni tugunlar birga harakatlanadi — butun shox egiladi
        final sway = math.sin(t * 9 + tree) + 0.5 * math.sin(t * 14 + tree * 1.7 + 2.0);
        final flutter = math.sin(t * 37 + un * 190 + wn * 70) + math.sin(t * 53 + un * 130 - wn * 110);
        final a = (1.6 + 3.2 * nearW) * amp;
        dx += a * (sway + 0.22 * flutter);
        dy += a * (0.35 * math.sin(t * 11 + tree * 1.3) + 0.2 * flutter);
        tex[k] = (u + dx * px).clamp(0.0, iw);
        tex[k + 1] = (w + dy * px).clamp(0.0, ih);
        k += 2;
      }
    }
    final idx = Uint16List(_cols * _rows * 6);
    k = 0;
    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final a = j * (_cols + 1) + i, b = a + 1, c = a + _cols + 1, d = c + 1;
        idx.setAll(k, [a, b, c, b, d, c]);
        k += 6;
      }
    }
    return ui.Vertices.raw(VertexMode.triangles, pos, textureCoordinates: tex, indices: idx);
  }

  // Rang (faqat qatlamning chizilgan joyiga — shaffof joy shaffof qoladi): xiralashtirish → tus → nur → tuman
  void _gradeAtop(Canvas canvas, Rect r, _Grade g) {
    if (g.sat < 0.99) {
      canvas.drawRect(r, Paint()
        ..blendMode = BlendMode.srcATop
        ..color = Color.fromRGBO(120, 122, 128, ((1 - g.sat) * 0.4).clamp(0.0, 1.0)));
    }
    if (g.mul.any((m) => m < 0.995)) {
      canvas.drawRect(r, Paint()
        ..blendMode = BlendMode.modulate
        ..color = Color.from(alpha: 1, red: g.mul[0].clamp(0.0, 1.0), green: g.mul[1].clamp(0.0, 1.0), blue: g.mul[2].clamp(0.0, 1.0)));
    }
    if (g.glow[3] > 0.005) {
      canvas.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Color.from(alpha: g.glow[3] * 0.3, red: g.glow[0], green: g.glow[1], blue: g.glow[2]),
              Color.from(alpha: g.glow[3] * 0.1, red: g.glow[0], green: g.glow[1], blue: g.glow[2]),
            ]).createShader(r));
    }
    if (g.haze[3] > 0) {
      canvas.drawRect(
          r,
          Paint()
            ..blendMode = BlendMode.srcATop
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Color.from(alpha: g.haze[3], red: g.haze[0], green: g.haze[1], blue: g.haze[2]),
              Color.from(alpha: g.haze[3] * 0.45, red: g.haze[0], green: g.haze[1], blue: g.haze[2]),
            ]).createShader(r));
    }
  }

  // (quyosh balandligi, tepa, o'rta, ufq)
  static const _skyKeys = <(double, int, int, int)>[
    (-18, 0xFF050916, 0xFF0A1024, 0xFF131B34),
    (-9, 0xFF0C1634, 0xFF22346A, 0xFF4F5A8E),
    (-4, 0xFF1F2E66, 0xFF6C5A92, 0xFFE08A6E),
    (0, 0xFF45659F, 0xFFD9A088, 0xFFFFC27A),
    (7, 0xFF5F92CF, 0xFFB9D0E8, 0xFFFFE3B4),
    (22, 0xFF3C82D4, 0xFF86B8EA, 0xFFD9E9F5),
  ];

  void _procSky(Canvas canvas, Rect band, double horizon, double e) {
    var lo = _skyKeys.first, hi = _skyKeys.last;
    if (e <= lo.$1) {
      hi = lo;
    } else if (e >= hi.$1) {
      lo = hi;
    } else {
      for (var i = 0; i < _skyKeys.length - 1; i++) {
        if (e >= _skyKeys[i].$1 && e <= _skyKeys[i + 1].$1) {
          lo = _skyKeys[i];
          hi = _skyKeys[i + 1];
          break;
        }
      }
    }
    final f = hi.$1 == lo.$1 ? 0.0 : (e - lo.$1) / (hi.$1 - lo.$1);
    var c = [Color.lerp(Color(lo.$2), Color(hi.$2), f)!, Color.lerp(Color(lo.$3), Color(hi.$3), f)!, Color.lerp(Color(lo.$4), Color(hi.$4), f)!];
    // Bulutli/yomg'irli havo: kulrang osmon (tunda to'q)
    final grey = switch (cfg.scene) { SkyScene.clear => 0.0, SkyScene.clouds => 0.45, SkyScene.fog => 0.8, _ => 0.85 };
    if (grey > 0) {
      final l = _smoothstep(-8, 6, e);
      final o = Color.lerp(const Color(0xFF1B1F29), cfg.scene == SkyScene.snow ? const Color(0xFFCFD5DB) : const Color(0xFF8B949C), l)!;
      c = [for (final x in c) Color.lerp(x, o, grey)!];
    }
    final r = Rect.fromLTRB(band.left, band.top, band.right, math.max(horizon, band.top + 1));
    canvas.drawRect(band, Paint()..color = c[2]);
    canvas.drawRect(r, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c, stops: const [0, 0.55, 1]).createShader(r));
  }

  void _sunDisc(Canvas canvas, Offset c, double r, double e, double a) {
    final high = _smoothstep(0, 22, e);
    final core = Color.lerp(const Color(0xFFFFB061), const Color(0xFFFFFBEA), high)!;
    final halo = Color.lerp(const Color(0xFFFF8A3D), const Color(0xFFFFF2C8), high)!;
    final gr = r * (7 - 2 * high);
    canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = RadialGradient(colors: [halo.withValues(alpha: 0.55 * a), halo.withValues(alpha: 0.12 * a), halo.withValues(alpha: 0)], stops: const [0, 0.4, 1])
              .createShader(Rect.fromCircle(center: c, radius: gr)));
    canvas.drawCircle(
        c,
        r * 1.25,
        Paint()..shader = RadialGradient(colors: [core.withValues(alpha: a), core.withValues(alpha: a), core.withValues(alpha: 0)], stops: const [0, 0.72, 1]).createShader(Rect.fromCircle(center: c, radius: r * 1.25)));
  }

  // Yulduzlar: turli yorqinlik va tus, sekin miltillash, xira Somon yo'li; ba'zan yulduz uchadi
  static final List<(double, double, double, int, double, int)> _starList = () {
    final rnd = math.Random(20261);
    const tints = [0xFFFFFFFF, 0xFFFFFFFF, 0xFFDDE8FF, 0xFFFFF1DC, 0xFFCFDcFF, 0xFFFFE4C4];
    return [
      for (var i = 0; i < 260; i++)
        (rnd.nextDouble(), math.pow(rnd.nextDouble(), 1.3).toDouble(), math.pow(rnd.nextDouble(), 4).toDouble(), tints[rnd.nextInt(tints.length)], rnd.nextDouble(), 14 + rnd.nextInt(40)),
    ];
  }();

  void _starField(Canvas canvas, Rect area, double v, double alpha) {
    // Somon yo'li: qiya, juda xira yorug' tasma
    canvas.save();
    canvas.translate(area.left + area.width * 0.58, area.top + area.height * 0.38);
    canvas.rotate(-0.5);
    final mw = Rect.fromCenter(center: Offset.zero, width: area.width * 1.25, height: area.height * 0.5);
    canvas.drawOval(mw, Paint()..shader = RadialGradient(colors: [const Color(0xFFBFCBFF).withValues(alpha: 0.13 * alpha), const Color(0x00BFCBFF)]).createShader(mw));
    canvas.restore();
    final dens = (area.width * area.height / 2600).clamp(40, 260).toInt();
    final p = Paint();
    for (var i = 0; i < dens; i++) {
      final (x, y, mag, tint, ph, sp) = _starList[i];
      // Ufqqa yaqinlashganda yulduzlar xiralashadi (atmosfera)
      final low = 1 - _smoothstep(0.7, 1.0, y);
      final tw = 0.72 + 0.28 * math.sin((v * sp + ph) * _tau);
      final a = (0.35 + 0.65 * mag) * tw * low * alpha;
      final c = Offset(area.left + x * area.width, area.top + y * area.height);
      final r = 0.55 + 1.25 * mag;
      p.color = Color(tint).withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawCircle(c, r, p);
      if (mag > 0.55) {
        // Yorqin yulduz atrofida yumshoq yog'du
        p.color = Color(tint).withValues(alpha: (a * 0.22).clamp(0.0, 1.0));
        canvas.drawCircle(c, r * 3.2, p);
      }
    }
    if (alpha > 0.7) _meteors(canvas, area, v);
  }

  // Uchar yulduz: bir daqiqada uch marta, har biri ~0,9 s; boshi yorqin, dumi so'nib boradi
  void _meteors(Canvas canvas, Rect area, double v) {
    const events = [(0.10, 0.22, 0.10, 0.34, 0.20), (0.46, 0.78, 0.06, -0.28, 0.24), (0.79, 0.45, 0.18, 0.30, 0.15)];
    const dur = 0.015;
    for (final (t0, x0, y0, dx, dy) in events) {
      final k = (v - t0) / dur;
      if (k < 0 || k > 1) continue;
      final ease = Curves.easeIn.transform(k);
      final head = Offset(area.left + (x0 + dx * ease) * area.width, area.top + (y0 + dy * ease) * area.height);
      final dir = Offset(dx * area.width, dy * area.height);
      final len = dir.distance == 0 ? Offset.zero : dir / dir.distance;
      final tail = head - len * (area.width * 0.13 * math.sin(k * math.pi).clamp(0.15, 1.0));
      final a = math.sin(k * math.pi);
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..shader = LinearGradient(colors: [const Color(0x00FFFFFF), Color.fromRGBO(255, 250, 235, a)]).createShader(Rect.fromPoints(tail, head)));
      canvas.drawCircle(head, 1.8, Paint()..color = Color.fromRGBO(255, 252, 240, a));
      canvas.drawCircle(head, 5.5, Paint()..color = Color.fromRGBO(255, 244, 214, a * 0.25));
    }
  }

  // Yumshoq bulutlar osmonda sekin suzadi
  void _softClouds(Canvas canvas, Rect b, double v, double strength) {
    final List<(double, double, double, int, double)> list = switch (cfg.scene) {
      SkyScene.clear => [(0.30, 0.18, 0.8, 1, 0.5), (0.78, 0.42, 0.55, 2, 0.4)],
      SkyScene.clouds => [(0.0, 0.25, 1.2, 1, 0.8), (0.35, 0.08, 1.0, 2, 0.75), (0.62, 0.45, 1.3, 1, 0.8), (0.9, 0.2, 0.9, 3, 0.7)],
      SkyScene.rain || SkyScene.snow => [(0.0, 0.1, 1.7, 1, 0.9), (0.28, 0.3, 1.5, 2, 0.85), (0.55, 0.05, 1.8, 1, 0.9), (0.8, 0.35, 1.4, 2, 0.85)],
      SkyScene.fog => const [],
    };
    if (list.isEmpty || strength <= 0.02) return;
    final dayC = switch (cfg.scene) { SkyScene.rain => const Color(0xFF7A8388), SkyScene.snow => const Color(0xFFE9ECEF), _ => const Color(0xFFFFFFFF) };
    final e = cfg.sun;
    final base = e >= 8
        ? dayC
        : e >= 0
            ? Color.lerp(const Color(0xFFF6C9A8), dayC, e / 8)!
            : Color.lerp(const Color(0xFF2A3145), const Color(0xFFD9A0A8), _smoothstep(-9, 0, e))!;
    for (final (x0, fy, k, sp, a) in list) {
      final r = math.max(8.0, b.height * 0.11 * k);
      final span = b.width + r * 8;
      final x = ((x0 + v * sp) * span) % span - r * 4;
      final c = Offset(b.left + x, b.top + b.height * fy + r);
      final p = Paint()
        ..color = base.withValues(alpha: a * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4);
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 5.4, height: r * 1.3), p);
      canvas.drawCircle(c.translate(-r * 0.9, -r * 0.3), r * 0.8, p);
      canvas.drawCircle(c.translate(r * 0.5, -r * 0.5), r * 1.05, p);
    }
  }

  // Qushlar: uzoqda "V" shaklidagi gala, daraxtlar orasidan o'tadigan yakka qushlar (oldingi shoxlar ortida) va
  // ba'zan kameraga yaqin uchib o'tadigan bitta qush. Qanot qoqadi, so'ng biroz sirpanadi.
  void _flock(Canvas canvas, Rect b, double v, {required bool front}) {
    final col = Color.lerp(const Color(0xFF241F1A), const Color(0xFF3A342B), _smoothstep(8, 30, cfg.sun))!;
    final unit = (b.height / 300).clamp(0.7, 1.7);
    void bird(double x, double y, double size, double phase, int dir, double alpha, double tilt) {
      // 62% vaqt qanot qoqadi (2 marta), qolganida sirpanadi
      final flap = phase < 0.62 ? math.sin(phase / 0.62 * _tau * 2) : 0.22 * math.cos((phase - 0.62) / 0.38 * math.pi);
      final wy = size * 0.8 * flap;
      final p = Paint()..color = col.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y - wy * 0.12); // qanot pastga urganda gavda biroz ko'tariladi
      canvas.rotate(tilt * dir);
      if (dir < 0) canvas.scale(-1, 1);
      for (final sgn in const [-1.0, 1.0]) {
        // Uzoqdagi (orqa) qanot biroz qisqa — hajm hissi
        final s = size * (sgn < 0 ? 0.86 : 1.0);
        canvas.drawPath(
            Path()
              ..moveTo(size * 0.1, 0)
              ..quadraticBezierTo(sgn * s * 0.42 + size * 0.05, -wy * 0.95 - s * 0.26, sgn * s, -wy)
              ..quadraticBezierTo(sgn * s * 0.5, -wy * 0.42 + s * 0.06, -size * 0.12, size * 0.1)
              ..close(),
            p);
      }
      canvas.drawOval(Rect.fromCenter(center: Offset(size * 0.02, size * 0.05), width: size * 0.78, height: size * 0.24), p);
      canvas.drawCircle(Offset(size * 0.42, 0), size * 0.11, p); // bosh
      canvas.drawPath(
          Path()
            ..moveTo(-size * 0.3, size * 0.04)
            ..lineTo(-size * 0.62, -size * 0.03)
            ..lineTo(-size * 0.6, size * 0.14)
            ..close(),
          p); // dum
      canvas.restore();
    }

    if (front) {
      final run = (0.55 + v * 2) % 1.0;
      if (run < 0.45) {
        final k = run / 0.45;
        bird(b.right + 60 - (b.width + 120) * k, b.top + b.height * (0.34 + 0.07 * math.sin(k * _tau)), 17 * unit, (v * 150) % 1.0, -1, 0.94, 0.06 * math.cos(k * _tau));
      }
      return;
    }
    // Uzoq gala: 7 ta qush, "V" shaklida, sekin
    final fr = (0.05 + v * 2) % 1.0;
    final fx = b.left - 90 + (b.width + 180) * fr, fy = b.top + b.height * (0.13 + 0.03 * math.sin(fr * _tau));
    for (var i = 0; i < 7; i++) {
      final side = i == 0 ? 0 : (i.isOdd ? -1 : 1), rank = (i + 1) ~/ 2;
      bird(fx - rank * 13.0 * unit, fy + side * rank * 6.5 * unit + math.sin((v * 9 + i * 0.37) * _tau) * 1.5, 4.6 * unit, (v * 170 + i * 0.19) % 1.0, 1, 0.8, 0);
    }
    // Daraxtlar orasidan o'tadigan yakka qushlar
    for (final (i, (start, speed, h, size, dir, wave)) in const [(0.30, 3, 0.36, 8.0, -1, 0.05), (0.62, 2, 0.47, 9.5, 1, 0.06), (0.86, 3, 0.29, 7.0, 1, 0.04)].indexed) {
      final run = (start + v * speed) % 1.0;
      final span = b.width + 140;
      final x = dir > 0 ? b.left - 70 + span * run : b.right + 70 - span * run;
      final y = b.top + b.height * (h + wave * math.sin(run * _tau * 2 + i));
      bird(x, y, size * unit, (v * 190 + i * 0.41) % 1.0, dir, 0.86, 0.1 * math.cos(run * _tau * 2 + i));
    }
  }

  // Shamolda uchayotgan barglar (kunduzi)
  void _leaves(Canvas canvas, Rect b, double v) {
    final rnd = math.Random(9);
    final n = (b.width / 110).clamp(3, 10).toInt();
    final colors = [const Color(0xFF7FA03A), const Color(0xFFA8B845), const Color(0xFFC9A23C)];
    for (var i = 0; i < n; i++) {
      final speed = 2 + rnd.nextInt(3);
      final k = (rnd.nextDouble() + v * speed) % 1.0;
      final x = b.left - 20 + (b.width + 40) * ((rnd.nextDouble() + k * 0.6) % 1.0);
      final y = b.top + b.height * (0.3 + 0.7 * k) + math.sin((k * 3 + i) * _tau) * 6;
      final a = (k < 0.1 ? k / 0.1 : (k > 0.9 ? (1 - k) / 0.1 : 1.0)) * 0.85;
      final size = 2.5 + rnd.nextDouble() * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((v * speed * 6 + i) * _tau);
      canvas.scale(1, 0.45 + 0.55 * math.cos((v * speed * 8 + i) * _tau).abs());
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size * 2, height: size), Paint()..color = colors[i % 3].withValues(alpha: a));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter o) =>
      o is! _PhotoPainter || o.image != image || o.sky != sky || o.near != near || o.depth != depth || super.shouldRepaint(o);
}
