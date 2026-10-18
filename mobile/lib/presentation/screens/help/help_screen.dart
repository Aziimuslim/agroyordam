import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../community/post_card.dart';

/// "Maslahat" — yordam olinadigan barcha joy: Agronomlar · AI yordamchi · Jamoat.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key, this.tab = 'agro'});
  final String tab;
  @override
  ConsumerState<HelpScreen> createState() => _HelpState();
}

class _HelpState extends ConsumerState<HelpScreen> {
  late String _tab = const {'agro', 'ai', 'comm'}.contains(widget.tab) ? widget.tab : 'agro';

  // Sahifa ochiq turganda havola boshqa bo'limga yuborsa (?tab=comm) — o'sha bo'limga o'tadi
  @override
  void didUpdateWidget(covariant HelpScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && const {'agro', 'ai', 'comm'}.contains(widget.tab)) _tab = widget.tab;
  }
  String _feed = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final convs = ref.watch(conversationsProvider);
    final unread = convs.value?.any((x) => x.unread > 0) ?? false;
    return Scaffold(
      backgroundColor: c.cream,
      bottomNavigationBar: const AppBottomNav(current: '/help'),
      floatingActionButton: _tab == 'comm'
          ? FloatingActionButton.extended(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              onPressed: () => context.push('/community/new'),
              icon: const Icon(AppIcons.edit),
              label: Text(tr('Post yozish'), style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: NavFrame(current: '/help', child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myQuestionsProvider);
                ref.invalidate(expertsProvider);
                ref.invalidate(questionQuotaProvider);
                ref.invalidate(feedProvider(_feed));
              },
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                TopBar(title: tr('Maslahat'), showBack: false, actions: [
                  CircleIconButton(icon: AppIcons.chat, badge: unread, tooltip: tr('Xabarlar'), onTap: () => context.push('/messages')),
                ]),
                SegmentTabs(
                  tabs: [('agro', tr('Agronomlar')), ('ai', tr('AI yordamchi')), ('comm', tr('Jamoat'))],
                  selected: _tab,
                  onSelect: (v) => setState(() => _tab = v),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: AppMotion.base,
                  transitionBuilder: (child, a) => fadeThrough(a, child),
                  child: KeyedSubtree(key: ValueKey(_tab), child: switch (_tab) {
                    'ai' => const _AiTab(),
                    'comm' => _CommunityTab(feed: _feed, onFeed: (v) => setState(() => _feed = v)),
                    _ => const _ExpertsTab(),
                  }),
                ),
              ]),
            ),
          ),
        ),
      )),
    );
  }
}

