import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'expert_shell.dart';

/// Agronom TZ Y01 — Navbat: agronom va mavjudlik, 3 ish ko'rsatkichi, filtrlar (Hammasi / Dehqon so'ragan / Ishonchi past)
/// va tekshiruv ishlari. Boshqa agronom olgan ish bu ro'yxatda ko'rinmaydi.
class ExpertQueueScreen extends ConsumerStatefulWidget {
  const ExpertQueueScreen({super.key});
  @override
  ConsumerState<ExpertQueueScreen> createState() => _QueueState();
}

class _QueueState extends ConsumerState<ExpertQueueScreen> {
  String _filter = 'all';

  Future<void> _refresh() async {
    ref.invalidate(expertStatsProvider);
    ref.invalidate(queueCountsProvider);
    ref.invalidate(reviewQueueProvider(_filter));
    await ref.read(reviewQueueProvider(_filter).future).catchError((_) => <QueueItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stats = ref.watch(expertStatsProvider).value;
    final counts = ref.watch(queueCountsProvider).value;
    final queue = ref.watch(reviewQueueProvider(_filter));
    final unread = ref.watch(notificationsProvider).value?.where((n) => !n.isRead).length ?? 0;
    return ExpertPage(
      current: '/expert',
      onRefresh: _refresh,
      children: [
        Row(children: [
          const BrandLogo(size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AgroYordam', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text, height: 1.1)),
              Text(tr('Agronom'), style: TextStyle(fontSize: 13, color: c.muted)),
            ]),
          ),
          IconButton(
            tooltip: unread > 0 ? trf('Bildirishnomalar: {0} ta yangi', [unread]) : tr('Bildirishnomalar'),
            onPressed: () => context.push('/notifications'),
            icon: Badge(isLabelVisible: unread > 0, backgroundColor: c.primary, smallSize: 9, child: Icon(Icons.notifications_none_rounded, color: c.text, size: 27)),
          ),
        ]),
        const SizedBox(height: 16),
        const _ExpertIntro(),
        const SizedBox(height: 16),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Metric(icon: Icons.inbox_outlined, value: counts?.all, label: tr("Ko'rib chiqish navbatida")),
          const SizedBox(width: 10),
          _Metric(icon: Icons.schedule_rounded, value: stats?.todayNew, label: tr('Bugun kelgan')),
          const SizedBox(width: 10),
          _Metric(icon: Icons.check_circle_rounded, value: stats?.reviewed7d, label: tr('Javob berilgan (7 kun)'), accent: c.success),
        ])),
        const SizedBox(height: 16),
        _FilterChips(
          tabs: [
            ('all', tr('Hammasi'), counts?.all),
            ('requested', tr("Dehqon so'ragan"), counts?.requested),
            ('low', tr('Ishonchi past'), counts?.low),
          ],
          selected: _filter,
          onSelect: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 14),
        AsyncView(
          value: queue,
          onRetry: () => ref.invalidate(reviewQueueProvider(_filter)),
          data: (items) => items.isEmpty
              ? _EmptyQueue(filter: _filter, onRefresh: _refresh)
              : Column(children: [for (final i in items) QueueCard(i)]),
        ),
      ],
    );
  }
}

/// Agronom: avatar, ism, mutaxassislik, tajriba va "Ish qabul qilaman" tanlovi.
class _ExpertIntro extends ConsumerStatefulWidget {
  const _ExpertIntro();
  @override
  ConsumerState<_ExpertIntro> createState() => _ExpertIntroState();
}

