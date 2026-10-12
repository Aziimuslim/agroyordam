import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'expert_shell.dart';

/// Tekshirish navbati: AI tashxislari. Avval dehqon so'raganlari va ishonchi pastlari.
class ExpertQueueScreen extends ConsumerStatefulWidget {
  const ExpertQueueScreen({super.key});
  @override
  ConsumerState<ExpertQueueScreen> createState() => _QueueState();
}

class _QueueState extends ConsumerState<ExpertQueueScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final stats = ref.watch(expertStatsProvider).value;
    final queue = ref.watch(reviewQueueProvider(_filter));
    return ExpertPage(
      current: '/expert',
      onRefresh: () async {
        ref.invalidate(expertStatsProvider);
        ref.invalidate(reviewQueueProvider(_filter));
      },
      children: [
        ExpertHeader(
          title: stats == null ? tr('Navbat') : (stats.queuePending == 0 ? tr("Navbat bo'sh") : trf('{0} ta kutmoqda', [stats.queuePending])),
          leading: me == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.expert, width: 2),
                  ),
                  child: Avatar(name: me.fullName, url: me.avatarUrl, size: 40, color: c.expertBg, textColor: c.expert),
                ),
          trailing: const OnlineToggle(),
        ),
        Row(
          children: [
            StatTile('${stats?.reviewedToday ?? '—'}', tr('bugun\ntekshirildi')),
            const SizedBox(width: 8),
            StatTile(stats?.aiAgreement == null ? '—' : '${stats!.aiAgreement}%', tr('AI bilan mos')),
            const SizedBox(width: 8),
            StatTile(formatWait(stats?.avgAnswerMinutes), tr("o'rtacha\njavob")),
          ],
        ),
        const SizedBox(height: 16),
        ExpertChips(
          tabs: [('all', tr('Hammasi')), ('requested', tr("Dehqon so'ragan")), ('low', tr('Ishonchi past'))],
          selected: _filter,
          onSelect: (v) => setState(() => _filter = v),
        ),
        AsyncView(
          value: queue,
          onRetry: () => ref.invalidate(reviewQueueProvider(_filter)),
          data: (items) => items.isEmpty
              ? EmptyNote(tr("Hammasi tekshirilgan. Yangi tashxislar shu yerda paydo bo'ladi."), icon: Icons.task_alt_rounded)
              : Column(children: [for (final i in items) QueueCard(i)]),
        ),
      ],
    );
  }
}

/// Agronom rangidagi filtr chiplari.
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
        child: Row(
          children: [
            for (final (id, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  selected: selected == id,
                  button: true,
                  child: Material(
                    color: selected == id ? c.expertBg : c.card,
                    shape: StadiumBorder(side: BorderSide(color: selected == id ? c.expert : c.border, width: selected == id ? 1.5 : 1)),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelect(id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Text(
                          label,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: selected == id ? c.expert : c.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QueueCard extends StatelessWidget {
  const QueueCard(this.i, {super.key});
  final QueueItem i;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = i.confidence?.round();
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/expert/review/${i.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogImage(url: AppConfig.mediaUrl(i.imageUrl), width: 76, height: 76),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(i.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3)),
                    ),
                    if (pct != null)
                      Text(
                        '$pct%',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: i.lowConfidence ? c.warning : c.success),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [i.plantName, i.farmerName, i.farmerRegion, timeAgo(i.diagnosedAt)].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (i.reviewRequested) StatusTag(tr("Dehqon so'radi"), kind: StatusKind.expert, icon: Icons.send_outlined),
                    if (i.lowConfidence) StatusTag(tr('Taxminiy'), kind: StatusKind.risk, icon: Icons.info_outline_rounded),
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
