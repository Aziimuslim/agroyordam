import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

/// Ilovaning harakat tizimi (Motion): bosish, paydo bo'lish, sanash, jilva.
/// Hammasi "harakatni kamaytirish" sozlamasiga bo'ysunadi; cheksiz animatsiyalar testda o'chadi.

bool _reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Cheksiz (fon) animatsiyalar yoqilganmi: test muhitida va "harakatni kamaytirish"da — yo'q.
bool ambientMotion(BuildContext context) =>
    !_reduced(context) && !WidgetsBinding.instance.runtimeType.toString().contains('Test');

/// Bosilganda biroz kichrayadi va qo'yib yuborilganda yumshoq qaytadi — "jonli" tugma hissi.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});
  final Widget child;
  final bool enabled;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Bir marta paydo bo'lish: shaffoflik + pastdan 12 px siljish. Bir kadrda qurilgan elementlar navbat bilan
/// (45 ms oraliq, ko'pi bilan 8 qadam) chiqadi. Foydalanuvchi ro'yxatni aylantirayotganda yangi elementlar
/// kechikmasdan ko'rinadi.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.offset = 12});
  final Widget child;
  final double offset;

  static int _batch = 0;
  static bool _resetScheduled = false;
  static int _nextIndex() {
    if (!_resetScheduled) {
      _resetScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _batch = 0;
        _resetScheduled = false;
      });
    }
    return _batch++;
  }

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  static const _step = 45, _run = 380;
  AnimationController? _ctl;
  Animation<double>? _anim;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduced(context)) return;
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != null && pos.hasPixels && pos.pixels > 40) return; // aylantirish paytida — darhol
    final i = Appear._nextIndex().clamp(0, 8);
    final total = _run + i * _step;
    _ctl = AnimationController(vsync: this, duration: Duration(milliseconds: total))..forward();
    _anim = CurvedAnimation(parent: _ctl!, curve: Interval(i * _step / total, 1, curve: AppMotion.enter));
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _anim;
    if (a == null) return widget.child;
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (context, child) {
        final k = a.value;
        if (k >= 1) return child!;
        return Opacity(opacity: k, child: Transform.translate(offset: Offset(0, widget.offset * (1 - k)), child: child));
      },
    );
  }
}

/// Son 0 dan (yoki oldingi qiymatdan) hozirgi qiymatgacha sanab chiqadi.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.suffix = ''});
  final int value;
  final TextStyle? style;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return Text('$value$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Yuklanayotgan joy ustidan o'tadigan yumshoq jilva (shimmer).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, required this.highlight});
  final Widget child;
  final Color highlight;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  AnimationController? _ctl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context)) {
      _ctl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    } else {
      _ctl?.dispose();
      _ctl = null;
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    if (ctl == null) return widget.child;
    return AnimatedBuilder(
      animation: ctl,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) {
          final x = -1.5 + 3 * ctl.value;
          return LinearGradient(
            begin: Alignment(x - 0.6, -0.3),
            end: Alignment(x + 0.6, 0.3),
            colors: [widget.highlight.withValues(alpha: 0), widget.highlight.withValues(alpha: 0.55), widget.highlight.withValues(alpha: 0)],
          ).createShader(r);
        },
        child: child,
      ),
    );
  }
}

/// Asosiy amal tugmasi atrofida sekin "nafas oluvchi" halqa.
class Breathing extends StatefulWidget {
  const Breathing({super.key, required this.child, required this.color, this.size = 56});
  final Widget child;
  final Color color;
  final double size;
  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  AnimationController? _ctl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ambientMotion(context)) {
      _ctl ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    } else {
      _ctl?.dispose();
      _ctl = null;
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    if (ctl == null) return widget.child;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      IgnorePointer(
        child: AnimatedBuilder(
          animation: ctl,
          builder: (context, _) {
            final k = Curves.easeOut.transform(ctl.value);
            return Container(
              width: widget.size + 14 * k,
              height: widget.size + 14 * k,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.28 * (1 - k))),
            );
          },
        ),
      ),
      widget.child,
    ]);
  }
}

/// Bo'limlar (pastki menyu) orasida: yangi sahifa eskisining ustida yumshoq paydo bo'ladi va 1,5% kattalashadi.
class FadeThroughPage<T> extends CustomTransitionPage<T> {
  FadeThroughPage({required super.child, super.key})
      : super(
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondary, child) {
            if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
            final a = CurvedAnimation(parent: animation, curve: AppMotion.standard);
            return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(a), child: child));
          },
        );
}
