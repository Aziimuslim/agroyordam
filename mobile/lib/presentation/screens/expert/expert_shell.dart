import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Agronom rejimi menyusi: Savollar · Jamoat · [Navbat] · Bilimlar · Profil. Faol rang — tuproq (expert).
class ExpertBottomNav extends ConsumerWidget {
  const ExpertBottomNav({super.key, required this.current});
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final stats = ref.watch(expertStatsProvider).value;
    Widget badge(int n, Widget child) =>
        n <= 0 ? child : Badge(label: Text(n > 99 ? '99+' : '$n'), backgroundColor: c.danger, textColor: c.card, child: child);

    Widget item(String route, String label, IconData icon, [int count = 0]) {
      final active = current == route;
      final color = active ? c.expert : c.muted;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: active ? c.expertBg : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                    child: badge(count, Icon(icon, size: 22, color: color)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final queueActive = current == '/expert';
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  item('/expert/questions', 'Savollar', Icons.inbox_outlined, stats?.questionsNew ?? 0),
                  item('/expert/community', 'Jamoat', AppIcons.users),
                  SizedBox(
                    width: 76,
                    height: 54,
                    child: OverflowBox(
                      maxHeight: 90,
                      alignment: Alignment.center,
                      child: Semantics(
                        button: true,
                        selected: queueActive,
                        label: 'Navbat',
                        child: Transform.translate(
                          offset: const Offset(0, -14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.card, width: 4),
                                  boxShadow: [BoxShadow(color: c.expert.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                                ),
                                child: badge(
                                  stats?.queuePending ?? 0,
                                  Material(
                                    color: c.expert,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => context.go('/expert'),
                                      child: SizedBox(width: 56, height: 56, child: Icon(Icons.verified_user_outlined, color: c.onExpert, size: 26)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Navbat',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: queueActive ? FontWeight.w800 : FontWeight.w600,
                                  color: queueActive ? c.expert : c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  item('/expert/kb', 'Bilimlar', AppIcons.book),
                  item('/expert/profile', 'Profil', AppIcons.user),
                ],
              ),
            ),
          ),
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
                    Icon(Icons.verified_user_outlined, size: 14, color: c.expert),
                    const SizedBox(width: 4),
                    Text(
                      'AGRONOM REJIMI',
                      style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: c.expert),
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
      if (mounted) showToast(context, on ? 'Onlayn: yangi savollar qabul qilinadi' : 'Oflayn: dehqonlar sizni band deb ko\'radi');
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
      label: on ? 'Onlayn' : 'Oflayn',
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
                  on ? 'Onlayn' : 'Oflayn',
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
          Text(label, style: TextStyle(fontSize: 12, color: context.c.muted, height: 1.25), maxLines: 2),
        ],
      ),
    ),
  );
}

/// O'rtacha javob vaqti: "35 daq", "2 soat", "1 kun".
String formatWait(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '$minutes daq';
  if (minutes < 60 * 24) return '${(minutes / 60).round()} soat';
  return '${(minutes / 1440).round()} kun';
}

/// Agronom rejimidagi tab ekrani qobig'i.
class ExpertPage extends StatelessWidget {
  const ExpertPage({super.key, required this.current, required this.children, this.onRefresh});
  final String current;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    Widget body = ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: children);
    if (onRefresh != null) body = RefreshIndicator(color: context.c.expert, onRefresh: onRefresh!, child: body);
    return Scaffold(
      backgroundColor: context.c.cream,
      bottomNavigationBar: ExpertBottomNav(current: current),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: body),
        ),
      ),
    );
  }
}
