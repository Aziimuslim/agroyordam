import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/crop_status.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../reminders/task_row.dart';
import '../reminders/today_tasks.dart' show dueTasks;
import 'crop_actions.dart';
import 'crop_photo.dart';

/// S06 Ekin tafsiloti: surat-header, holat (foizsiz), Umumiy / Vazifalar / Kundalik tablari.
/// Arxivlangan ekin — faqat ko'rish va "Tiklash". Butunlay o'chirish bu bosqichda yo'q (TZ S06).
class CropDetailScreen extends ConsumerStatefulWidget {
  const CropDetailScreen({super.key, required this.id, this.tab});
  final String id;
  final String? tab;
  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
  late String _tab = const {'overview', 'tasks', 'diary'}.contains(widget.tab) ? widget.tab! : 'overview';

  @override
  void didUpdateWidget(covariant CropDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && const {'overview', 'tasks', 'diary'}.contains(widget.tab)) _tab = widget.tab!;
  }

  Future<void> _refresh() async {
    ref.invalidate(cropProvider(widget.id));
    ref.invalidate(cropDiagnosesProvider(widget.id));
    ref.invalidate(cropLogsProvider(widget.id));
    ref.invalidate(remindersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = ref.watch(cropProvider(widget.id));
    final crop = value.value;
    if (crop == null) {
      final err = value.hasError ? ApiException.from(value.error!) : null;
      return PageShell(
        padBottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(title: tr('Ekin')),
          if (err == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (err.statusCode == 404 || err.statusCode == 403)
            // O'chirilgan yoki boshqa foydalanuvchining ekini (TZ 3)
            Column(children: [
              EmptyNote(tr("Topilmadi yoki kirish huquqi yo'q"), icon: Icons.search_off_rounded),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(0, 48)),
                onPressed: () => context.go('/garden'),
                child: Text(tr("Mening bog'imga qaytish")),
              ),
            ])
          else
            BlockError(error: value.error!, what: tr('Ekin'), onRetry: () => ref.invalidate(cropProvider(widget.id))),
        ]),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tabs = SegmentTabs(
      tabs: [('overview', tr('Umumiy')), ('tasks', tr('Vazifalar')), ('diary', tr('Kundalik'))],
      selected: _tab,
      onSelect: (v) => setState(() => _tab = v),
    );
    final content = switch (_tab) {
      'tasks' => _TasksTab(crop: crop),
      'diary' => _DiaryTab(crop: crop),
      _ => _OverviewTab(crop: crop, onTab: (t) => setState(() => _tab = t)),
    };
    return Scaffold(
      backgroundColor: c.cream,
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Hero(crop: crop, rounded: wide),
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 16, wide ? 0 : 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (crop.isArchived) _ArchivedBanner(crop: crop),
                    tabs,
                    const SizedBox(height: 16),
                    AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tab), child: content)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Header: surat, nom, holat, joy ----------------