class _ExpertIntroState extends ConsumerState<_ExpertIntro> {
  bool _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(expertRepoProvider).updateMe(acceptingQuestions: on);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) showToast(context, on ? tr('Ish qabul qilinadi') : tr("Yangi ish tayinlanmaydi; mavjud ishlar qoladi"));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    if (me == null) return const SizedBox.shrink();
    final on = me.acceptingQuestions;
    final fg = on ? c.success : c.muted;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.oliveSoft, width: 3)),
        child: Avatar(name: me.fullName, url: me.avatarUrl, size: 64, color: c.olive, textColor: c.onOlive),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(me.fullName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text, height: 1.25)),
          const SizedBox(height: 2),
          Text(
            [tr('Agronom'), if ((me.specialization ?? '').isNotEmpty) me.specialization!].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: c.muted, height: 1.35),
          ),
          if (me.experienceYears != null) Text(trf('Tajriba: {0} yil', [me.experienceYears]), style: TextStyle(fontSize: 14, color: c.muted, height: 1.35)),
          const SizedBox(height: 8),
          PopupMenuButton<bool>(
            enabled: !_busy,
            tooltip: tr('Mavjudlik'),
            onSelected: (v) => v == on ? null : _set(v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: true, checked: on, child: Text(tr('Ish qabul qilaman'))),
              CheckedPopupMenuItem(value: false, checked: !on, child: Text(tr('Hozircha qabul qilmayman'))),
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              decoration: BoxDecoration(color: on ? c.successBg : c.cream2, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(on ? tr('Ish qabul qilaman') : tr('Hozircha qabul qilmayman'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: fg)),
                const SizedBox(width: 2),
                _busy ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg)) : Icon(Icons.expand_more_rounded, size: 20, color: fg),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label, this.accent});
  final IconData icon;
  final int? value;
  final String label;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 22, color: accent ?? c.olive),
            const SizedBox(width: 6),
            Flexible(child: Text(value == null ? '—' : '$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text))),
          ]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.3)),
        ]),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.tabs, required this.selected, required this.onSelect});
  final List<(String, String, int?)> tabs;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (id, label, n) in tabs)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: selected == id,
              button: true,
              child: Material(
                color: selected == id ? c.olive : c.card,
                shape: StadiumBorder(side: BorderSide(color: selected == id ? c.olive : c.border)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelect(id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(n == null ? label : '$label ($n)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selected == id ? c.onOlive : c.text)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.filter, required this.onRefresh});
  final String filter;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(Icons.task_alt_rounded, size: 40, color: c.success),
        const SizedBox(height: 10),
        Text(filter == 'all' ? tr('Yangi ish yo\'q') : tr('Bu filtrda ish yo\'q'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 4),
        Text(tr("Dehqonlar tekshiruv so'raganda yoki AI ishonchi past bo'lganda shu yerda paydo bo'ladi."),
            textAlign: TextAlign.center, style: TextStyle(color: c.muted, height: 1.4)),
        const SizedBox(height: 14),
        PillButton(label: tr('Yangilash'), icon: Icons.refresh_rounded, style: PillStyle.outline, onPressed: onRefresh),
      ]),
    );
  }
}

/// Navbat kartasi: dehqon yuborgan asl rasm, ekin, qisqa belgi, kim va qachon, "Ko'rib chiqish".
class QueueCard extends StatelessWidget {
  const QueueCard(this.i, {super.key});
  final QueueItem i;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    void open() => context.push('/expert/review/${i.id}');
    final symptom = (i.reviewNote?.trim().isNotEmpty ?? false) ? i.reviewNote!.trim() : (i.symptoms ?? trf('AI: {0}', [i.title]));
    return Semantics(
      container: true,
      child: AppCard(
        shadow: false,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        onTap: open,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CatalogImage(url: AppConfig.mediaUrl(i.imageUrl), width: 104, height: 120, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(i.plantName ?? tr('Ekin ko\'rsatilmagan'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                if (i.claimedByMe) StatusTag(tr("Siz ko'rib chiqyapsiz"), kind: StatusKind.info, icon: Icons.edit_note_rounded)
                else if (i.reviewRequested) StatusTag(tr("Dehqon so'ragan"), kind: StatusKind.info, icon: Icons.send_outlined)
                else if (i.lowConfidence) StatusTag(tr('Ishonchi past'), kind: StatusKind.risk, icon: Icons.info_outline_rounded),
              ]),
              const SizedBox(height: 4),
              Text(symptom, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.text, height: 1.35)),
              const SizedBox(height: 6),
              _Meta(Icons.person_outline_rounded, [i.farmerName, if (i.farmerRegion != null) i.farmerRegion!].join(' · ')),
              _Meta(Icons.schedule_rounded, timeAgo(i.diagnosedAt)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: open,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(tr("Ko'rib chiqish"), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: context.c.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: context.c.muted))),
        ]),
      );
}
