import 'package:flutter/material.dart';

/// Yashil dala 2.0 — harakat tokenlari va sahifa o'tishlari (docs/redesign: Motion).
class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const page = Duration(milliseconds: 360);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const enter = Cubic(0.05, 0.7, 0.1, 1);
  static const exit = Cubic(0.3, 0, 0.8, 0.15);
}

/// Oldinga/orqaga: yangi sahifa o'ngdan 30% siljib kiradi, eskisi chapga 12% ketib xiralashadi.
/// "Harakatni kamaytirish" yoqilgan bo'lsa — oddiy almashinuv.
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final inCurve = CurvedAnimation(parent: animation, curve: AppMotion.enter, reverseCurve: AppMotion.enter.flipped);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.enter, reverseCurve: AppMotion.enter.flipped);
    return SlideTransition(
      position: Tween(begin: const Offset(0.3, 0), end: Offset.zero).animate(inCurve),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.12, 0)).animate(outCurve),
          child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.5))), child: child),
        ),
      ),
    );
  }
}

/// Pastki menyu bo'limlari: fade-through (eski tez yo'qoladi, yangi 0.98 dan kattalashib chiqadi).
Widget fadeThrough(Animation<double> animation, Widget child) {
  final a = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: AppMotion.enter));
  return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(a), child: child));
}