class _Hero extends ConsumerWidget {
  const _Hero({required this.crop, required this.rounded});
  final Crop crop;
  final bool rounded;

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final c = context.c;
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            minTileHeight: 52,
            leading: Icon(crop.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(crop.isArchived ? tr('Arxivdan tiklash') : tr('Arxivlash')),
            onTap: () => Navigator.pop(ctx, crop.isArchived ? 'restore' : 'archive'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (r == 'archive') await archiveCrop(context, ref, crop);
    if (r == 'restore' && context.mounted) await restoreCrop(context, ref, crop);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final place = [crop.location, if (crop.area != null) trf('{0} sotix', [crop.area!.toStringAsFixed(crop.area! == crop.area!.roundToDouble() ? 0 : 1)])].whereType<String>().join(' · ');
    Widget glass({required Widget child, String? tooltip, required VoidCallback onTap}) => Tooltip(
          message: tooltip ?? '',
          child: Material(
            color: const Color(0xE6FFFFFF),
            shape: const StadiumBorder(),
            child: InkWell(customBorder: const StadiumBorder(), onTap: onTap, child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44, minHeight: 44), child: Center(child: child))),
          ),
        );
    const ink = Color(0xFF20251B); // oq "shisha" tugma ustidagi matn (har ikki mavzuda)
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(rounded ? 16 : 0), bottom: const Radius.circular(24)),
      child: SizedBox(
        height: 260 + top,
        child: Stack(fit: StackFit.expand, children: [
          Hero(tag: 'crop-${crop.id}', child: CropPhoto(crop: crop, iconSize: 72)),
          // Matn ostida qorong'i gradient — har qanday surat ustida o'qiladi
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                stops: [0, 0.3, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 12,
            right: 12,
            child: Row(children: [
              glass(
                tooltip: tr('Orqaga'),
                onTap: () => Navigator.of(context).canPop() ? Navigator.of(context).maybePop() : context.go('/garden'),
                child: const Icon(Icons.arrow_back_rounded, color: ink),
              ),
              const Spacer(),
              if (!crop.isArchived) ...[
                glass(
                  onTap: () => context.push('/garden/${crop.id}/edit'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.edit, size: 18, color: ink),
                      const SizedBox(width: 6),
                      Text(tr('Tahrirlash'), style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              glass(tooltip: tr("Ko'proq"), onTap: () => _more(context, ref), child: const Icon(Icons.more_vert_rounded, color: ink)),
            ]),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                header: true,
                child: Text(crop.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.15, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              CropStatusChip(crop: crop, withDate: true),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.place_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ArchivedBanner extends ConsumerWidget {
  const _ArchivedBanner({required this.crop});
  final Crop crop;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.archive_outlined, color: c.warning),
        const SizedBox(width: 12),
        Expanded(child: Text(tr("Arxivlangan ekin — tarixni faqat ko'rish mumkin"), style: TextStyle(color: c.warning, fontSize: 15, fontWeight: FontWeight.w600))),
        TextButton(onPressed: () => restoreCrop(context, ref, crop), child: Text(tr('Tiklash'))),
      ]),
    );
  }
}

// ---------------- Umumiy ----------------
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.crop, required this.onTab});
  final Crop crop;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final diags = ref.watch(cropDiagnosesProvider(crop.id));
    final logs = ref.watch(cropLogsProvider(crop.id));
    final reminders = ref.watch(remindersProvider);
    final last = diags.value?.isNotEmpty == true ? diags.value!.first : null;

    // Oxirgi tashxis
    Widget diagBlock;
    if (diags.value == null && diags.hasError) {
      diagBlock = BlockError(error: diags.error!, what: tr('Tashxislar'), onRetry: () => ref.invalidate(cropDiagnosesProvider(crop.id)));
    } else if (diags.value == null) {
      diagBlock = const Skeleton(height: 96);
    } else if (last == null) {
      diagBlock = AppCard(
        margin: EdgeInsets.zero,
        child: Row(children: [
          Icon(Icons.help_outline_rounded, color: c.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(tr("Bu ekin hali tekshirilmagan. Holatni bilish uchun barg suratini oling."), style: TextStyle(fontSize: 15, color: c.text))),
        ]),
      );
    } else {
      diagBlock = _DiagnosisTile(d: last);
    }

    // Bugungi ishlar
    Widget todayBlock;
    final all = reminders.value;
    if (all == null && reminders.hasError) {
      todayBlock = BlockError(error: reminders.error!, what: tr('Vazifalar'), onRetry: () => ref.invalidate(remindersProvider));
    } else if (all == null) {
      todayBlock = const Skeleton(height: 64);
    } else {
      final due = dueTasks(all, cropId: crop.id);
      todayBlock = due.isEmpty
          ? Text(tr("Bugun bu ekin uchun vazifa yo'q"), style: TextStyle(color: c.muted, fontSize: 15))
          : Column(children: [for (final r in due.take(3)) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskRow(r: r))]);
    }

    // So'nggi kuzatuv
    final lastLog = logs.value?.isNotEmpty == true ? logs.value!.first : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BlockTitle(tr('Oxirgi tashxis'), action: (diags.value?.length ?? 0) > 1 ? tr('Tarix') : null, onAction: () => context.push('/diagnoses')),
      diagBlock,
      const SizedBox(height: 24),
      BlockTitle(tr('Bugungi ishlar'), action: tr("Barchasini ko'rish"), onAction: () => onTab('tasks')),
      todayBlock,
      const SizedBox(height: 24),
      BlockTitle(tr("So'nggi kuzatuv"), action: tr("Barchasini ko'rish"), onAction: () => onTab('diary')),
      if (lastLog == null)
        Text(logs.isLoading ? '' : tr("Hali kuzatuv yozilmagan"), style: TextStyle(color: c.muted, fontSize: 15))
      else
        _LogTile(log: lastLog, onTap: () => onTab('diary')),
      const SizedBox(height: 24),
      _Facts(crop: crop),
      if (!crop.isArchived) ...[
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => context.push('/diagnose?crop=${crop.id}'),
            icon: const Icon(AppIcons.camera),
            label: Text(tr('Qayta tekshirish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        if (last != null && !last.isHealthy) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primaryDark,
                side: BorderSide(color: c.primary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.push('/diagnosis/${last.id}/plan'),
              icon: const Icon(Icons.event_note_outlined),
              label: Text(tr('Parvarish rejasini ochish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ],
    ]);
  }
}

class _DiagnosisTile extends StatelessWidget {
  const _DiagnosisTile({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Kasallik nomi — tashxis ehtimoli sifatida; AI ishonchi sog'lik foizi emas (TZ 1)
    final title = d.isHealthy ? tr('Kasallik belgisi aniqlanmadi') : trf('{0} ehtimoli', [d.diseaseName ?? tr('Aniqlanmadi')]);
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/diagnosis/${d.id}'),
      child: Row(children: [
        ThumbIcon(icon: AppIcons.image, imageUrl: d.imageUrl, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 2),
            Text([if (d.diagnosedAt != null) formatDate(d.diagnosedAt), if (d.expertChecked) tr('Agronom tekshirgan')].join(' · '),
                style: TextStyle(fontSize: 14, color: c.muted)),
          ]),
        ),
        Icon(AppIcons.chevron, color: c.muted),
      ]),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, this.onTap});
  final CropLog log;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(AppIcons.calendar, color: c.muted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text([if (log.createdAt != null) formatDate(log.createdAt), tr('Siz yozgan')].join(' · '),
                style: TextStyle(fontSize: 14, color: c.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(log.content, maxLines: onTap != null ? 3 : null, overflow: onTap != null ? TextOverflow.ellipsis : null,
                style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
          ]),
        ),
        if (onTap != null) Icon(AppIcons.chevron, color: c.muted),
      ]),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.crop});
  final Crop crop;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <(IconData, String, String)>[
      if (crop.plantName != null) (Icons.eco_outlined, tr('Ekin turi'), crop.plantName!),
      if (crop.variety != null) (Icons.local_florist_outlined, tr('Navi'), crop.variety!),
      if (crop.plantingDate != null) (AppIcons.calendar, tr('Ekilgan sana'), formatDate(crop.plantingDate)),
      if (crop.area != null) (Icons.straighten_rounded, tr('Maydon'), trf('{0} sotix', [crop.area])),
      if (crop.location != null) (Icons.place_outlined, tr('Joylashuv'), crop.location!),
    ];
    if (rows.isEmpty && (crop.notes ?? '').isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BlockTitle(tr("Ekin haqida")),
      AppCard(
        margin: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (icon, label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(icon, size: 20, color: c.muted),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: Text(label, style: TextStyle(color: c.muted, fontSize: 14))),
                Expanded(child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text))),
              ]),
            ),
          if ((crop.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(crop.notes!, style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
          ],
        ]),
      ),
    ]);
  }
}

