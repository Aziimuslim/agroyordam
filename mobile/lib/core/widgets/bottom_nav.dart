import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Pastki navigatsiya: Bosh sahifa, Bog'im, [Tashxis kamerasi], Jamoat, Profil.
/// Eslatmalar — ekin sahifasida, bosh sahifadagi "Bugungi vazifalar"da va Profil menyusida.
/// Dizayn: Figma "Yashil dala" — faol bo'lim yumshoq yashil "pill" ichida, markazda suzuvchi kamera tugmasi.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget item(String route, String label, IconData icon) {
      final active = current == route;
      final color = active ? c.primary : c.muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go(route),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: active ? c.primaryLight : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                item('/home', 'Bosh sahifa', AppIcons.home),
                item('/garden', "Bog'im", AppIcons.leaf),
                SizedBox(
                  width: 76,
                  height: 54,
                  child: OverflowBox(
                    maxHeight: 90,
                    alignment: Alignment.center,
                    child: Tooltip(
                      message: 'AI Tashxis',
                      child: Transform.translate(
                        offset: const Offset(0, -18),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.card, width: 4),
                            boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                          ),
                          child: Material(
                            color: c.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => context.push('/diagnose'),
                              child: SizedBox(width: 58, height: 58, child: Icon(AppIcons.camera, color: c.card, size: 26)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                item('/community', 'Jamoat', AppIcons.users),
                item('/profile', 'Profil', AppIcons.sliders),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
