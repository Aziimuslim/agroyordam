import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../reminders/task_row.dart';
import 'crop_actions.dart';
import 'crop_photo.dart';

/// S04 Parvarish rejasi (ekin bo'yicha): Bugun / Hafta / Barchasi yoki kalendardan tanlangan kun.
/// Bajarilgan hisob aynan tanlangan davr bo'yicha; kechikkan vazifa yangi kun bo'ldi deb bajarilgan sanalmaydi.
/// Reja manbasi ko'rsatiladi — AI yaratgan reja agronom tavsiyasi deb yozilmaydi.
class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key, required this.cropId});
  final String cropId;
  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  String _period = 'today';
  DateTime? _day;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _day ?? _today);
    if (d != null) {
      setState(() {
        _day = d;
        _period = 'day';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final crop = ref.watch(cropProvider(widget.cropId));
    final tasks = ref.watch(cropRemindersProvider(widget.cropId));
    final cr = crop.value;
    final all = tasks.value;

    Widget body;
    if (all == null && tasks.hasError) {
      body = BlockError(error: tasks.error!, what: tr('Vazifalar'), onRetry: () => ref.invalidate(cropRemindersProvider(widget.cropId)));
    } else if (all == null) {
      body = const Column(children: [Skeleton(height: 64), SizedBox(height: 8), Skeleton(height: 64), SizedBox(height: 8), Skeleton(height: 64)]);
    } else if (all.isEmpty) {
      body = Column(children: [
        EmptyNote(tr("Bu ekin uchun parvarish rejasi yo'q. Bargni tekshiring — AI natijasi asosida reja tuzish mumkin."), icon: Icons.event_note_outlined),
        if (cr != null && !cr.isArchived)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(0, 52)),
            onPressed: () => context.push('/diagnose?crop=${widget.cropId}'),
            icon: const Icon(AppIcons.scan),
            label: Text(tr('Ekinni tekshirish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
      ]);
    } else {
      final t = _today;
      final weekEnd = t.add(const Duration(days: 6));
      bool inPeriod(Reminder r) => switch (_period) {
            'today' => r.date == t,
            'week' => !r.date.isBefore(t) && !r.date.isAfter(weekEnd),
            'day' => _day != null && r.date == _day,
            _ => true,
          };
      final period = all.where(inPeriod).toList()
        ..sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : (a.time ?? '').compareTo(b.time ?? ''));
      // Kechikkanlar alohida guruh: "Bugun" va "Hafta" davrida ko'rinadi, davr hisobiga qo'shilmaydi
      final overdue = _period == 'today' || _period == 'week' ? all.where((r) => !r.isCompleted && r.date.isBefore(t)).toList() : const <Reminder>[];
      final done = period.where((r) => r.isCompleted).length;
      final readOnly = cr?.isArchived ?? false;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (period.isNotEmpty) ...[
          Semantics(
            label: trf('{0} tadan {1} tasi bajarildi', [period.length, done]),
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('{0}/{1} vazifa', [done, period.length]), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: done / period.length, minHeight: 10, backgroundColor: c.cream2, color: c.olive),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (overdue.isNotEmpty) ...[
          Text(trf('Kechikkan ({0})', [overdue.length]), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.danger)),
          const SizedBox(height: 8),
          for (final r in overdue) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskRow(r: r, readOnly: readOnly)),
          const SizedBox(height: 8),
        ],
        if (period.isEmpty)
          EmptyNote(switch (_period) {
            'today' => tr("Bugun bu ekin uchun vazifa yo'q"),
            'week' => tr("Shu hafta uchun vazifa yo'q"),
            _ => tr("Tanlangan kunda vazifa yo'q"),
          }, icon: Icons.task_alt_rounded)
        else
          _Timeline(tasks: period, showDate: _period != 'today' && _period != 'day', readOnly: readOnly),
      ]);
    }

    final dayLabel = _day == null ? null : formatDayMonth(_day!);
    final fromAi = all?.any((r) => r.diagnosisId != null) ?? false;
    final start = all == null || all.isEmpty ? null : all.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async {
        ref.invalidate(cropRemindersProvider(widget.cropId));
        ref.invalidate(cropProvider(widget.cropId));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Parvarish rejasi'), actions: [
          IconButton(tooltip: tr('Kunni tanlash'), onPressed: _pickDay, icon: Icon(AppIcons.calendar, color: c.text)),
        ]),
        if (cr != null)
          AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => context.canPop() ? context.pop() : context.go('/garden/${cr.id}'),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 72, height: 72, child: CropPhoto(crop: cr))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cr.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 4),
                  if (all != null && all.isNotEmpty)
                    _SourceTag(fromAi: fromAi),
                  if (start != null) ...[
                    const SizedBox(height: 4),
                    Text(trf('Reja {0} dan boshlangan', [formatDayMonth(start)]), style: TextStyle(fontSize: 14, color: c.muted)),
                  ],
                ]),
              ),
            ]),
          )
        else if (crop.hasError)
          BlockError(error: crop.error!, what: tr('Ekin'), onRetry: () => ref.invalidate(cropProvider(widget.cropId))),
        const SizedBox(height: 4),
        SegmentTabs(
          tabs: [('today', tr('Bugun')), ('week', tr('Hafta')), ('all', tr('Barchasi')), if (dayLabel != null) ('day', dayLabel)],
          selected: _period,
          onSelect: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: 16),
        body,
        if (cr != null && !cr.isArchived && (all?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => addObservation(context, ref, cr.id),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(tr("Kuzatuv qo'shish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => context.push('/reminders/add?crop=${cr.id}'),
              icon: const Icon(AppIcons.plus),
              label: Text(tr("Vazifa qo'shish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.fromAi});
  final bool fromAi;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(fromAi ? Icons.auto_awesome_outlined : Icons.person_outline_rounded, size: 16, color: c.onOliveSoft),
        const SizedBox(width: 5),
        Flexible(
          child: Text(fromAi ? tr('AI tashxis asosida') : tr("O'zingiz qo'shgan"),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onOliveSoft, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Vazifalar vaqt chizig'i: kun sarlavhasi (davr bir kundan katta bo'lsa) va TaskRow.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.tasks, required this.showDate, required this.readOnly});
  final List<Reminder> tasks;
  final bool showDate, readOnly;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <Widget>[];
    DateTime? last;
    for (final r in tasks) {
      if (showDate && r.date != last) {
        last = r.date;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(formatDayLong(r.date), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.muted)),
        ));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskRow(r: r, readOnly: readOnly)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
