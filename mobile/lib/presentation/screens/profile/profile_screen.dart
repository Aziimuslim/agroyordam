import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/app_mode.dart';
import '../../../application/lang.dart';
import '../../../application/providers.dart';
import '../../../application/theme_mode.dart';
import '../../../core/config.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';

/// S23 Profil: hisob, faoliyat va sozlamalar guruhlari. Statistika serverdan (ekin, post), "Kun faol" — ro'yxatdan
/// o'tgan kundan. Chiqish tasdiq bilan; shaxsiy kesh tozalanadi, mavzu va til qoladi. Saqlanganlar (A02) — API yo'q.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final crops = ref.watch(cropsProvider);
    final profile = ref.watch(profileProvider(user.id));
    final days = user.createdAt == null ? null : DateTime.now().difference(user.createdAt!).inDays + 1;
    final mode = ref.watch(themeModeProvider);
    final premiumLabel = user.isPremium
        ? (user.premiumUntil != null && user.premiumUntil!.year < 2100 ? trf('Premium · {0} gacha', [formatDate(user.premiumUntil)]) : tr('Premium · muddatsiz'))
        : tr('Bepul reja');

    Widget group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Semantics(header: true, child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.3))),
          ),
          ...rows,
        ]);

    return PageShell(
      bottom: const AppBottomNav(current: '/profile'),
      maxWidth: 760,
      onRefresh: () async {
        await ref.read(authProvider.notifier).refreshUser();
        ref.invalidate(cropsProvider);
        ref.invalidate(profileProvider(user.id));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text(tr('Profil'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text))),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: trf("{0}, shaxsiy ma'lumotlarni tahrirlash", [user.fullName]),
          excludeSemantics: true,
          child: Material(
            color: c.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/profile/edit'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Avatar(name: user.fullName, url: user.avatarUrl, size: 64, color: c.olive, textColor: c.onOlive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text)),
                      Text(['@${user.username}', placeText(user.region, user.district)].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted)),
                      const SizedBox(height: 4),
                      Text(premiumLabel, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: user.isPremium ? c.olive : c.muted)),
                    ]),
                  ),
                  Icon(AppIcons.edit, color: c.muted),
                ]),
              ),
            ),
          ),
        ),
        if (!user.isExpert && !user.hasFarmInfo) ...[
          const SizedBox(height: 12),
          RowCard(
            leading: ThumbIcon(icon: Icons.agriculture_outlined, bg: c.oliveSoft, fg: c.olive),
            title: tr("Xo'jaligingiz haqida yozing"),
            subtitle: tr("Maydon, ekinlar, sug'orish — agronom aniqroq maslahat beradi"),
            trailing: Icon(AppIcons.chevron, color: c.muted),
            onTap: () => context.push('/profile/edit'),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Row(children: [
            _Stat(crops.value?.length, tr('Ekin'), loading: crops.isLoading && !crops.hasValue),
            _Stat(profile.value?.posts, tr('Post'), loading: profile.isLoading && !profile.hasValue),
            _Stat(days, tr('Kun faol')),
          ]),
        ),
        const SizedBox(height: 4),
        const _ExpertEntry(),
        group(tr('Hisob'), [
          ListRow(icon: Icons.person_outline_rounded, label: tr("Shaxsiy ma'lumotlar"), onTap: () => context.push('/profile/edit')),
          ListRow(icon: Icons.lock_outline_rounded, label: tr('Parol va xavfsizlik'), onTap: () => context.push('/profile/password')),
          ListRow(icon: AppIcons.star, label: tr('Obunam'), value: user.isPremium ? 'Premium' : tr('Bepul'), onTap: () => context.push('/premium')),
          ListRow(icon: AppIcons.card, label: tr("To'lovlar tarixi"), onTap: () => context.push('/premium/payments')),
        ]),
        group(tr('Faoliyat'), [
          ListRow(icon: AppIcons.history, label: tr('Tashxislar tarixi'), onTap: () => context.push('/diagnoses')),
          ListRow(icon: AppIcons.bell, label: tr('Eslatmalar va vazifalar'), onTap: () => context.push('/reminders')),
          ListRow(icon: AppIcons.chat, label: tr('Xabarlar'), onTap: () => context.push('/messages')),
          ListRow(icon: Icons.notifications_none_rounded, label: tr('Bildirishnomalar'), onTap: () => context.push('/notifications')),
          ListRow(icon: Icons.article_outlined, label: tr('Mening postlarim'), onTap: () => context.push('/users/${user.id}')),
          ListRow(icon: AppIcons.book, label: tr("Ma'lumotnoma"), value: tr("O'simlik, kasallik, dori"), onTap: () => context.push('/catalog')),
        ]),
        group(tr('Sozlamalar'), [
          ListRow(
            icon: Icons.palette_outlined,
            label: tr("Ko'rinish"),
            value: switch (mode) { ThemeMode.dark => tr("Qorong'i"), ThemeMode.light => tr("Yorug'"), _ => tr('Tizimga mos') },
            onTap: () => context.push('/settings/appearance'),
          ),
          ListRow(icon: AppIcons.globe, label: tr('Ilova tili'), value: ref.watch(langProvider).label, onTap: () => context.push('/settings/language')),
          ListRow(icon: Icons.info_outline_rounded, label: tr('Ilova haqida'), value: AppConfig.version, onTap: () => context.push('/settings/about')),
          if (user.isAdmin)
            ListRow(
              icon: AppIcons.shield,
              label: tr('Admin panel'),
              value: tr('Kompyuterda'),
              onTap: () => launchUrl(Uri.parse('${AppConfig.apiUrl}/admin/'), mode: LaunchMode.externalApplication),
            ),
        ]),
        const SizedBox(height: 10),
        ListRow(
          icon: AppIcons.logout,
          label: tr('Chiqish'),
          danger: true,
          chevron: false,
          onTap: () async {
            if (await confirm(context, tr('Chiqish'), tr("Hisobdan chiqasizmi? Shu qurilmadagi shaxsiy ma'lumotlar tozalanadi."), ok: tr('Chiqish'), danger: true)) {
              await ref.read(authProvider.notifier).logout();
            }
          },
        ),
        const SizedBox(height: 18),
        Center(child: Text(trf('Versiya {0}', [AppConfig.version]), style: TextStyle(color: c.muted, fontSize: 13))),
      ]),
    );
  }
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
        (ThemeMode.light, Icons.light_mode_outlined, tr("Yorug'")),
        (ThemeMode.dark, Icons.dark_mode_outlined, tr("Qorong'i")),
        (ThemeMode.system, Icons.brightness_auto_outlined, tr('Tizimga qarab')),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: mode == m ? accent : c.text)),
                      ),
                    ),
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
              Text(tr("Agronom rejimiga o'tish"), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: c.expert)),
              Text(tr('Navbat, savollar va bilimlar bazasi'), style: TextStyle(fontSize: 13, color: c.text)),
            ]),
          ),
          Icon(AppIcons.chevron, color: c.expert),
        ]),
      );
    }
    final app = ref.watch(myApplicationProvider).value;
    if (app != null && app.pending) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: NoteBox(title: tr("Agronom arizangiz ko'rib chiqilmoqda"), text: tr('Javob 1–2 kunda bildirishnoma bo\'lib keladi.'), icon: Icons.hourglass_top_rounded),
      );
    }
    return Column(children: [
      if (app != null && app.status == 'rejected')
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: NoteBox(kind: NoteKind.risk, title: tr('Oldingi ariza rad etildi'), text: app.reason),
        ),
      ListRow(icon: Icons.verified_user_outlined, label: tr('Men agronomman'), value: tr('Ariza'), onTap: () => context.push('/profile/expert')),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.loading = false});
  final int? value;
  final String label;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value == null ? (loading ? '…' : '—') : '$value';
    return Expanded(
      child: Semantics(
        label: '$v $label',
        excludeSemantics: true,
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
          Text(label, style: TextStyle(fontSize: 14, color: c.muted)),
        ]),
      ),
    );
  }
}
