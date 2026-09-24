import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

final _dsStatsProvider = FutureProvider.autoDispose((ref) => ref.watch(adminRepoProvider).datasetStats());
final _dsLabelsProvider = FutureProvider.autoDispose((ref) => ref.watch(adminRepoProvider).datasetLabels());
final _dsItemsProvider = FutureProvider.autoDispose.family<List<DatasetItem>, String>((ref, filter) {
  final repo = ref.watch(adminRepoProvider);
  return filter == 'flagged' ? repo.datasetItems(flagged: true) : repo.datasetItems(status: filter);
});

final _labelRe = RegExp(r'^[A-Z][A-Za-z]*_[A-Za-z0-9_]+$');

/// Dataset yig'ish: foydalanuvchilar yuklagan rasmlarni mutaxassis tekshiradi → tasdiqlanganlar modelni qayta o'qitishga.
class DatasetTab extends ConsumerStatefulWidget {
  const DatasetTab({super.key});
  @override
  ConsumerState<DatasetTab> createState() => _DatasetTabState();
}

class _DatasetTabState extends ConsumerState<DatasetTab> {
  String _filter = 'pending';
  bool _allLabels = false;
  final _done = <String>{};

  void _refresh() {
    _done.clear();
    ref.invalidate(_dsStatsProvider);
    ref.invalidate(_dsItemsProvider(_filter));
  }

