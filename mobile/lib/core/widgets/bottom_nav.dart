import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'brand.dart';

/// TZ 2.3 o'lcham chegaralari: telefon < 600, planshet 600–1023, desktop ≥ 1024.
abstract final class Breakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;
  static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;
}

typedef _NavItem = (String route, String label, IconData icon, IconData activeIcon);

List<_NavItem> _items() => [
      ('/home', tr('Bosh sahifa'), Icons.home_outlined, Icons.home_rounded),
      ('/garden', tr("Bog'im"), Icons.eco_outlined, Icons.eco_rounded),
      ('/help', tr('Maslahat'), Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
      ('/profile', tr('Profil'), Icons.person_outline_rounded, Icons.person_rounded),
    ];

/// Pastki navigatsiya (TZ 3.1): Bosh sahifa, Bog'im, [Tekshirish], Maslahat, Profil.
/// Faol bo'lim — terrakota ikonka va yozuv; markazda terrakota doira ichida skaner (S03).
/// Desktop (≥ 1024) da ko'rinmaydi — o'rniga [AppSideNav] chiqadi ([NavFrame] orqali).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isDesktop(context)) return const SizedBox.shrink();
    final c = context.c;
    final items = _items();
    Widget item(_NavItem it) {
      final active = current == it.$1;
      final color = active ? c.primary : c.muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: it.$2,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: active ? null : () => context.go(it.$1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(active ? it.$4 : it.$3, size: 24, color: color),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(it.$2,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color)),
                ),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            item(items[0]),
            item(items[1]),
            const _ScanButton(),
            item(items[2]),
            item(items[3]),
          ]),
        ),
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Balandlik qat'iy: bottomNavigationBar butun ekran balandligini cheklov sifatida beradi
    return SizedBox(
      width: 76,
      height: 64,
      child: Semantics(
        button: true,
        label: tr('Ekinni tekshirish'),
        excludeSemantics: true,
        child: Tooltip(
          message: tr('Ekinni tekshirish'),
          child: Center(
            child: Material(
              color: c.primary,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/diagnose'),
                child: SizedBox(width: 56, height: 56, child: Icon(AppIcons.scan, color: c.onPrimary, size: 28)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop yon navigatsiyasi (TZ 2.3: ≥ 1024 — yon panel, kontent 1200 gacha).
class AppSideNav extends StatelessWidget {
  const AppSideNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 248,
      decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.border))),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const BrandLogo(size: 36),
              const SizedBox(width: 10),
              Flexible(
                child: Text('AgroYordam',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/diagnose'),
                icon: const Icon(AppIcons.scan),
                label: Text(tr('Ekinni tekshirish'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 16),
            for (final it in _items()) _SideItem(item: it, active: current == it.$1),
          ]),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.item, required this.active});
  final _NavItem item;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = active ? c.primary : c.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: active,
        label: item.$2,
        excludeSemantics: true,
        child: Material(
          color: active ? c.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: active ? null : () => context.go(item.$1),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Icon(active ? item.$4 : item.$3, color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asosiy bo'lim ekranlari uchun: desktopda chapda [AppSideNav], aks holda faqat [child].
class NavFrame extends StatelessWidget {
  const NavFrame({super.key, required this.current, required this.child});
  final String current;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!Breakpoints.isDesktop(context)) return child;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppSideNav(current: current),
      Expanded(child: child),
    ]);
  }
}
