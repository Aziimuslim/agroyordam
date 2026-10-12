import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'help_screen.dart' show ExpertAvatar;

/// Dehqon ko'radigan agronom profili: kimligi, tajribasi, ta'limi, yo'nalishlari.
class ExpertPublicScreen extends ConsumerWidget {
  const ExpertPublicScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(expertProvider(id));
    final me = ref.watch(currentUserProvider);
    final e = value.value;
    final self = me?.id == id;
    return PageShell(
      padBottom: false,
      bottom: e == null || self
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: PillButton(
                      label: tr('Savol berish'),
                      icon: Icons.chat_bubble_outline_rounded,
                      style: PillStyle.primary,
                      block: true,
                      onPressed: () => context.push('/help/ask'),
                    ),
                  ),
                ),
              ),
            ),
      onRefresh: () async => ref.invalidate(expertProvider(id)),
      child: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(expertProvider(id)),
        data: (e) => _Body(e: e, self: self),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.e, required this.self});
  final Expert e;
  final bool self;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final place = placeText(e.region, e.district);
    final info = <(IconData, String, String)>[
      if (place.isNotEmpty) (Icons.location_on_outlined, tr('Hudud'), place),
      if (e.workHours != null) (Icons.schedule_rounded, tr('Ish vaqti'), e.workHours!),
      if (e.education != null) (Icons.school_outlined, tr("Ta'lim"), e.education!),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TopBar(title: self ? tr("Dehqonlar shunday ko'radi") : tr('Agronom')),
      Center(
        child: Column(children: [
          ExpertAvatar(name: e.fullName, url: e.avatarUrl, size: 96),
          const SizedBox(height: 12),
          Text(e.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(e.specialization ?? tr('Agronom'), textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14.5)),
          const SizedBox(height: 8),
          StatusTag(e.acceptingQuestions ? tr('Onlayn · savol qabul qiladi') : tr('Hozir oflayn'),
              kind: e.acceptingQuestions ? StatusKind.healthy : StatusKind.neutral),
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [
        _Stat(value: e.rating?.toStringAsFixed(1) ?? '—', label: trf('{0} baho', [e.ratingsCount]), icon: Icons.star_rounded, iconColor: c.gold),
        const SizedBox(width: 8),
        _Stat(value: '${e.answers}', label: tr('javob')),
        const SizedBox(width: 8),
        _Stat(value: e.experienceYears == null ? '—' : trf('{0} yil', [e.experienceYears]), label: tr('tajriba')),
      ]),
      if (e.about != null) ...[
        const SizedBox(height: 20),
        Text(tr('MEN HAQIMDA'), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Text(e.about!, style: Theme.of(context).textTheme.bodyLarge),
      ],
      if (info.isNotEmpty) ...[
        const SizedBox(height: 18),
        AppCard(
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final (i, row) in info.indexed) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 32, child: Icon(row.$1, color: c.expert, size: 21)),
                  SizedBox(width: 82, child: Text(row.$2, style: TextStyle(color: c.muted, fontSize: 13.5))),
                  Expanded(child: Text(row.$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                ]),
              ),
            ],
          ]),
        ),
      ],
      if (e.skills.isNotEmpty) ...[
        Text(tr("YO'NALISHLAR"), style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in e.skills) StatusTag(s, kind: StatusKind.expert)]),
      ],
      if (self && e.about == null && e.skills.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: 16),
          child: NoteBox(
            kind: NoteKind.expert,
            title: tr("Profilingiz bo'sh ko'rinmoqda"),
            text: tr("«Ma'lumotlarim» bo'limida o'zingiz, tajribangiz va yo'nalishlaringiz haqida yozing — dehqonlar ishonchi ortadi."),
          ),
        ),
      const SizedBox(height: 16),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon, this.iconColor});
  final String value, label;
  final IconData? icon;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: context.c.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.c.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 18, color: iconColor), const SizedBox(width: 3)],
              Flexible(child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.15))),
            ]),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: context.c.muted)),
          ]),
        ),
      );
}