class _ExpertsTab extends ConsumerWidget {
  const _ExpertsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final quota = ref.watch(questionQuotaProvider).value;
    final experts = ref.watch(expertsProvider).value ?? const <Expert>[];
    final online = experts.where((e) => e.acceptingQuestions).length;
    final quotaText = quota == null
        ? null
        : quota.unlimited
            ? tr('Premium: cheksiz savol')
            : trf('Bu oy: {0} ta bepul savol qoldi', [quota.remaining]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.dark, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.verified_user_outlined, color: c.onDark),
            const SizedBox(width: 10),
            Expanded(child: Text(tr("Agronomdan so'rang"), style: TextStyle(color: c.onDark, fontSize: 17, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Text([quotaText, if (experts.isNotEmpty) trf('{0} agronom onlayn', [online])].whereType<String>().join(' · '),
              style: TextStyle(color: c.onDarkMuted, fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(backgroundColor: c.onDark, foregroundColor: c.dark, padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
              onPressed: quota != null && quota.remaining == 0 ? () => context.push('/premium') : () => context.push('/help/ask'),
              child: Text(quota != null && quota.remaining == 0 ? tr("Limit tugadi — Premium'ga o'tish") : tr('Savol berish'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 22),
      SectionTitle(tr('Savollarim')),
      AsyncView(
        value: ref.watch(myQuestionsProvider),
        onRetry: () => ref.invalidate(myQuestionsProvider),
        data: (list) => list.isEmpty
            ? EmptyNote(tr("Hali savol bermagansiz. Ekiningiz haqida agronomdan so'rang — rasm va tashxis o'zi biriktiriladi."),
                icon: Icons.forum_outlined)
            : Column(children: [for (final q in list) QuestionTile(q)]),
      ),
      if (experts.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionTitle(tr('Agronomlar')),
        for (final e in experts)
          AppCard(
            shadow: false,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => context.push('/help/agronom/${e.id}'),
            child: Row(children: [
              ExpertAvatar(name: e.fullName, url: e.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.fullName, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  Text([e.specialization, e.district ?? e.region, if (e.experienceYears != null) trf('{0} yil tajriba', [e.experienceYears])].whereType<String>().join(' · '),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (e.rating != null) ...[Icon(Icons.star_rounded, size: 16, color: c.gold), Text(' ${e.rating!.toStringAsFixed(1)} · ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))],
                    Text(trf('{0} javob', [e.answers]), style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ]),
              ),
              StatusTag(e.acceptingQuestions ? tr('Onlayn') : tr('Oflayn'), kind: e.acceptingQuestions ? StatusKind.healthy : StatusKind.neutral),
            ]),
          ),
      ],
    ]);
  }
}

/// Savollar ro'yxatidagi qator (holat belgisi bilan).
class QuestionTile extends StatelessWidget {
  const QuestionTile(this.q, {super.key});
  final Question q;
  @override
  Widget build(BuildContext context) {
    final (label, kind) = switch (q.status) {
      'answered' => (tr('Javob berildi'), StatusKind.expert),
      'closed' => (tr('Yopilgan'), StatusKind.neutral),
      _ => (tr('Javob kutilmoqda'), StatusKind.info),
    };
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/help/q/${q.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 4),
        Text([q.cropName, if (q.expert != null) q.expert!.fullName, timeAgo(q.updatedAt ?? q.createdAt)].whereType<String>().join(' · '),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          StatusTag(label, kind: kind),
          if (q.rating != null) StatusTag('${q.rating}', kind: StatusKind.premium, icon: Icons.star_rounded),
        ]),
      ]),
    );
  }
}

/// Agronom avatari — tuproq rangidagi halqa bilan (dehqon kim agronom ekanini darhol ko'radi).
class ExpertAvatar extends StatelessWidget {
  const ExpertAvatar({super.key, required this.name, this.url, this.size = 44});
  final String name;
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.expert, width: 2)),
      child: Avatar(name: name, url: url, size: size - 4, color: c.expertBg, textColor: c.expert),
    );
  }
}

class _AiTab extends StatelessWidget {
  const _AiTab();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final examples = [tr('Pomidorni qachon purkash kerak?'), tr('Uzumni qachon kesish kerak?'), tr("Olma qo'turiga qarshi nima qilay?")];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        shadow: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: c.primaryLight, shape: BoxShape.circle), child: Icon(AppIcons.bot, color: c.primary)),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('AI yordamchi'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 8),
          Text(tr("Ekinlar, kasalliklar va dorilar haqida istalgan savolga darhol javob beradi. Murakkab holatda agronomga yo'naltiradi."),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          PillButton(label: tr('Suhbatni ochish'), style: PillStyle.primary, block: true, onPressed: () => context.push('/assistant')),
        ]),
      ),
      Text(tr('MASALAN'), style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      for (final e in examples)
        ListRow(icon: Icons.chat_bubble_outline_rounded, label: e, onTap: () => context.push('/assistant')),
    ]);
  }
}

class _CommunityTab extends ConsumerWidget {
  const _CommunityTab({required this.feed, required this.onFeed});
  final String feed;
  final ValueChanged<String> onFeed;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        ChipTabs(tabs: [('all', tr('Barchasi')), ('following', tr('Obunalarim'))], selected: feed, onSelect: onFeed),
        AsyncView(
          value: ref.watch(feedProvider(feed)),
          onRetry: () => ref.invalidate(feedProvider(feed)),
          data: (posts) => posts.isEmpty
              ? EmptyNote(feed == 'following' ? tr("Obuna bo'lgan fermerlaringiz hali post yozmagan") : tr("Hali post yo'q. Birinchi bo'ling!"), icon: AppIcons.chat)
              : Column(children: [for (final p in posts) PostCard(post: p, feed: feed)]),
        ),
      ]);
}
