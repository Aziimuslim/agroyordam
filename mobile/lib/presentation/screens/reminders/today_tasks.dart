import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Bugungi va muddati o'tgan, hali bajarilmagan vazifalar.
List<Reminder> dueTasks(List<Reminder> all, {String? cropId}) {
  final t = _today();
  return all.where((r) => !r.isCompleted && !r.date.isAfter(t) && (cropId == null || r.cropId == cropId)).toList()
    ..sort((a, b) => a.date.compareTo(b.date) != 0 ? a.date.compareTo(b.date) : (a.time ?? '').compareTo(b.time ?? ''));
}

/// Bir bosishda bajarildi deb belgilanadigan vazifa qatori (bosh sahifa, ekin sahifasi).
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.r, this.showCrop = true});
  final Reminder r;
  final bool showCrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final overdue = !r.isCompleted && r.date.isBefore(_today());
    final meta = [
      if (showCrop && r.cropName != null) r.cropName!,
      overdue ? "Muddati o'tgan · ${formatDate(r.date)}" : (r.time != null ? r.time!.substring(0, 5) : 'Bugun'),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: softShadow(context, 6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          try {
            await ref.read(gardenRepoProvider).toggleReminder(r.id);
            ref.invalidate(remindersProvider);
            if (r.cropId != null) ref.invalidate(cropProvider(r.cropId!));
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          child: Row(children: [
            Icon(r.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: r.isCompleted ? c.success : (overdue ? c.danger : c.muted), size: 26),
            const SizedBox(width: 8),
            Icon(AppIcons.forReminder(r.type), size: 18, color: c.primaryDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                    )),
                Text(meta, style: TextStyle(fontSize: 12, color: overdue ? c.danger : c.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Bugungi vazifalar" ro'yxati. cropId berilsa — faqat shu ekin.
class TodayTasks extends ConsumerWidget {
  const TodayTasks({super.key, this.cropId, this.limit = 4});
  final String? cropId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(remindersProvider).maybeWhen(
          data: (all) {
            final due = dueTasks(all, cropId: cropId);
            if (due.isEmpty) return const EmptyNote("Bugun bajariladigan vazifa yo'q", icon: AppIcons.check);
            return Column(children: [
              for (final r in due.take(limit)) TaskTile(r: r, showCrop: cropId == null),
              if (due.length > limit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('yana ${due.length - limit} ta vazifa', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
                ),
            ]);
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
