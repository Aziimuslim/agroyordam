import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/app_mode.dart';
import '../../../application/providers.dart';
import '../../../application/theme_mode.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../auth/server_settings.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final crops = ref.watch(cropsProvider).value?.length ?? 0;
    final reminders = ref.watch(remindersProvider).value?.length ?? 0;
    final days = user.createdAt == null ? 1 : DateTime.now().difference(user.createdAt!).inDays + 1;
    final myPosts = ref.watch(userPostsProvider(user.id));
    final mode = ref.watch(themeModeProvider);

    return PageShell(
      bottom: const AppBottomNav(current: '/profile'),
      onRefresh: () async {
        await ref.read(authProvider.notifier).refreshUser();
        ref.invalidate(userPostsProvider(user.id));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Profil', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Center(
          child: Column(children: [
            Avatar(name: user.fullName, url: user.avatarUrl, size: 84, color: c.primary),
            const SizedBox(height: 12),
            Text(user.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text('@${user.username}', style: TextStyle(color: c.muted)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => context.push('/profile/edit'),
              child: Text('Profilni tahrirlash', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          _Stat('$crops', 'Ekin'),
          const SizedBox(width: 10),
          _Stat('$reminders', 'Eslatma'),
          const SizedBox(width: 10),
          _Stat('$days', 'Kun faol'),
        ]),
        const SizedBox(height: 18),
        RowCard(
          dark: true,
          leading: ThumbIcon(icon: AppIcons.star, bg: c.onDark.withValues(alpha: 0.14), fg: c.gold),
          title: 'Obunam',
          subtitle: 'Joriy reja: ${user.isPremium ? 'Premium${user.premiumUntil != null && user.premiumUntil!.year < 2100 ? ' (${formatDate(user.premiumUntil)} gacha)' : ''}' : "Bepul · Premium'ga o'ting"}',
          trailing: Icon(AppIcons.chevron, color: c.onDark),
          onTap: () => context.push('/premium'),
        ),
        const SizedBox(height: 4),
        const _ExpertEntry(),
        SectionTitle('Mening postlarim', action: "Jamoatda ko'rish", onAction: () => context.go('/help?tab=comm')),
        myPosts.maybeWhen(
          data: (posts) => posts.isEmpty
              ? const EmptyNote("Hali post yo'q")
              : RowCard(
                  leading: ThumbIcon(icon: AppIcons.leaf, imageUrl: posts.first.imageUrl),
                  title: posts.first.title,
                  subtitle: timeAgo(posts.first.createdAt),
                  trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${posts.first.likes} layk', style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 12)),
                    Text('${posts.first.comments} izoh', style: TextStyle(color: c.muted, fontSize: 12)),
                  ]),
                  onTap: () => context.push('/community/${posts.first.id}'),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
        ListRow(icon: AppIcons.history, label: 'Tashxislar tarixi', onTap: () => context.push('/diagnoses')),
        ListRow(icon: AppIcons.bell, label: 'Eslatmalar va vazifalar', onTap: () => context.push('/reminders')),
        ListRow(icon: AppIcons.chat, label: 'Xabarlar', onTap: () => context.push('/messages')),
        ListRow(icon: Icons.notifications_none_rounded, label: 'Bildirishnomalar', onTap: () => context.push('/notifications')),
        ListRow(icon: AppIcons.book, label: "Ma'lumotnoma", value: "O'simlik, kasallik, dori", onTap: () => context.push('/catalog')),
        ListRow(
          icon: Icons.dark_mode_outlined,
          label: 'Mavzu',
          value: switch (mode) { ThemeMode.dark => "Qorong'i", ThemeMode.light => "Yorug'", _ => 'Tizim' },
          onTap: () => _themeSheet(context, ref),
        ),
        ListRow(icon: Icons.dns_outlined, label: 'Server manzili', onTap: () => showServerSettings(context, ref)),
        ListRow(icon: AppIcons.globe, label: 'Til', value: "O'zbekcha", onTap: () => showToast(context, "Hozircha faqat o'zbek tili")),
        if (user.isAdmin)
          ListRow(
            icon: AppIcons.shield,
            label: 'Admin panel',
            value: 'Kompyuterda',
            onTap: () => launchUrl(Uri.parse('${AppConfig.apiUrl}/admin/'), mode: LaunchMode.externalApplication),
          ),
        ListRow(
          icon: AppIcons.logout,
          label: 'Chiqish',
          danger: true,
          onTap: () async {
            if (await confirm(context, 'Chiqish', 'Hisobdan chiqmoqchimisiz?', ok: 'Chiqish', danger: true)) {
              await ref.read(authProvider.notifier).logout();
            }
          },
        ),
        const SizedBox(height: 18),
        Center(child: Text('AGROYORDAM', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 12))),
        Center(child: Text('Versiya ${AppConfig.version} · Barcha huquqlar himoyalangan.', style: TextStyle(color: c.muted, fontSize: 11))),
      ]),
    );
  }
}

