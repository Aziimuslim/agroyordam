import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, this.cropId});
  final String? cropId;
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersState();
}

class _RemindersState extends ConsumerState<RemindersScreen> {
  String _filter = 'today';

  Future<void> _clearDone(List<Reminder> list) async {
    final done = list.where((r) => r.isCompleted).toList();
    if (done.isEmpty) {
      showToast(context, "Bajarilgan eslatma yo'q");
      return;
    }
    if (!await confirm(context, 'Tozalash', '${done.length} ta bajarilgan eslatma o\'chiriladi')) return;
    for (final r in done) {
      await ref.read(gardenRepoProvider).deleteReminder(r.id);
    }
    ref.invalidate(remindersProvider);
    if (mounted) showToast(context, 'Bajarilgan eslatmalar tozalandi');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reminders = ref.watch(remindersProvider);
    return PageShell(
      padBottom: false,
      onRefresh: () async => ref.invalidate(remindersProvider),
      child: AsyncView(
        value: reminders,
        onRetry: () => ref.invalidate(remindersProvider),
        data: (everything) {
          final all = widget.cropId == null ? everything : everything.where((r) => r.cropId == widget.cropId).toList();
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final list = switch (_filter) {
            'today' => all.where((r) => !r.date.isAfter(today) && (!r.isCompleted || r.date == today)).toList(),
            'care' => all.where((r) => !r.isTreatment).toList(),
            'treat' => all.where((r) => r.isTreatment).toList(),
            _ => all,
          };
          final pending = all.where((r) => !r.isCompleted).length;
          final overdue = all.where((r) => !r.isCompleted && r.date.isBefore(today)).length;
          final cropName = widget.cropId == null ? null : all.map((r) => r.cropName).whereType<String>().firstOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TopBar(title: 'Eslatmalar', subtitle: cropName, actions: [
              CircleIconButton(icon: AppIcons.trash, tooltip: 'Bajarilganlarni tozalash', onTap: () => _clearDone(all)),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: AppIcons.plus,
                tooltip: "Eslatma qo'shish",
                onTap: () => context.push(widget.cropId == null ? '/reminders/add' : '/reminders/add?crop=${widget.cropId}'),
              ),
            ]),
            AppCard(
              color: c.cream2,
              shadow: false,
              child: Row(children: [
                ThumbIcon(icon: AppIcons.bell, bg: c.card),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$pending ta eslatma', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (overdue > 0) Text("$overdue tasi muddati o'tgan", style: TextStyle(color: c.danger, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            ChipTabs(
              tabs: const [('today', 'Bugun'), ('all', 'Barchasi'), ('care', 'Parvarish'), ('treat', 'Davolash')],
              selected: _filter,
              onSelect: (v) => setState(() => _filter = v),
            ),
            if (list.isEmpty) EmptyNote(_filter == 'today' ? "Bugun bajariladigan vazifa yo'q" : "Bu bo'limda eslatma yo'q", icon: AppIcons.bell),
            for (final r in list) ReminderCard(reminder: r),
          ]);
        },
      ),
    );
  }
}

class ReminderCard extends ConsumerWidget {
  const ReminderCard({super.key, required this.reminder});
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final r = reminder;
    final today = DateTime.now();
    final overdue = !r.isCompleted && r.date.isBefore(DateTime(today.year, today.month, today.day));
    return Opacity(
      opacity: r.isCompleted ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: c.tan, shape: BoxShape.circle),
              child: Icon(AppIcons.forReminder(r.type), size: 18, color: c.primaryDark),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(r.cropName ?? 'Umumiy', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Tag(reminderTypeLabels[r.type] ?? 'Parvarish', bg: r.isTreatment ? c.tagTreat : c.tagCare, fg: r.isTreatment ? c.primaryDark : c.onTagCare),
            if (overdue) ...[const SizedBox(width: 6), Tag("Muddati o'tgan", bg: c.dangerBg, fg: c.danger)],
          ]),
          const SizedBox(height: 10),
          Text(r.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          if (r.description != null && r.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.description!, style: TextStyle(fontSize: 13, color: c.muted, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text('${formatDate(r.date)}${r.time != null ? ' · ${r.time!.substring(0, 5)}' : ''}', style: TextStyle(fontSize: 11.5, color: c.muted)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: PillButton(
                label: r.isCompleted ? 'Bajarildi' : 'Bajarildi deb belgilash',
                icon: r.isCompleted ? AppIcons.check : null,
                style: PillStyle.primary,
                fg: null,
                onPressed: () async {
                  try {
                    await ref.read(gardenRepoProvider).toggleReminder(r.id);
                    ref.invalidate(remindersProvider);
                    ref.invalidate(cropsProvider);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            CircleIconButton(
              icon: AppIcons.trash,
              tooltip: "O'chirish",
              onTap: () async {
                await ref.read(gardenRepoProvider).deleteReminder(r.id);
                ref.invalidate(remindersProvider);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