  Future<void> _review(DatasetItem it, String status, {String? label}) async {
    try {
      await ref.read(adminRepoProvider).review(it.id, status, label: label);
      setState(() => _done.add(it.id));
      ref.invalidate(_dsStatsProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _correct(DatasetItem it) async {
    final labels = await ref.read(_dsLabelsProvider.future).catchError((_) => <String>[]);
    if (!mounted) return;
    final picked = await showSheet<String>(context, title: "To'g'ri sinfni tanlang", builder: (ctx) => _LabelPicker(labels: labels, initial: it.aiLabel));
    if (picked != null) await _review(it, 'corrected', label: picked);
  }

  Future<void> _export() async {
    try {
      final path = await ref.read(adminRepoProvider).exportLink();
      await launchUrl(Uri.parse('${AppConfig.apiUrl}$path'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AsyncView(
        value: ref.watch(_dsStatsProvider),
        onRetry: () => ref.invalidate(_dsStatsProvider),
        data: (s) => _StatsView(stats: s, allLabels: _allLabels, onToggle: () => setState(() => _allLabels = !_allLabels), onExport: _export),
      ),
      const SectionTitle('Tekshiruv navbati'),
      Row(children: [
        Expanded(
          child: ChipTabs(
            tabs: const [('pending', 'Kutilmoqda'), ('flagged', '"Xato" deganlar'), ('usable', 'Tasdiqlangan'), ('rejected', 'Rad etilgan')],
            selected: _filter,
            onSelect: (v) => setState(() {
              _filter = v;
              _done.clear();
            }),
          ),
        ),
        CircleIconButton(icon: Icons.refresh_rounded, tooltip: 'Yangilash', onTap: _refresh),
      ]),
      AsyncView(
        value: ref.watch(_dsItemsProvider(_filter)),
        onRetry: () => ref.invalidate(_dsItemsProvider(_filter)),
        data: (items) {
          final left = items.where((i) => !_done.contains(i.id)).toList();
          if (left.isEmpty) {
            return EmptyNote(items.isEmpty ? "Bu bo'limda rasm yo'q" : "Hammasi ko'rib chiqildi — yangilash tugmasini bosing", icon: AppIcons.check);
          }
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final it in left)
              SizedBox(
                width: 250,
                child: _ItemCard(
                  item: it,
                  reviewing: _filter == 'pending' || _filter == 'flagged',
                  onConfirm: it.aiLabel == null ? null : () => _review(it, 'confirmed'),
                  onCorrect: () => _correct(it),
                  onReject: () => _review(it, 'rejected'),
                  onReset: () => _review(it, 'pending'),
                ),
              ),
          ]);
        },
      ),
      const SizedBox(height: 12),
      Text(
        "Mutaxassis (agronom) har bir rasmni tekshiradi: AI to'g'ri bo'lsa — \"To'g'ri\", xato bo'lsa — to'g'ri sinfni tanlaydi, "
        "rasm yaroqsiz bo'lsa (barg ko'rinmaydi, boshqa narsa) — \"Yaroqsiz\". Faqat tasdiqlangan rasmlar eksport qilinadi.",
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
    ]);
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats, required this.allLabels, required this.onToggle, required this.onExport});
  final Map<String, dynamic> stats;
  final bool allLabels;
  final VoidCallback onToggle, onExport;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final target = stats['target_per_label'] as int;
    final labels = (stats['labels'] as List).cast<Map>();
    final shown = allLabels ? labels : labels.take(8).toList();
    Widget tile(String label, Object? value, IconData icon, {Color? color}) => SizedBox(
          width: 200,
          child: AppCard(
            margin: EdgeInsets.zero,
            child: Row(children: [
              ThumbIcon(icon: icon, size: 40, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${value ?? '—'}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color ?? c.primary)),
                  Text(label, style: TextStyle(fontSize: 11.5, color: c.muted, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        );
    final acc = stats['ai_field_accuracy'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle("Dala dataseti"),
      Wrap(spacing: 12, runSpacing: 12, children: [
        tile('Tekshiruv kutmoqda', stats['pending'], AppIcons.history),
        tile('"Xato" deb belgilangan', stats['flagged_pending'], Icons.thumb_down_alt_outlined, color: c.danger),
        tile('Tasdiqlangan rasm', stats['usable'], AppIcons.check, color: c.success),
        tile('AI dala aniqligi', acc == null ? null : '$acc%', AppIcons.chart),
      ]),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Sinflar bo'yicha (maqsad: har biriga $target ta)", style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (labels.isEmpty) Text("Hali tasdiqlangan rasm yo'q", style: TextStyle(color: c.muted)),
          for (final l in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(width: 210, child: Text('${l['label']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((l['count'] as int) / target).clamp(0, 1).toDouble(),
                      minHeight: 10,
                      backgroundColor: c.cream2,
                      color: (l['count'] as int) >= target ? c.success : c.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 60, child: Text('${l['count']}/$target', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
              ]),
            ),
          if (labels.length > 8)
            TextButton(onPressed: onToggle, child: Text(allLabels ? "Yig'ish" : "Barcha ${labels.length} sinf", style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            PillButton(
              label: 'ZIP yuklab olish (${stats['usable']} ta rasm)',
              icon: Icons.download_rounded,
              style: PillStyle.primary,
              onPressed: (stats['usable'] as int) > 0 ? onExport : null,
            ),
            Text("Qayta o'qitish: GitHub > Actions > \"Train AI model\" > dataset_url", style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ]),
      ),
    ]);
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.reviewing, required this.onCorrect, required this.onReject, required this.onReset, this.onConfirm});
  final DatasetItem item;
  final bool reviewing;
  final VoidCallback? onConfirm;
  final VoidCallback onCorrect, onReject, onReset;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = AppConfig.mediaUrl(item.imageUrl);
    return Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: softShadow(context, 8)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 1,
          child: url == null ? Container(color: c.tan) : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.tan)),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(item.verifiedLabel ?? item.aiLabel ?? 'Sinf yo\'q',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5), overflow: TextOverflow.ellipsis),
              ),
              if (item.userFeedback == false) Tag('Xato', bg: c.dangerBg, fg: c.danger),
              if (item.userFeedback == true) Tag("To'g'ri", bg: c.successBg, fg: c.success),
            ]),
            Text(
              [
                if (item.diseaseName != null) item.diseaseName!,
                if (item.confidence != null) 'AI ${item.confidence!.toStringAsFixed(0)}%',
                if (item.verifiedLabel != null && item.verifiedLabel != item.aiLabel) 'AI: ${item.aiLabel ?? '—'}',
                formatDate(item.diagnosedAt),
              ].join(' · '),
              style: TextStyle(color: c.muted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            if (reviewing)
              Wrap(spacing: 6, runSpacing: 6, children: [
                MiniButton(label: "To'g'ri", icon: AppIcons.check, filled: true, onTap: onConfirm),
                MiniButton(label: 'Tuzatish', icon: AppIcons.edit, onTap: onCorrect),
                MiniButton(label: 'Yaroqsiz', icon: Icons.block_rounded, onTap: onReject),
              ])
            else
              MiniButton(label: 'Qayta tekshirishga', icon: Icons.undo_rounded, onTap: onReset),
          ]),
        ),
      ]),
    );
  }
}

class _LabelPicker extends StatefulWidget {
  const _LabelPicker({required this.labels, this.initial});
  final List<String> labels;
  final String? initial;
  @override
  State<_LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends State<_LabelPicker> {
  late final _q = TextEditingController(text: widget.initial?.split('_').first ?? '');

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _q.text.trim().toLowerCase();
    final found = widget.labels.where((l) => l.toLowerCase().contains(q)).toList();
    final custom = _q.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _q,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Qidirish yoki yangi sinf: Ekin_Kasallik', prefixIcon: Icon(Icons.search_rounded)),
      ),
      const SizedBox(height: 10),
      if (custom.isNotEmpty && !widget.labels.contains(custom) && _labelRe.hasMatch(custom))
        ListRow(icon: AppIcons.plus, label: 'Yangi sinf: $custom', onTap: () => Navigator.pop(context, custom)),
      for (final l in found.take(40))
        ListRow(icon: l.endsWith('healthy') ? AppIcons.leaf : AppIcons.virus, label: l, chevron: false, onTap: () => Navigator.pop(context, l)),
      if (found.isEmpty) Text("Topilmadi. Yangi sinf nomini Ekin_Kasallik ko'rinishida yozing (masalan Cucumber_Downy_mildew).", style: TextStyle(color: c.muted, fontSize: 12.5)),
    ]);
  }
}
