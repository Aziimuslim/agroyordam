import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Vazifani bajarildi/bajarilmadi qilish. Holat faqat server tasdig'idan keyin o'zgaradi (TZ 4);
/// bog'liq ro'yxatlar (S01, S25, S06) yangilanadi. Muvaffaqiyatda "Bekor qilish" taklif qilinadi.
Future<bool> toggleTask(BuildContext context, WidgetRef ref, Reminder r, {bool offerUndo = true}) async {
  final repo = ref.read(gardenRepoProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await repo.toggleReminder(r.id);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
  ref.invalidate(remindersProvider);
  if (r.cropId != null) ref.invalidate(cropProvider(r.cropId!));
  if (offerUndo && messenger != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(r.isCompleted ? tr('Vazifa qayta ochildi') : tr('Vazifa bajarildi')),
        action: SnackBarAction(
          label: tr('Bekor qilish'),
          onPressed: () async {
            try {
              await repo.toggleReminder(r.id);
              ref.invalidate(remindersProvider);
              if (r.cropId != null) ref.invalidate(cropProvider(r.cropId!));
            } catch (_) {
              messenger.showSnackBar(SnackBar(content: Text(tr("Bekor qilib bo'lmadi. Qayta urinib ko'ring"))));
            }
          },
        ),
      ));
  }
  return true;
}

/// A03 Vazifa tafsiloti — pastki oyna: ekin, muddat, izoh, holat; bajarish/qaytarish, o'chirish.
Future<void> showTaskSheet(BuildContext context, Reminder r) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _TaskSheet(r: r),
    );

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({required this.r});
  final Reminder r;
  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final ok = await toggleTask(context, ref, widget.r);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr("Vazifani o'chirasizmi?")),
        content: Text(widget.r.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Bekor qilish'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(tr("O'chirish"), style: TextStyle(color: context.c.danger))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(gardenRepoProvider).deleteReminder(widget.r.id);
      ref.invalidate(remindersProvider);
      if (widget.r.cropId != null) ref.invalidate(cropProvider(widget.r.cropId!));
      if (mounted) {
        Navigator.of(context).pop();
        showToast(context, tr("Vazifa o'chirildi"));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.r;
    final now = DateTime.now();
    final overdue = !r.isCompleted && r.date.isBefore(DateTime(now.year, now.month, now.day));
    final (statusText, statusBg, statusFg) = r.isCompleted
        ? (tr('Bajarildi'), c.successBg, c.success)
        : overdue
            ? (tr("Muddati o'tgan"), c.dangerBg, c.danger)
            : (tr('Kutilmoqda'), c.warningBg, c.warning);
    Widget row(IconData icon, String label, String value, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Icon(icon, size: 20, color: c.muted),
              const SizedBox(width: 12),
              SizedBox(width: 96, child: Text(label, style: TextStyle(color: c.muted, fontSize: 14))),
              Expanded(
                child: Text(value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onTap != null ? c.primary : c.text,
                        decoration: onTap != null ? TextDecoration.underline : null)),
              ),
              if (onTap != null) Icon(AppIcons.chevron, color: c.muted),
            ]),
          ),
        );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Tag(statusText, bg: statusBg, fg: statusFg),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text(r.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text))),
        const SizedBox(height: 12),
        row(AppIcons.forReminder(r.type), tr('Turi'), reminderTypeLabels[r.type] ?? tr('Parvarish')),
        row(AppIcons.calendar, tr('Muddat'), [formatDate(r.date), if (r.time != null) r.time!.substring(0, 5)].join(' · ')),
        if (r.cropId != null)
          row(AppIcons.leaf, tr('Ekin'), r.cropName ?? tr('Ekin'), onTap: () {
            Navigator.of(context).pop();
            context.push('/garden/${r.cropId}');
          }),
        if (r.diagnosisId != null)
          row(AppIcons.history, tr('Manba'), tr('AI tashxis va parvarish rejasi'), onTap: () {
            Navigator.of(context).pop();
            context.push('/diagnosis/${r.diagnosisId}');
          }),
        if ((r.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tr('Izoh'), style: TextStyle(color: c.muted, fontSize: 14)),
          const SizedBox(height: 4),
          Text(r.description!, style: TextStyle(fontSize: 16, height: 1.45, color: c.text)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: r.isCompleted ? c.cream2 : c.primary,
              foregroundColor: r.isCompleted ? c.text : c.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy ? null : _toggle,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(r.isCompleted ? Icons.undo_rounded : AppIcons.check),
            label: Text(r.isCompleted ? tr('Bajarilmagan deb qaytarish') : tr('Bajarildi deb belgilash'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: _busy ? null : _delete,
            icon: const Icon(AppIcons.trash),
            label: Text(tr("O'chirish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
