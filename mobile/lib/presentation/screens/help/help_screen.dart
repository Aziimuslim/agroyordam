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
import '../../../core/widgets/blocks.dart';
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

/// S09 AI yordamchi tabi: tayyor savol S10 yozish maydoniga qo'yiladi (avtomatik yuborilmaydi, limit sarflanmaydi).
class _AiTab extends ConsumerWidget {
  const _AiTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sub = ref.watch(mySubscriptionProvider).value;
    final examples = [tr('Pomidorni qachon purkash kerak?'), tr('Uzumni qachon kesish kerak?'), tr("Olma qo'turiga qarshi nima qilay?")];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: c.oliveSoft, shape: BoxShape.circle), child: Icon(AppIcons.bot, color: c.onOliveSoft)),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('AI yordamchi'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text))),
          ]),
          const SizedBox(height: 8),
          Text(tr("Ekinlar, kasalliklar va dorilar haqida savol bering. Javob agronom tavsiyasi emas; murakkab holatda agronomga murojaat qiling."),
              style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
          if (sub != null && sub.aiDailyLimit != null) ...[
            const SizedBox(height: 8),
            Text(trf('Bugun: {0}/{1} bepul so\'rov', [sub.aiUsedToday, sub.aiDailyLimit]), style: TextStyle(fontSize: 14, color: c.muted)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => context.push('/assistant'),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(tr('Suhbatni ochish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Text(tr('Tayyor savollar'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
      const SizedBox(height: 4),
      Text(tr("Bosilganda savol yozish maydoniga qo'yiladi — yuborishni o'zingiz tasdiqlaysiz."), style: TextStyle(fontSize: 14, color: c.muted)),
      const SizedBox(height: 8),
      for (final e in examples)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: c.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(Uri(path: '/assistant', queryParameters: {'q': e}).toString()),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.edit_note_rounded, color: c.olive),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e, style: TextStyle(fontSize: 15, color: c.text))),
                  Icon(Icons.chevron_right_rounded, color: c.muted),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// S11 Jamoat: Barchasi / Obunalarim / Tajriba / Savollar. Holat (skeleton, xato, bo'sh) faqat lenta blokida.
class _CommunityTab extends ConsumerWidget {
  const _CommunityTab({required this.feed, required this.onFeed});
  final String feed;
  final ValueChanged<String> onFeed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(feedProvider(feed));
    final posts = v.value;
    Widget body;
    if (posts == null && v.hasError) {
      body = BlockError(error: v.error!, what: tr('Postlar'), onRetry: () => ref.invalidate(feedProvider(feed)));
    } else if (posts == null) {
      body = const Column(children: [Skeleton(height: 180), SizedBox(height: 12), Skeleton(height: 180)]);
    } else if (posts.isEmpty) {
      body = Column(children: [
        EmptyNote(
          switch (feed) {
            'following' => tr("Obuna bo'lgan fermerlaringiz hali post yozmagan"),
            'question' => tr("Hali savol yo'q"),
            _ => tr("Hali post yo'q. Birinchi bo'ling!"),
          },
          icon: AppIcons.chat,
        ),
        TextButton.icon(onPressed: () => context.push('/community/new'), icon: const Icon(AppIcons.edit), label: Text(tr('Post yozish'))),
      ]);
    } else {
      body = Column(children: [for (final p in posts) PostCard(key: ValueKey(p.id), post: p, feed: feed)]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChipTabs(
        tabs: [('all', tr('Barchasi')), ('following', tr('Obunalarim')), ('experience', tr('Tajriba')), ('question', tr('Savollar'))],
        selected: feed,
        onSelect: onFeed,
      ),
      body,
    ]);
  }
}
