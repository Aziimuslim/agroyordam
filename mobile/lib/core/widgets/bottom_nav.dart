import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Pastki navigatsiya: Bosh sahifa, Bog'im, [Tashxis kamerasi], Eslatmalar, Profil.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(String route, String label, IconData icon) {
      final active = current == route;
      return Expanded(
        child: InkWell(
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 24, color: active ? c.primary : c.muted),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: active ? c.primary : c.muted)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: c.card, boxShadow: [BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                item('/home', 'Bosh sahifa', AppIcons.home),
                item('/garden', "Bog'im", AppIcons.leaf),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Tooltip(
                      message: 'AI Tashxis',
                      child: Transform.translate(
                        offset: const Offset(0, -16),
                        child: Material(
                          color: c.primary,
                          shape: const CircleBorder(),
                          elevation: 6,
                          shadowColor: c.primary.withValues(alpha: 0.5),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => context.push('/diagnose'),
                            child: SizedBox(width: 56, height: 56, child: Icon(AppIcons.camera, color: c.card, size: 26)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                item('/reminders', 'Eslatmalar', AppIcons.bell),
                item('/profile', 'Profil', AppIcons.sliders),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
