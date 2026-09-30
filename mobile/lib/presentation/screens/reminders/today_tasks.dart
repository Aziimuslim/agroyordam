import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
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

(Color, Color) _typeColors(AppColors c, String? type) => switch (type) {
      'treatment' => (c.dangerBg, c.danger),
      'watering' => (c.infoBg, c.info),
      'recheck' => (c.accentSoft, c.warning),
      'fertilizing' => (c.warningBg, c.warning),
      _ => (c.successBg, c.success),
    };

/// Bir bosishda bajarildi deb belgilanadigan vazifa qatori (Figma: "Tasks" kartasidagi qator).
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.r, this.showCrop = true, this.divider = false});
  final Reminder r;
  final bool showCrop, divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final overdue = !r.isCompleted && r.date.isBefore(_today());
    final meta = [
      if (showCrop && r.cropName != null) r.cropName!,
      overdue ? "Muddati o'tgan · ${formatDate(r.date)}" : (r.time != null ? r.time!.substring(0, 5) : 'Bugun'),
    ].join(' · ');
    final (bg, fg) = _typeColors(c, r.type);
    return InkWell(
      onTap: () async {
        try {
          await ref.read(gardenRepoProvider).toggleReminder(r.id);
          ref.invalidate(remindersProvider);
          if (r.cropId != null) ref.invalidate(cropProvider(r.cropId!));
        } catch (e) {
          if (context.mounted) showError(context, e);
        }
      },
      child: Container(
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: r.isCompleted ? c.success : Colors.transparent,
              shape: BoxShape.circle,
              border: r.isCompleted ? null : Border.all(color: overdue ? c.danger : c.border, width: 2),
            ),
            child: r.isCompleted ? Icon(AppIcons.check, size: 15, color: c.card) : null,
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(AppIcons.forReminder(r.type), size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: r.isCompleted ? c.muted : c.text,
                    decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                  )),
              const SizedBox(height: 2),
              Text(meta, style: TextStyle(fontSize: 12.5, color: overdue ? c.danger : c.muted, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// "Bugungi vazifalar" kartasi: muddati o'tgan + bugungi bajarilmaganlar, keyin bugun bajarilganlar (chizilgan).
/// cropId berilsa — faqat shu ekin.
class TodayTasks extends ConsumerWidget {
  const TodayTasks({super.key, this.cropId, this.limit = 4});
  final String? cropId;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return ref.watch(remindersProvider).maybeWhen(
          data: (all) {
            final t = _today();
            final due = dueTasks(all, cropId: cropId);
            final doneToday = all.where((r) => r.isCompleted && r.date == t && (cropId == null || r.cropId == cropId)).toList();
            final rows = [...due, ...doneToday];
            if (rows.isEmpty) {
              return AppCard(
                child: Row(children: [
                  Icon(AppIcons.check, color: c.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Bugun bajariladigan vazifa yo'q", style: TextStyle(color: c.muted, fontWeight: FontWeight.w600))),
                ]),
              );
            }
            final shown = rows.take(limit).toList();
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(children: [
                for (var i = 0; i < shown.length; i++) TaskTile(r: shown[i], showCrop: cropId == null, divider: i > 0),
                if (rows.length > limit)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('yana ${rows.length - limit} ta vazifa', style: TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
              ]),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
