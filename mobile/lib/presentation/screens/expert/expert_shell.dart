import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav.dart' show Breakpoints;
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

typedef _ExpertNavItem = (String route, String label, IconData icon, IconData activeIcon, int count);

List<_ExpertNavItem> _expertItems(ExpertStats? stats) => [
      ('/expert', tr('Navbat'), Icons.assignment_outlined, Icons.assignment_rounded, stats?.queuePending ?? 0),
      ('/expert/questions', tr('Savollar'), Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, stats?.questionsNew ?? 0),
      ('/expert/community', tr('Jamoat'), Icons.groups_outlined, Icons.groups_rounded, 0),
      ('/expert/kb', tr('Bilimlar'), Icons.menu_book_outlined, Icons.menu_book_rounded, 0),
      ('/expert/profile', tr('Profil'), Icons.person_outline_rounded, Icons.person_rounded, 0),
    ];

/// Agronom rejimi menyusi (Agronom TZ 4): Navbat · Savollar · Jamoat · Bilimlar · Profil. Faol rang — brand (to'q yashil).
class ExpertBottomNav extends ConsumerWidget {
  const ExpertBottomNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final stats = ref.watch(expertStatsProvider).value;
    Widget badge(int n, Widget child) =>
        n <= 0 ? child : Badge(label: Text(n > 99 ? '99+' : '$n'), backgroundColor: c.primary, textColor: c.onPrimary, child: child);

    Widget item(String route, String label, IconData icon, IconData activeIcon, [int count = 0]) {
      final active = current == route;
      final color = active ? c.olive : c.muted;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: count > 0 ? trf('{0}, {1} ta yangi', [label, count]) : label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: active ? null : () => context.go(route),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  badge(count, Icon(active ? activeIcon : icon, size: 24, color: color)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1, softWrap: false, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color)),
                  ),
                ],
              ),
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
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(children: [for (final it in _expertItems(stats)) item(it.$1, it.$2, it.$3, it.$4, it.$5)]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keng ekran (≥ 1024 px) uchun chap menyu (Agronom TZ 3.3): pastki menyu o'rnida.
class ExpertSideNav extends ConsumerWidget {
  const ExpertSideNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final stats = ref.watch(expertStatsProvider).value;
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AgroYordam', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
                  Text(tr('Agronom'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.olive)),
                ]),
              ),
            ]),
            const SizedBox(height: 24),
            for (final it in _expertItems(stats))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Semantics(
                  button: true,
                  selected: current == it.$1,
                  label: it.$5 > 0 ? trf('{0}, {1} ta yangi', [it.$2, it.$5]) : it.$2,
                  excludeSemantics: true,
                  child: Material(
                    color: current == it.$1 ? c.oliveSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: current == it.$1 ? null : () => context.go(it.$1),
                      child: SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            Icon(current == it.$1 ? it.$4 : it.$3, size: 22, color: current == it.$1 ? c.olive : c.text),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(it.$2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: current == it.$1 ? FontWeight.w800 : FontWeight.w600, color: current == it.$1 ? c.olive : c.text)),
                            ),
                            if (it.$5 > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(99)),
                                child: Text(it.$5 > 99 ? '99+' : '${it.$5}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.onPrimary)),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Agronom rejimi sarlavhasi: "AGRONOM REJIMI" yorlig'i + sarlavha + o'ng tomonda amal.
class ExpertHeader extends StatelessWidget {
  const ExpertHeader({super.key, required this.title, this.leading, this.trailing});
  final String title;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: c.olive),
                    const SizedBox(width: 4),
                    Text(
                      tr('AGRONOM REJIMI'),
                      style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: c.olive),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(title, style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Onlayn / oflayn: agronom yangi savollarni qabul qiladimi. Dehqonlar ro'yxatida shu ko'rinadi.
class OnlineToggle extends ConsumerStatefulWidget {
  const OnlineToggle({super.key});
  @override
  ConsumerState<OnlineToggle> createState() => _OnlineToggleState();
}

class _OnlineToggleState extends ConsumerState<OnlineToggle> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(expertRepoProvider).updateMe(acceptingQuestions: on);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) showToast(context, on ? tr('Onlayn: yangi savollar qabul qilinadi') : tr('Oflayn: dehqonlar sizni band deb ko\'radi'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = ref.watch(currentUserProvider)?.acceptingQuestions ?? true;
    final fg = on ? c.success : c.muted;
    return Semantics(
      button: true,
      toggled: on,
      label: on ? tr('Onlayn') : tr('Oflayn'),
      child: Material(
        color: on ? c.successBg : c.cream2,
        shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: 0.5), width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _busy ? null : () => _toggle(!on),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  on ? tr('Onlayn') : tr('Oflayn'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Raqamli ko'rsatkich kartochkasi (navbat va profil).
class StatTile extends StatelessWidget {
  const StatTile(this.value, this.label, {super.key});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: context.c.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 2),
          // Uzun so'z tor kartada bo'linib ketmasin: sig'masa kichrayadi
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label, style: TextStyle(fontSize: 12, color: context.c.muted, height: 1.25), maxLines: 2, softWrap: false),
          ),
        ],
      ),
    ),
  );
}

/// O'rtacha javob vaqti: "35 daq", "2 soat", "1 kun".
String formatWait(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return trf('{0} daq', [minutes]);
  if (minutes < 60 * 24) return trf('{0} soat', [(minutes / 60).round()]);
  return trf('{0} kun', [(minutes / 1440).round()]);
}

/// Agronom rejimidagi tab ekrani qobig'i.
class ExpertPage extends StatelessWidget {
  const ExpertPage({super.key, required this.current, required this.children, this.onRefresh});
  final String current;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    Widget body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: children);
    if (onRefresh != null) body = RefreshIndicator(color: context.c.primary, onRefresh: onRefresh!, child: body);
    final desktop = Breakpoints.isDesktop(context);
    final content = SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: body),
      ),
    );
    return Scaffold(
      backgroundColor: context.c.cream,
      bottomNavigationBar: desktop ? null : ExpertBottomNav(current: current),
      body: desktop
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ExpertSideNav(current: current), Expanded(child: content)])
          : content,
    );
  }
}

/// Filtr chiplari (agronom ekranlari): tanlangani to'q yashil.
class ExpertChips extends StatelessWidget {
  const ExpertChips({super.key, required this.tabs, required this.selected, required this.onSelect});
  final List<(String, String)> tabs;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (id, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: selected == id,
                button: true,
                child: Material(
                  color: selected == id ? c.olive : c.card,
                  shape: StadiumBorder(side: BorderSide(color: selected == id ? c.olive : c.border)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelect(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected == id ? c.onOlive : c.text)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
