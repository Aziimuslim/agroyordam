import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

const _rejected = '__rejected__';

/// Tashxisni tekshirish: AI ehtimollaridan tanlash yoki boshqa kasallik, rasm yaroqsiz; dehqonga izoh.
/// Yuborilgach navbatdagi keyingisi o'zi ochiladi.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<ReviewScreen> {
  final _comment = TextEditingController();
  String? _choice; // tanlangan sinf (ai_label) yoki _rejected
  Alternative? _other; // "Boshqa kasallik" orqali tanlangan
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String _nameOf(QueueItem i, String label) {
    if (_other?.label == label) return _other!.diseaseName ?? label;
    return i.alternatives.where((a) => a.label == label).firstOrNull?.diseaseName ?? label;
  }

  Future<void> _submit(QueueItem i) async {
    final choice = _choice ?? i.aiLabel;
    if (choice == null) return;
    final status = choice == _rejected ? 'rejected' : (choice == i.aiLabel ? 'confirmed' : 'corrected');
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(expertRepoProvider)
          .review(i.id, status: status, label: status == 'corrected' ? choice : null, comment: _comment.text);
      ref.invalidate(reviewQueueProvider);
      ref.invalidate(expertStatsProvider);
      if (!mounted) return;
      final done = switch (status) {
        'confirmed' => 'Tasdiqlandi',
        'corrected' => 'Tuzatildi',
        _ => 'Rad etildi',
      };
      if (next != null) {
        showToast(context, '$done. Keyingi tashxis');
        context.pushReplacement('/expert/review/${next.id}');
      } else {
        showToast(context, "$done. Navbat bo'sh");
        context.canPop() ? context.pop() : context.go('/expert');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOther(QueueItem i) async {
    final picked = await showModalBottomSheet<Alternative>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => _OtherDiseaseSheet(plantName: i.plantName),
    );
    if (picked != null) {
      setState(() {
        _choice = picked.label;
        if (!i.alternatives.any((a) => a.label == picked.label)) _other = picked;
      });
    }
  }

  void _zoom(String url) => showDialog(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Text(
              'Yopish uchun bosing',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = ref.watch(queueItemProvider(widget.id));
    final i = value.value;
    final choice = _choice ?? i?.aiLabel;
    final label = i == null || choice == null
        ? 'Tasdiqlash'
        : choice == _rejected
        ? 'Rad etish: rasm yaroqsiz'
        : choice == i.aiLabel
        ? "To'g'ri — tasdiqlash"
        : 'Tuzatish: ${_nameOf(i, choice)}';
    return PageShell(
      padBottom: false,
      bottom: i == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: choice == _rejected ? c.danger : c.expert,
                          foregroundColor: c.onExpert,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        onPressed: _busy || choice == null ? null : () => _submit(i),
                        icon: _busy
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onExpert))
                            : Icon(choice == _rejected ? Icons.block_rounded : AppIcons.check),
                        label: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      child: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(queueItemProvider(widget.id)),
        data: (i) {
          final url = AppConfig.mediaUrl(i.imageUrl);
          final alts = [...i.alternatives, if (_other != null) _other!];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopBar(title: 'Tashxisni tekshirish', subtitle: i.plantName),
              Semantics(
                button: true,
                label: 'Rasmni kattalashtirish',
                child: GestureDetector(
                  onTap: url == null ? null : () => _zoom(url),
                  child: Stack(
                    children: [
                      CatalogImage(url: url, width: double.infinity, height: 260, radius: AppRadius.lg),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(AppRadius.pill)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded, size: 15, color: Color(0xFFFFFFFF)),
                              SizedBox(width: 4),
                              Text('bosib kattalashtiring', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [i.farmerName, i.farmerRegion, timeAgo(i.diagnosedAt)].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (i.reviewRequested) const StatusTag("Dehqon so'radi", kind: StatusKind.expert, icon: Icons.send_outlined),
                ],
              ),
              if (i.reviewNote != null) ...[
                const SizedBox(height: 12),
                NoteBox(title: 'Dehqon izohi', text: i.reviewNote, icon: Icons.chat_bubble_outline_rounded),
              ],
              const SizedBox(height: 14),
              AppCard(
                shadow: false,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("AI JAVOBI — TO'G'RI KASALLIKNI TANLANG", style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 10),
                    if (alts.isEmpty) const Text("AI javob bermagan — «Boshqa kasallik» orqali tanlang."),
                    for (final a in alts) _AltTile(a: a, selected: choice == a.label, onTap: () => setState(() => _choice = a.label)),
                    const SizedBox(height: 4),
                    PillButton(
                      label: 'Boshqa kasallik tanlash',
                      icon: Icons.search_rounded,
                      style: PillStyle.outline,
                      block: true,
                      onPressed: () => _pickOther(i),
                    ),
                    const SizedBox(height: 8),
                    PillButton(
                      label: 'Rasm yaroqsiz',
                      icon: Icons.highlight_off_rounded,
                      style: PillStyle.outline,
                      fg: c.danger,
                      block: true,
                      onPressed: () => setState(() => _choice = _rejected),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Dehqonga izoh', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t
                      in choice == _rejected
                          ? const [
                              'Bargni yaqinroqdan, kunduzi suratga oling',
                              'Rasm xira chiqqan, qayta oling',
                              'Bitta bargni oq fonda suratga oling',
                            ]
                          : const [
                              'Pastki barglarni olib tashlang',
                              "Rejadagi dorini qo'llang",
                              "3 kundan keyin yangi rasm yuboring",
                              "Sug'orishni kamaytiring",
                            ])
                    ActionChip(
                      label: Text(t),
                      backgroundColor: c.card,
                      side: BorderSide(color: c.border),
                      shape: const StadiumBorder(),
                      onPressed: () {
                        final cur = _comment.text.trim();
                        _comment.text = cur.isEmpty ? '$t.' : '$cur $t.';
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _comment,
                minLines: 2,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(hintText: "Ixtiyoriy: dehqon tashxis sahifasida ko'radi", counterText: ''),
              ),
              const SizedBox(height: 12),
              Text(
                "Natija dehqonga bildirishnoma bo'lib boradi; rasm datasetga tasdiqlangan bo'lib tushadi.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _AltTile extends StatelessWidget {
  const _AltTile({required this.a, required this.selected, required this.onTap});
  final Alternative a;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = a.confidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        excludeSemantics: true,
        label: '${a.diseaseName ?? a.label}${pct != null ? ', ${pct.round()}%' : ''}',
        onTap: onTap,
        child: Material(
          color: selected ? c.expertBg : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: selected ? c.expert : c.border, width: selected ? 1.6 : 1),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? c.expert : c.subtle),
                  const SizedBox(width: 10),
                  CatalogImage(asset: CatalogImages.disease(a.label), width: 44, height: 44, radius: AppRadius.sm),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.diseaseName ?? a.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                        if (pct != null) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), minHeight: 5, color: c.expert, backgroundColor: c.cream2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (pct != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${pct.round()}%',
                      style: TextStyle(fontWeight: FontWeight.w800, color: c.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shu ekinning boshqa kasalliklari — ma'lumotnoma rasmlari bilan solishtirib tanlash.
class _OtherDiseaseSheet extends ConsumerWidget {
  const _OtherDiseaseSheet({this.plantName});
  final String? plantName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(diseasesProvider);
    final prefix = CatalogImages.plantPrefix[plantName];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => AsyncView(
        value: all,
        onRetry: () => ref.invalidate(diseasesProvider),
        data: (list) {
          final items = list.where((d) => d.aiLabel != null && (plantName == null || d.plantName == plantName)).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text('Boshqa kasallik', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                plantName == null
                    ? "Ma'lumotnomadagi rasmlar bilan solishtiring."
                    : "$plantName kasalliklari — ma'lumotnomadagi rasmlar bilan solishtiring.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              if (prefix != null)
                _SheetRow(
                  asset: CatalogImages.disease('${prefix}_healthy'),
                  title: "Sog'lom",
                  tag: const StatusTag("Sog'lom", kind: StatusKind.healthy),
                  onTap: () => Navigator.pop(ctx, Alternative(label: '${prefix}_healthy', diseaseName: "Sog'lom", healthy: true)),
                ),
              for (final d in items)
                _SheetRow(
                  asset: CatalogImages.disease(d.aiLabel),
                  url: AppConfig.mediaUrl(d.imageUrl),
                  title: d.name,
                  sub: plantName == null ? d.plantName : null,
                  tag: RiskTag(d.riskLevel),
                  onTap: () => Navigator.pop(ctx, Alternative(label: d.aiLabel!, diseaseId: d.id, diseaseName: d.name)),
                ),
              if (items.isEmpty) const EmptyNote("Bu ekin uchun ma'lumotnomada kasallik yo'q"),
            ],
          );
        },
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.title, required this.onTap, this.asset, this.url, this.sub, this.tag});
  final String title;
  final String? asset, url, sub;
  final Widget? tag;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    shadow: false,
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 10),
    onTap: onTap,
    child: Row(
      children: [
        CatalogImage(asset: asset, url: url, width: 64, height: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
              if (tag != null) Padding(padding: const EdgeInsets.only(top: 6), child: tag!),
            ],
          ),
        ),
      ],
    ),
  );
}
