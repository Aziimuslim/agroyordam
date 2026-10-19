import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'task_row.dart';

/// S25 Eslatmalar: Bugun / Barchasi / Bajarilgan; kechikkanlar alohida guruh. Ro'yxat bitta Task modeli
/// (care reja va qo'lda qo'shilgan eslatmalar bir joyda, dublikatsiz). Karta → A03, "+" → S26.
/// `?crop=` berilsa — faqat shu ekin (S04/S06 dan).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, this.cropId});
  final String? cropId;
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersState();
}

class _RemindersState extends ConsumerState<RemindersScreen> {
  String _tab = 'today';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = ref.watch(widget.cropId == null ? remindersProvider : cropRemindersProvider(widget.cropId!));
    final everything = value.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    Widget body;
    if (everything == null && value.hasError) {
      body = BlockError(
        error: value.error!,
        what: tr('Vazifalar'),
        onRetry: () => widget.cropId == null ? ref.invalidate(remindersProvider) : ref.invalidate(cropRemindersProvider(widget.cropId!)),
      );
    } else if (everything == null) {
      body = const Column(children: [Skeleton(height: 64), SizedBox(height: 8), Skeleton(height: 64), SizedBox(height: 8), Skeleton(height: 64)]);
    } else {
      final all = everything;
      final overdue = all.where((r) => !r.isCompleted && r.date.isBefore(today)).toList()..sort(_byDate);
      // "Bugun N" hisobiga ertangi vazifa kirmaydi (TZ S25)
      final todays = all.where((r) => r.date == today).toList()..sort(_byDate);
      final upcoming = all.where((r) => !r.isCompleted && r.date.isAfter(today)).toList()..sort(_byDate);
      final done = all.where((r) => r.isCompleted).toList()
        ..sort((a, b) => (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date));

      Widget group(String title, List<Reminder> items, {Color? color, String? trailing}) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(trf('{0} ({1})', [title, items.length]), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? c.text)),
                    ),
                  ),
                  if (trailing != null) Text(trailing, style: TextStyle(fontSize: 14, color: c.muted)),
                ]),
              ),
              for (final r in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskRow(r: r)),
            ],
          );

      final List<Widget> sections = switch (_tab) {
        'done' => [if (done.isNotEmpty) group(tr('Bajarilgan'), done)],
        'all' => [
            if (overdue.isNotEmpty) group(tr('Kechikkan'), overdue, color: c.danger),
            if (todays.isNotEmpty) group(tr('Bugun'), todays, trailing: formatDate(today)),
            if (upcoming.where((r) => r.date == tomorrow).isNotEmpty) group(tr('Ertaga'), upcoming.where((r) => r.date == tomorrow).toList()),
            if (upcoming.where((r) => r.date.isAfter(tomorrow)).isNotEmpty)
              group(tr('Keyinroq'), upcoming.where((r) => r.date.isAfter(tomorrow)).toList()),
          ],
        _ => [
            if (overdue.isNotEmpty) group(tr('Kechikkan'), overdue, color: c.danger),
            if (todays.isNotEmpty) group(tr('Bugun'), todays, trailing: formatDate(today)),
          ],
      };
      final todayDone = todays.where((r) => r.isCompleted).length;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_tab == 'today' && todays.isNotEmpty) ...[
          Semantics(
            label: trf('{0} tadan {1} tasi bajarildi', [todays.length, todayDone]),
            excludeSemantics: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('Bugun: {0}/{1} vazifa bajarildi', [todayDone, todays.length]),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: todayDone / todays.length, minHeight: 10, backgroundColor: c.cream2, color: c.olive),
              ),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        if (sections.isEmpty)
          Column(children: [
            EmptyNote(
              switch (_tab) {
                'done' => tr("Hali bajarilgan vazifa yo'q"),
                'all' => tr("Vazifalar yo'q. Eslatma qo'shing yoki tashxisdan keyin parvarish rejasini boshlang."),
                _ => tr("Bugun bajariladigan vazifa yo'q"),
              },
              icon: Icons.task_alt_rounded,
            ),
            if (_tab != 'done')
              TextButton.icon(
                onPressed: () => context.push(_addPath),
                icon: const Icon(AppIcons.plus),
                label: Text(tr("Eslatma qo'shish")),
              ),
          ])
        else
          ...sections,
      ]);
    }

    final cropName = widget.cropId == null ? null : everything?.map((r) => r.cropName).whereType<String>().firstOrNull;
    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async {
        ref.invalidate(remindersProvider);
        if (widget.cropId != null) ref.invalidate(cropRemindersProvider(widget.cropId!));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Eslatmalar'), subtitle: cropName, actions: [
          Tooltip(
            message: tr("Eslatma qo'shish"),
            child: Material(
              color: c.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push(_addPath),
                child: SizedBox(width: 48, height: 48, child: Icon(AppIcons.plus, color: c.onPrimary)),
              ),
            ),
          ),
        ]),
        ChipTabs(
          tabs: [('today', tr('Bugun')), ('all', tr('Barchasi')), ('done', tr('Bajarilgan'))],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tab), child: body)),
      ]),
    );
  }

  String get _addPath => widget.cropId == null ? '/reminders/add' : '/reminders/add?crop=${widget.cropId}';

  static int _byDate(Reminder a, Reminder b) =>
      a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : (a.time ?? '').compareTo(b.time ?? '');
}