// ---------------- Vazifalar ----------------
class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    // Ekin bo'yicha so'rov arxivlangan ekin vazifalarini ham qaytaradi (tarix)
    final value = ref.watch(cropRemindersProvider(crop.id));
    final all = value.value;
    if (all == null && value.hasError) {
      return BlockError(error: value.error!, what: tr('Vazifalar'), onRetry: () => ref.invalidate(cropRemindersProvider(crop.id)));
    }
    if (all == null) return const Column(children: [Skeleton(height: 64), SizedBox(height: 8), Skeleton(height: 64)]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = dueTasks(all, cropId: crop.id);
    final upcoming = all.where((r) => !r.isCompleted && r.date.isAfter(today)).toList()..sort((a, b) => a.date.compareTo(b.date));
    final done = all.where((r) => r.isCompleted).toList()..sort((a, b) => b.date.compareTo(a.date));

    Widget section(String title, List<Reminder> list) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Semantics(header: true, child: Text(trf('{0} ({1})', [title, list.length]), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text))),
          ),
          for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: TaskRow(r: r, readOnly: crop.isArchived)),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (all.isNotEmpty) ...[
        Semantics(
          label: trf('{0} tadan {1} tasi bajarildi', [all.length, done.length]),
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf('{0}/{1} vazifa bajarildi', [done.length, all.length]), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: done.length / all.length, minHeight: 10, backgroundColor: c.cream2, color: c.olive),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      if (all.isEmpty)
        EmptyNote(tr("Bu ekin uchun vazifa yo'q. Tashxisdan keyin parvarish rejasini boshlang yoki vazifa qo'shing."), icon: Icons.task_alt_rounded),
      if (due.isNotEmpty) section(tr('Bugun va kechikkan'), due),
      if (upcoming.isNotEmpty) section(tr('Keyingi vazifalar'), upcoming.take(10).toList()),
      if (done.isNotEmpty) section(tr('Bajarilgan'), done.take(10).toList()),
      if (!crop.isArchived) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => context.push('/reminders/add?crop=${crop.id}'),
            icon: const Icon(AppIcons.plus),
            label: Text(tr("Vazifa qo'shish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}

// ---------------- Kundalik (A04) ----------------
class _DiaryTab extends ConsumerWidget {
  const _DiaryTab({required this.crop});
  final Crop crop;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final text = await showSheet<String>(context, title: tr('Kuzatuv yozish'), builder: (ctx) {
      return StatefulBuilder(builder: (ctx, set) {
        final len = ctrl.text.trim().length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: ctrl,
            maxLines: 5,
            maxLength: 2000,
            autofocus: true,
            onChanged: (_) => set(() {}),
            decoration: InputDecoration(hintText: tr("Bugun nimani kuzatdingiz? (barglar, sug'orish, o'g'itlash...)")),
          ),
          const SizedBox(height: 12),
          PillButton(label: tr('Saqlash'), block: true, onPressed: len == 0 ? null : () => Navigator.pop(ctx, ctrl.text.trim())),
        ]);
      });
    });
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(gardenRepoProvider).addLog(crop.id, text);
      ref.invalidate(cropLogsProvider(crop.id));
      if (context.mounted) showToast(context, tr('Kuzatuv saqlandi'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final value = ref.watch(cropLogsProvider(crop.id));
    final list = value.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!crop.isArchived) ...[
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(tr("Kuzatuv qo'shish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (list == null && value.hasError)
        BlockError(error: value.error!, what: tr('Kundalik'), onRetry: () => ref.invalidate(cropLogsProvider(crop.id)))
      else if (list == null)
        const Skeleton(height: 96)
      else if (list.isEmpty)
        EmptyNote(tr("Hali kuzatuv yozilmagan"), icon: Icons.edit_note_rounded)
      else
        for (final l in list) _LogTile(log: l),
    ]);
  }
}
