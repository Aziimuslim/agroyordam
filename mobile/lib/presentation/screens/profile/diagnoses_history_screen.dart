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

/// Tashxis kartasidagi holat (foizsiz; AI ishonchi sog'lik emas).
({String label, IconData icon, Color bg, Color fg}) diagnosisStatus(BuildContext context, Diagnosis d) {
  final c = context.c;
  if (d.isHealthy) return (label: tr('Muammo aniqlanmadi'), icon: Icons.check_circle_rounded, bg: c.successBg, fg: c.success);
  if (d.lowConfidence || d.diseaseName == null) return (label: tr('Qayta tekshirish'), icon: Icons.refresh_rounded, bg: c.warningBg, fg: c.warning);
  return (label: tr("E'tibor kerak"), icon: Icons.error_rounded, bg: c.dangerBg, fg: c.danger);
}

/// "{kasallik} ehtimoli" / "Kasallik belgisi aniqlanmadi" — kasallik nomi tashxis ehtimoli sifatida (TZ S06/S08).
String diagnosisHeadline(Diagnosis d) => d.isHealthy ? tr('Kasallik belgisi aniqlanmadi') : trf('{0} ehtimoli', [d.diseaseName ?? tr('Aniqlanmadi')]);

/// S07 Tashxislar tarixi: qidiruv, Barchasi / Bog'imdagi / Sana filtri, Bugun va Avvalgi guruhlari,
/// "⋮" → yashirish (tasdiq va qaytarish), "Yangi tashxis" → S03.
class DiagnosesHistoryScreen extends ConsumerStatefulWidget {
  const DiagnosesHistoryScreen({super.key});
  @override
  ConsumerState<DiagnosesHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<DiagnosesHistoryScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    _search.clear();
    _filter = 'all';
    _range = null;
  });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    // Sana diapazoni: boshlanish ≤ tugash (picker o'zi kafolatlaydi), kelajak tanlanmaydi
    final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: now, initialDateRange: _range);
    if (r != null) {
      setState(() {
        _range = r;
        _filter = 'date';
      });
    }
  }

  Future<void> _hide(Diagnosis d) async {
    final ok = await confirm(
      context,
      tr('Tarixdan yashirish'),
      tr("Yozuv ro'yxatdan olinadi. Agronom javobi va ma'lumotlar saqlanadi, istalgan payt qaytarish mumkin."),
      ok: tr('Yashirish'),
    );
    if (!ok || !mounted) return;
    final repo = ref.read(gardenRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.hideDiagnosis(d.id);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    void refresh() {
      ref.invalidate(diagnosesProvider);
      ref.invalidate(cropsProvider);
      if (d.cropId != null) {
        ref.invalidate(cropProvider(d.cropId!));
        ref.invalidate(cropDiagnosesProvider(d.cropId!));
      }
    }

    refresh();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('Tashxis yashirildi')),
          action: SnackBarAction(
            label: tr('Qaytarish'),
            onPressed: () async {
              try {
                await repo.restoreDiagnosis(d.id);
                refresh();
              } catch (_) {
                messenger.showSnackBar(SnackBar(content: Text(tr("Bekor qilib bo'lmadi. Qayta urinib ko'ring"))));
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = ref.watch(diagnosesProvider);
    final crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final cropNames = {for (final x in crops) x.id: x.name};
    final q = _search.text.trim().toLowerCase();
    final list = value.value;

    Widget body;
    if (list == null && value.hasError) {
      body = BlockError(error: value.error!, what: tr('Tashxislar'), onRetry: () => ref.invalidate(diagnosesProvider));
    } else if (list == null) {
      body = const Column(children: [Skeleton(height: 96), SizedBox(height: 10), Skeleton(height: 96), SizedBox(height: 10), Skeleton(height: 96)]);
    } else if (list.isEmpty) {
      body = Column(
        children: [
          EmptyNote(tr("Hali tashxis qilinmagan"), icon: AppIcons.camera),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(0, 52)),
            onPressed: () => context.push('/diagnose'),
            icon: const Icon(AppIcons.scan),
            label: Text(tr('Birinchi tashxisni boshlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    } else {
      final shown = list.where((d) {
        if (_filter == 'garden' && d.cropId == null) return false;
        if (_filter == 'date' && _range != null && d.diagnosedAt != null) {
          final t = d.diagnosedAt!.toLocal();
          final day = DateTime(t.year, t.month, t.day);
          if (day.isBefore(_range!.start) || day.isAfter(_range!.end)) return false;
        }
        if (q.isEmpty) return true;
        final hay = [d.plantName, d.diseaseName, diagnosisHeadline(d), if (d.cropId != null) cropNames[d.cropId]].whereType<String>().join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
      if (shown.isEmpty) {
        body = Column(
          children: [
            EmptyNote(tr('Hech narsa topilmadi'), icon: Icons.search_off_rounded),
            TextButton(onPressed: _clear, child: Text(tr('Filtrni tozalash'))),
          ],
        );
      } else {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        bool isToday(Diagnosis d) => d.diagnosedAt != null && !d.diagnosedAt!.toLocal().isBefore(today);
        final todays = shown.where(isToday).toList();
        final older = shown.where((d) => !isToday(d)).toList();
        Widget group(String title, List<Diagnosis> items, {String? trailing}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
                      ),
                    ),
                  ),
                  if (trailing != null) Text(trailing, style: TextStyle(color: c.muted, fontSize: 14)),
                ],
              ),
            ),
            for (final d in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DiagnosisRow(d: d, cropName: d.cropId != null ? cropNames[d.cropId] : null, onHide: () => _hide(d)),
              ),
          ],
        );
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (q.isNotEmpty || _filter != 'all')
              Text(trf('{0} ta natija (jami {1})', [shown.length, list.length]), style: TextStyle(color: c.muted, fontSize: 14)),
            if (todays.isNotEmpty) group(tr('Bugun'), todays, trailing: formatDate(now)),
            if (older.isNotEmpty) group(tr('Avvalgi tashxislar'), older),
          ],
        );
      }
    }

    final dateLabel = _range == null ? tr('Sana') : '${formatDayMonth(_range!.start)} – ${formatDayMonth(_range!.end)}';
    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async => ref.invalidate(diagnosesProvider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(title: tr('Tashxislar tarixi')),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('Ekin yoki tashxisni qidirish...'),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(tooltip: tr('Tozalash'), icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
            ),
          ),
          const SizedBox(height: 12),
          ChipTabs(
            tabs: [('all', tr('Barchasi')), ('garden', tr("Bog'imdagi")), ('date', dateLabel)],
            selected: _filter,
            onSelect: (v) {
              if (v == 'date') {
                _pickRange();
              } else {
                setState(() {
                  _filter = v;
                  _range = null;
                });
              }
            },
          ),
          body,
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.push('/diagnose'),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: Text(tr('Yangi tashxis'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisRow extends StatelessWidget {
  const _DiagnosisRow({required this.d, required this.onHide, this.cropName});
  final Diagnosis d;
  final String? cropName;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = diagnosisStatus(context, d);
    final title = cropName ?? d.plantName ?? tr("Ekin turi aniqlanmagan");
    final local = d.diagnosedAt?.toLocal();
    final now = DateTime.now();
    final when = local == null
        ? ''
        : (local.year == now.year && local.month == now.month && local.day == now.day)
        ? '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}'
        : formatDate(local);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/diagnosis/${d.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
          child: Row(
            children: [
              ThumbIcon(icon: AppIcons.image, imageUrl: d.imageUrl, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '$title. ${diagnosisHeadline(d)}. ${s.label}. $when',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text),
                            ),
                          ),
                          Text(when, style: TextStyle(fontSize: 14, color: c.muted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diagnosisHeadline(d),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: c.muted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                        decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icon, size: 16, color: s.fg),
                            const SizedBox(width: 4),
                            // 320 px va uzun tarjimada toshib ketmasin (QA14)
                            Flexible(
                              child: Text(
                                s.label,
                                style: TextStyle(color: s.fg, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: tr('Amallar'),
                icon: Icon(Icons.more_vert_rounded, color: c.muted),
                onSelected: (_) => onHide(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'hide',
                    child: Row(children: [const Icon(Icons.visibility_off_outlined), const SizedBox(width: 12), Text(tr('Tarixdan yashirish'))]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
