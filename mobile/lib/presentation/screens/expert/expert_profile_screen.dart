import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/app_mode.dart';
import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../profile/profile_screen.dart';
import 'expert_shell.dart';

/// Agronom profili: reyting, javoblar, o'rtacha javob vaqti, ish vaqti, mutaxassislik, mavzu.
class ExpertProfileScreen extends ConsumerWidget {
  const ExpertProfileScreen({super.key});

  Future<void> _editText(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initial,
    required String hint,
    required Future<void> Function(String) save,
  }) async {
    final ctl = TextEditingController(text: initial);
    final ok = await showSheet<bool>(
      context,
      title: title,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctl,
            autofocus: true,
            maxLength: 100,
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 12),
          PillButton(label: 'Saqlash', style: PillStyle.dark, block: true, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    final v = ctl.text.trim();
    ctl.dispose();
    if (ok != true || v.isEmpty) return;
    try {
      await save(v);
      await ref.read(authProvider.notifier).refreshUser();
      if (context.mounted) showToast(context, 'Saqlandi');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final s = ref.watch(expertStatsProvider).value;
    final repo = ref.read(expertRepoProvider);
    return ExpertPage(
      current: '/expert/profile',
      onRefresh: () async {
        ref.invalidate(expertStatsProvider);
        await ref.read(authProvider.notifier).refreshUser();
      },
      children: [
        const ExpertHeader(title: 'Profil'),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.expert, width: 2.5),
              ),
              child: Avatar(name: user.fullName, url: user.avatarUrl, size: 68, color: c.expertBg, textColor: c.expert),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(['Agronom', user.specialization].whereType<String>().join(' · '), style: TextStyle(color: c.muted, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 18, color: c.gold),
                      const SizedBox(width: 3),
                      Text(s?.rating?.toStringAsFixed(1) ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(' · ${s?.ratingsCount ?? 0} baho', style: TextStyle(color: c.muted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatTile('${s?.answers ?? '—'}', 'javob'),
            const SizedBox(width: 8),
            StatTile('${s?.reviewedTotal ?? '—'}', 'tekshirilgan\ntashxis'),
            const SizedBox(width: 8),
            StatTile(formatWait(s?.avgAnswerMinutes), "o'rtacha\njavob"),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Column(
            children: [
              _Row(
                icon: AppIcons.clock,
                label: 'Ish vaqti',
                value: user.workHours ?? "Ko'rsatilmagan",
                onTap: () => _editText(
                  context,
                  ref,
                  title: 'Ish vaqti',
                  initial: user.workHours ?? '',
                  hint: 'Du–Ju, 9:00–18:00',
                  save: (v) => repo.updateMe(workHours: v),
                ),
              ),
              Divider(height: 1, color: c.border),
              _Row(
                icon: AppIcons.leaf,
                label: 'Mutaxassislik',
                value: user.specialization ?? "Ko'rsatilmagan",
                onTap: () => _editText(
                  context,
                  ref,
                  title: 'Mutaxassislik',
                  initial: user.specialization ?? '',
                  hint: 'Mevali daraxtlar, sabzavotlar',
                  save: (v) => repo.updateMe(specialization: v),
                ),
              ),
              Divider(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 34, child: Icon(Icons.inbox_outlined, color: c.expert)),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yangi savollar qabul qilish', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          Text("O'chirsangiz, dehqonlar sizni «Oflayn» ko'radi", style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Switch(
                      value: user.acceptingQuestions,
                      activeTrackColor: c.expert,
                      onChanged: (v) async {
                        try {
                          await repo.updateMe(acceptingQuestions: v);
                          await ref.read(authProvider.notifier).refreshUser();
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text('MAVZU', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        const ThemePicker(expert: true),
        const SizedBox(height: 16),
        ListRow(
          icon: AppIcons.home,
          label: "Dehqon rejimiga o'tish",
          value: "Bog'im, tashxis",
          onTap: () async {
            await ref.read(expertModePrefProvider.notifier).set(false);
            if (context.mounted) context.go('/home');
          },
        ),
        ListRow(icon: AppIcons.edit, label: "Ma'lumotlarim", value: "Tajriba, ta'lim, yo'nalish", onTap: () => context.push('/profile/edit')),
        ListRow(icon: Icons.visibility_outlined, label: "Dehqonlar ko'radigan profil", onTap: () => context.push('/help/agronom/${user.id}')),
        ListRow(icon: Icons.notifications_none_rounded, label: 'Bildirishnomalar', onTap: () => context.push('/notifications')),
        ListRow(icon: AppIcons.chat, label: 'Xabarlar', onTap: () => context.push('/messages')),
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
        const SizedBox(height: 10),
        Center(
          child: Text('Versiya ${AppConfig.version}', style: TextStyle(color: c.muted, fontSize: 11)),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 34, child: Icon(icon, color: c.expert)),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(color: c.muted, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(AppIcons.chevron, color: c.muted),
          ],
        ),
      ),
    );
  }
}
