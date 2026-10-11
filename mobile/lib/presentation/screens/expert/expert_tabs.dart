import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../community/post_card.dart';
import 'expert_shell.dart';
import 'queue_screen.dart';

/// Agronom: dehqon savollari — Yangi (hech kim olmagan) · Jarayonda (men olganlar) · Yopilgan.
class ExpertQuestionsScreen extends ConsumerStatefulWidget {
  const ExpertQuestionsScreen({super.key});
  @override
  ConsumerState<ExpertQuestionsScreen> createState() => _QuestionsState();
}

class _QuestionsState extends ConsumerState<ExpertQuestionsScreen> {
  String _tab = 'new';

  @override
  Widget build(BuildContext context) {
    String count(String s) {
      final n = ref.watch(inboxProvider(s)).value?.length;
      return n == null ? '' : ' · $n';
    }

    return ExpertPage(
      current: '/expert/questions',
      onRefresh: () async {
        ref.invalidate(inboxProvider);
        ref.invalidate(expertStatsProvider);
      },
      children: [
        const ExpertHeader(title: 'Savollar', trailing: OnlineToggle()),
        SegmentTabs(
          expert: true,
          tabs: [('new', 'Yangi${count('new')}'), ('mine', 'Jarayonda${count('mine')}'), ('closed_mine', 'Yopilgan${count('closed_mine')}')],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 14),
        AsyncView(
          value: ref.watch(inboxProvider(_tab)),
          onRetry: () => ref.invalidate(inboxProvider(_tab)),
          data: (list) => list.isEmpty
              ? EmptyNote(switch (_tab) {
                  'new' => "Yangi savol yo'q. Dehqon savol bersa shu yerda va bildirishnomada ko'rinadi.",
                  'mine' => "Javob berayotgan savolingiz yo'q",
                  _ => "Yopilgan savollar yo'q",
                }, icon: Icons.inbox_outlined)
              : Column(children: [for (final q in list) InboxTile(q)]),
        ),
      ],
    );
  }
}

class InboxTile extends StatelessWidget {
  const InboxTile(this.q, {super.key});
  final Question q;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/help/q/${q.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(name: q.author.fullName, url: q.author.avatarUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  [q.author.fullName, q.cropName, timeAgo(q.updatedAt ?? q.createdAt)].whereType<String>().join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (q.diagnosisName != null)
                      StatusTag(
                        'AI: ${q.diagnosisName}${q.diagnosisConfidence != null ? ' ${q.diagnosisConfidence!.round()}%' : ''}',
                        kind: (q.diagnosisConfidence ?? 100) < 70 ? StatusKind.risk : StatusKind.neutral,
                        icon: Icons.auto_awesome_outlined,
                      )
                    else if (q.diagnosisId == null)
                      const StatusTag('Tashxissiz', kind: StatusKind.neutral),
                    switch (q.status) {
                      'new' => const StatusTag('Yangi', kind: StatusKind.info),
                      'closed' =>
                        q.rating != null
                            ? StatusTag('${q.rating}', kind: StatusKind.premium, icon: Icons.star_rounded)
                            : const StatusTag('Yopilgan', kind: StatusKind.neutral),
                      _ => StatusTag('${q.messagesCount} xabar', kind: StatusKind.expert, icon: Icons.chat_bubble_outline_rounded),
                    },
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Agronom: jamoat — "Javobsiz" (hali agronom yozmagan postlar) va barcha postlar.
class ExpertCommunityScreen extends ConsumerStatefulWidget {
  const ExpertCommunityScreen({super.key});
  @override
  ConsumerState<ExpertCommunityScreen> createState() => _CommunityState();
}

class _CommunityState extends ConsumerState<ExpertCommunityScreen> {
  String _tab = 'unanswered';
  @override
  Widget build(BuildContext context) {
    final unanswered = ref.watch(unansweredPostsProvider);
    final value = _tab == 'unanswered' ? unanswered : ref.watch(feedProvider('all'));
    final n = unanswered.value?.length;
    return ExpertPage(
      current: '/expert/community',
      onRefresh: () async {
        ref.invalidate(unansweredPostsProvider);
        ref.invalidate(feedProvider('all'));
      },
      children: [
        const ExpertHeader(title: 'Jamoat'),
        ExpertChips(
          tabs: [('unanswered', n == null ? 'Javobsiz' : 'Javobsiz · $n'), ('all', 'Hammasi')],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        if (_tab == 'unanswered')
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: NoteBox(
              kind: NoteKind.expert,
              title: 'Agronom javobi',
              text: "Siz yozgan izoh postda birinchi bo'lib, «Agronom javobi» belgisi bilan ko'rinadi.",
            ),
          ),
        AsyncView(
          value: value,
          onRetry: () => ref.invalidate(unansweredPostsProvider),
          data: (posts) => posts.isEmpty
              ? EmptyNote(_tab == 'unanswered' ? 'Hamma postlarga agronom javob bergan' : "Hali post yo'q", icon: Icons.forum_outlined)
              : Column(
                  children: [for (final p in posts) PostCard(post: p, feed: 'all')],
                ),
        ),
      ],
    );
  }
}
