import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/crop_status.dart' show shortDate;
import '../../../domain/entities/entities.dart';
import 'task_sheet.dart';

/// Vazifa qatori (S01/S06/S25): alohida 48 px checkbox (server tasdig'idan keyin o'zgaradi),
/// qatorning o'zi → A03 vazifa tafsiloti.
class TaskRow extends ConsumerStatefulWidget {
  const TaskRow({super.key, required this.r, this.readOnly = false});
  final Reminder r;

  /// Arxivlangan ekin: holatni o'zgartirib bo'lmaydi, faqat ko'rish.
  final bool readOnly;
  @override
  ConsumerState<TaskRow> createState() => TaskRowState();
}

class TaskRowState extends ConsumerState<TaskRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.r;
    final now = DateTime.now();
    final overdue = !r.isCompleted && r.date.isBefore(DateTime(now.year, now.month, now.day));
    final time = overdue ? tr("Kechikkan") : (r.time != null ? r.time!.substring(0, 5) : tr('Bugun'));
    final meta = [if (r.cropName != null) r.cropName!, if (overdue) shortDate(r.date)].join(' · ');
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTaskSheet(context, r),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(children: [
            // Checkbox — alohida 48 px bosish maydoni; holat server tasdig'idan keyin
            Semantics(
              checked: r.isCompleted,
              button: true,
              label: r.isCompleted ? trf('{0}: bajarilgan. Qaytarish', [r.title]) : trf('{0}: bajarildi deb belgilash', [r.title]),
              excludeSemantics: true,
              child: InkResponse(
                radius: 24,
                onTap: _busy || widget.readOnly
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await toggleTask(context, ref, r);
                        if (mounted) setState(() => _busy = false);
                      },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: r.isCompleted ? c.olive : Colors.transparent,
                              shape: BoxShape.circle,
                              border: r.isCompleted ? null : Border.all(color: overdue ? c.danger : c.lineStrong, width: 2),
                            ),
                            child: r.isCompleted ? Icon(AppIcons.check, size: 17, color: c.onOlive) : null,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(time,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: overdue ? c.danger : c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: r.isCompleted ? c.muted : c.text,
                        decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                      )),
                  if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: overdue ? c.danger : c.muted)),
                ]),
              ),
            ),
            Icon(AppIcons.chevron, color: c.muted),
          ]),
        ),
      ),
    );
  }
}

