import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/widgets.dart';
import '../garden/garden_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    final crops = ref.watch(cropsProvider);
    final notes = ref.watch(notificationsProvider);
    final unread = notes.value?.where((n) => !n.isRead).length ?? 0;

    return PageShell(
      bottom: const AppBottomNav(current: '/home'),
      onRefresh: () async {
        ref.invalidate(cropsProvider);
        ref.invalidate(notificationsProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: user?.fullName ?? '?', url: user?.avatarUrl, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text('Ekinlaringiz bugun sizni kutmoqda', style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
          CircleIconButton(icon: AppIcons.bell, badge: unread > 0, tooltip: 'Bildirishnomalar', onTap: () => context.push('/notifications')),
        ]),
        const SizedBox(height: 20),
        _Hero(onTap: () => context.push('/diagnose')),
        const SectionTitle("Bo'limlar"),
        Row(children: [
          _Chip3(icon: AppIcons.plant, label: "O'simliklar", onTap: () => context.push('/catalog?tab=plants')),
          const SizedBox(width: 10),
          _Chip3(icon: AppIcons.virus, label: 'Kasalliklar', onTap: () => context.push('/catalog?tab=diseases')),
          const SizedBox(width: 10),
          _Chip3(icon: AppIcons.pill, label: 'Dorilar', onTap: () => context.push('/catalog?tab=medicines')),
        ]),
        const SizedBox(height: 18),
        RowCard(
          leading: ThumbIcon(icon: AppIcons.bot, bg: c.primaryLight),
          title: 'AI bot bilan suhbat',
          subtitle: 'Savolingizni yozing — bilimlar bazasidan javob',
          trailing: Icon(AppIcons.chevron, color: c.muted),
          onTap: () => context.push('/assistant'),
        ),
        SectionTitle("Mening bog'im", action: "Barchasini ko'rish", onAction: () => context.go('/garden')),
        AsyncView(
          value: crops,
          onRetry: () => ref.invalidate(cropsProvider),
          data: (list) => list.isEmpty
              ? AppCard(
                  onTap: () => context.push('/garden/add'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text("Hali ekin qo'shilmagan.", textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
                    const SizedBox(height: 4),
                    Text("+ Ekin qo'shish", textAlign: TextAlign.center, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
                  ]),
                )
              : Column(children: [for (final crop in list.take(2)) CropRowCard(crop: crop)]),
        ),
        RowCard(
          dark: true,
          leading: ThumbIcon(icon: AppIcons.chat, bg: c.card.withValues(alpha: 0.12), fg: c.card),
          title: 'Jamoat',
          subtitle: "Boshqa fermerlarning natijalarini ko'ring",
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text('YANGI', style: TextStyle(color: c.onGold, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          onTap: () => context.push('/community'),
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary, c.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: c.primaryDark.withValues(alpha: 0.28), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("O'simlik holatini biling", style: TextStyle(color: c.card, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text("Rasmga oling — tahlil va tavsiya darhol tayyor bo'ladi",
            style: TextStyle(color: c.card.withValues(alpha: 0.92), fontSize: 14, height: 1.4)),
        const SizedBox(height: 18),
        PillButton(label: 'Tashxis boshlash', icon: AppIcons.camera, style: PillStyle.light, onPressed: onTap),
      ]),
    );
  }
}

class _Chip3 extends StatelessWidget {
  const _Chip3({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          onTap: onTap,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(children: [
            Icon(icon, color: context.c.primaryDark, size: 22),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ]),
        ),
      );
}