void _themeSheet(BuildContext context, WidgetRef ref) {
  showSheet(context, title: 'Mavzu', builder: (ctx) => const ThemePicker());
}

/// Mavzu tanlash: yorug' / qorong'i / tizimga qarab. Agronom rejimida faol rang — tuproq.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key, this.expert = false});
  final bool expert;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final c = context.c;
    final (accent, accentBg) = expert ? (c.expert, c.expertBg) : (c.primary, c.primaryLight);
    return Row(children: [
      for (final (m, icon, label) in [
        (ThemeMode.light, Icons.light_mode_outlined, "Yorug'"),
        (ThemeMode.dark, Icons.dark_mode_outlined, "Qorong'i"),
        (ThemeMode.system, Icons.brightness_auto_outlined, 'Tizimga qarab'),
      ]) ...[
        if (m != ThemeMode.light) const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            selected: mode == m,
            button: true,
            child: Material(
              color: mode == m ? accentBg : c.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14), side: BorderSide(color: mode == m ? accent : c.lineStrong, width: 1.5)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => ref.read(themeModeProvider.notifier).set(m),
                child: SizedBox(
                  height: 76,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: mode == m ? accent : c.text),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: mode == m ? accent : c.text)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// "Men agronomman": ariza yuborish yoki holatini ko'rish. Agronom bo'lsa — agronom rejimi haqida.
class _ExpertEntry extends ConsumerWidget {
  const _ExpertEntry();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    if (user.canReview) {
      final c = context.c;
      return AppCard(
        color: c.expertBg,
        shadow: false,
        onTap: () async {
          await ref.read(expertModePrefProvider.notifier).set(true);
          if (context.mounted) context.go('/expert');
        },
        child: Row(children: [
          Icon(Icons.verified_user_outlined, color: c.expert),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Agronom rejimiga o'tish", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.expert)),
              Text('Navbat, savollar va bilimlar bazasi', style: TextStyle(fontSize: 13, color: c.text)),
            ]),
          ),
          Icon(AppIcons.chevron, color: c.expert),
        ]),
      );
    }
    final app = ref.watch(myApplicationProvider).value;
    if (app != null && app.pending) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: NoteBox(title: "Agronom arizangiz ko'rib chiqilmoqda", text: 'Javob 1–2 kunda bildirishnoma bo\'lib keladi.', icon: Icons.hourglass_top_rounded),
      );
    }
    return Column(children: [
      if (app != null && app.status == 'rejected')
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoteBox(kind: NoteKind.risk, title: 'Oldingi ariza rad etildi', text: app.reason),
        ),
      ListRow(icon: Icons.verified_user_outlined, label: 'Men agronomman', value: 'Ariza', onTap: () => context.push('/profile/expert')),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.c.primary)),
            Text(label, style: TextStyle(fontSize: 11.5, color: context.c.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
