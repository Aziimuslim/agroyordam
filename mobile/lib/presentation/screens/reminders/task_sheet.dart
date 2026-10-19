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

/// Vazifa o'zgarganda bog'liq ro'yxatlar (S01, S04, S06, S25) sinxron yangilanadi.
void refreshTasks(WidgetRef ref, {String? cropId}) {
  ref.invalidate(remindersProvider);
  ref.invalidate(cropRemindersProvider);
  ref.invalidate(reminderProvider);
  if (cropId != null) ref.invalidate(cropProvider(cropId));
}

/// "Har kuni" / "Har hafta" / "Har oy" / "Har 3 kunda" (+ "· 30-noyabrgacha").
String? repeatLabel(Reminder r) {
  final base = switch (r.repeat) {
    'daily' => tr('Har kuni'),
    'weekly' => tr('Har hafta'),
    'monthly' => tr('Har oy'),
    'custom' => trf('Har {0} kunda', [r.repeatEvery ?? 1]),
    _ => null,
  };
  if (base == null) return null;
  return r.repeatUntil == null ? base : '$base · ${trf('{0} gacha', [formatDayMonth(r.repeatUntil!)])}';
}

String remindBeforeLabel(int minutes) => switch (minutes) {
      0 => tr('Aynan vaqtida'),
      < 60 => trf('Vaqtidan {0} daqiqa oldin', [minutes]),
      < 1440 => trf('Vaqtidan {0} soat oldin', [minutes ~/ 60]),
      _ => trf('Vaqtidan {0} kun oldin', [minutes ~/ 1440]),
    };

/// Seriyadagi vazifa uchun: faqat shu yoki shu va keyingilar. null — bekor qilindi.
Future<String?> askSeriesScope(BuildContext context, {required String title}) => showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ctx.c.text)),
          ),
          ListTile(minTileHeight: 52, leading: const Icon(Icons.event_outlined), title: Text(tr('Faqat shu vazifa')), onTap: () => Navigator.pop(ctx, 'one')),
          ListTile(minTileHeight: 52, leading: const Icon(Icons.event_repeat_outlined), title: Text(tr('Shu va keyingi takrorlar')), onTap: () => Navigator.pop(ctx, 'future')),
          const SizedBox(height: 8),
        ]),
      ),
    );

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
  refreshTasks(ref, cropId: r.cropId);
  if (offerUndo && messenger != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(r.isCompleted ? tr('Vazifa qayta ochildi') : tr('Vazifa bajarildi')),
          action: SnackBarAction(
            label: tr('Bekor qilish'),
            onPressed: () async {
              try {
                await repo.toggleReminder(r.id);
                refreshTasks(ref, cropId: r.cropId);
              } catch (_) {
                messenger.showSnackBar(SnackBar(content: Text(tr("Bekor qilib bo'lmadi. Qayta urinib ko'ring"))));
              }
            },
          ),
        ),
      );
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
    final r = widget.r;
    String scope = 'one';
    if (r.isSeries) {
      final picked = await askSeriesScope(context, title: tr("Qaysi vazifalarni o'chirasiz?"));
      if (picked == null || !mounted) return;
      scope = picked;
    }
    final yes = await confirm(context, scope == 'future' ? tr("Takrorlarni o'chirasizmi?") : tr("Vazifani o'chirasizmi?"), r.title,
        ok: tr("O'chirish"), danger: true);
    if (!yes || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(gardenRepoProvider).deleteReminder(r.id, scope: scope);
      refreshTasks(ref, cropId: r.cropId);
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
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.muted),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? c.primary : c.text,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (onTap != null) Icon(AppIcons.chevron, color: c.muted),
          ],
        ),
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Tag(statusText, bg: statusBg, fg: statusFg),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(
              r.title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text),
            ),
          ),
          const SizedBox(height: 12),
          row(AppIcons.forReminder(r.type), tr('Turi'), reminderTypeLabels[r.type] ?? tr('Parvarish')),
          row(AppIcons.calendar, tr('Muddat'), [formatDate(r.date), r.time != null ? r.time!.substring(0, 5) : tr("Kun bo'yi")].join(' · ')),
          if (repeatLabel(r) != null) row(Icons.event_repeat_outlined, tr('Takrorlash'), repeatLabel(r)!),
          if (r.remindBefore != null) row(AppIcons.bell, tr('Eslatish'), remindBeforeLabel(r.remindBefore!)),
          if (r.isCompleted && r.completedAt != null)
            row(Icons.task_alt_rounded, tr('Bajarildi'), [formatDate(r.completedAt), hhmmLocal(r.completedAt!)].join(' · ')),
          if (r.cropId != null)
            row(
              AppIcons.leaf,
              tr('Ekin'),
              r.cropName ?? tr('Ekin'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/garden/${r.cropId}');
              },
            ),
          if (r.diagnosisId != null)
            row(
              AppIcons.history,
              tr('Manba'),
              tr('AI tashxis va parvarish rejasi'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/diagnosis/${r.diagnosisId}');
              },
            ),
          if ((r.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr('Izoh'), style: TextStyle(color: c.muted, fontSize: 14)),
            const SizedBox(height: 4),
            Text(r.description!, style: TextStyle(fontSize: 16, height: 1.45, color: c.text)),
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
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
              label: Text(
                r.isCompleted ? tr('Bajarilmagan deb qaytarish') : tr('Bajarildi deb belgilash'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primaryDark,
                side: BorderSide(color: c.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      context.push('/reminders/${r.id}/edit');
                    },
              icon: const Icon(AppIcons.edit),
              label: Text(tr('Tahrirlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
