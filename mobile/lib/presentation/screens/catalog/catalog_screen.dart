import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'catalog_common.dart';

const _tabs = {'plants', 'diseases', 'medicines'};

/// S17–S19 Ma'lumotnoma: O'simliklar / Kasalliklar / Dorilar — bitta katalog stekida.
/// Har tabning qidiruvi va filtri alohida saqlanadi (tab almashganda yo'qolmaydi).
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.tab = 'plants'});
  final String tab;
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<CatalogScreen> {
  late String _tab = _tabs.contains(widget.tab) ? widget.tab : 'plants';
  final _q = {for (final t in _tabs) t: TextEditingController()};
  final _filter = {for (final t in _tabs) t: 'all'};

  @override
  void didUpdateWidget(covariant CatalogScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && _tabs.contains(widget.tab)) _tab = widget.tab;
  }

  @override
  void dispose() {
    for (final c in _q.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear() => setState(() {
        _q[_tab]!.clear();
        _filter[_tab] = 'all';
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _q[_tab]!.text.trim().toLowerCase();
    final hint = switch (_tab) {
      'diseases' => tr('Kasallik nomini qidirish...'),
      'medicines' => tr('Dori yoki faol moddani qidirish...'),
      _ => tr("O'simlik nomini qidirish..."),
    };
    final body = switch (_tab) {
      'diseases' => _DiseasesTab(q: q, filter: _filter['diseases']!, onFilter: (v) => setState(() => _filter['diseases'] = v), onClear: _clear),
      'medicines' => _MedicinesTab(q: q, filter: _filter['medicines']!, onFilter: (v) => setState(() => _filter['medicines'] = v), onClear: _clear),
      _ => _PlantsTab(q: q, filter: _filter['plants']!, onFilter: (v) => setState(() => _filter['plants'] = v), onClear: _clear),
    };
    return PageShell(
      padBottom: false,
      maxWidth: 1000,
      onRefresh: () async {
        ref.invalidate(plantsProvider);
        ref.invalidate(diseasesProvider);
        ref.invalidate(medicinesProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr("Ma'lumotnoma"), subtitle: tr('Ekinlar haqida bilimlar')),
        TextField(
          key: ValueKey('q-$_tab'),
          controller: _q[_tab],
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.search_rounded, color: c.muted),
            suffixIcon: _q[_tab]!.text.isEmpty
                ? null
                : IconButton(tooltip: tr('Tozalash'), icon: const Icon(Icons.close_rounded), onPressed: () => setState(_q[_tab]!.clear)),
          ),
        ),
        const SizedBox(height: 12),
        SegmentTabs(
          tabs: [('plants', tr("O'simliklar")), ('diseases', tr('Kasalliklar')), ('medicines', tr('Dorilar'))],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tab), child: body)),
      ]),
    );
  }
}

Widget _grid(BuildContext context, List<Widget> children, {double min = 160}) => LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / min).floor().clamp(2, 5);
      const gap = 12.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
    });

/// Filtr yoki qidiruv qo'llanganda: natija soni va umumiy son (tanlangan chip ekrandan chiqib ketsa ham kontekst ko'rinadi).
Widget _count(BuildContext context, int shown, int total, bool active, VoidCallback onClear) => !active
    ? const SizedBox.shrink()
    : Row(children: [
        Expanded(child: Text(trf('{0} ta natija (jami {1})', [shown, total]), style: TextStyle(fontSize: 14, color: context.c.muted))),
        TextButton(onPressed: onClear, child: Text(tr('Tozalash'))),
      ]);

Widget _empty(String text, VoidCallback onClear) => Column(children: [
      EmptyNote(text, icon: Icons.search_off_rounded),
      TextButton(onPressed: onClear, child: Text(tr('Filtrni tozalash'))),
    ]);

Widget _loading(AsyncValue v, VoidCallback retry, String what, Widget Function() data) {
  if (v.value != null) return data();
  if (v.hasError) return BlockError(error: v.error!, what: what, onRetry: retry);
  return const Column(children: [Skeleton(height: 120), SizedBox(height: 10), Skeleton(height: 120)]);
}

// ---------- S17 O'simliklar ----------
class _PlantsTab extends ConsumerWidget {
  const _PlantsTab({required this.q, required this.filter, required this.onFilter, required this.onClear});
  final String q, filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsProvider);
    final diseases = ref.watch(diseasesProvider).value ?? const <Disease>[];
    return _loading(plants, () => ref.invalidate(plantsProvider), tr("O'simliklar"), () {
      final list = plants.value!;
      // Faqat katalogda bor toifalar chiqadi
      final cats = [for (final k in const ['vegetable', 'fruit', 'vine', 'grain', 'berry', 'melon']) if (list.any((p) => p.category == k)) k];
      final shown = list.where((p) => (filter == 'all' || p.category == filter) &&
          (q.isEmpty || p.name.toLowerCase().contains(q) || (p.scientificName ?? '').toLowerCase().contains(q))).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChipTabs(tabs: [('all', tr('Barchasi')), for (final k in cats) (k, plantCategoryLabel(k))], selected: filter, onSelect: onFilter),
        _count(context, shown.length, list.length, filter != 'all' || q.isNotEmpty, onClear),
        if (shown.isEmpty)
          _empty(tr('Hech narsa topilmadi'), onClear)
        else
          _grid(context, [for (final p in shown) _PlantCard(p: p, diseases: diseases.where((d) => d.plantId == p.id).length)]),
      ]);
    });
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.p, required this.diseases});
  final Plant p;
  final int diseases;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: '${p.name}. ${plantCategoryLabel(p.category)}. ${trf('{0} ta kasallik', [diseases])}',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/catalog/plant/${p.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              // Rasm yo'q bo'lsa — nomli o'rinbosar (TZ S17)
              child: CatalogImage(asset: CatalogImages.plant(p.name), url: AppConfig.mediaUrl(p.imageUrl), radius: 0, placeholderText: p.name),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 4),
                    InfoChip(icon: plantCategoryIcon(p.category), label: plantCategoryLabel(p.category)),
                    const SizedBox(height: 4),
                    Text(trf('{0} ta kasallik', [diseases]), style: TextStyle(fontSize: 14, color: c.muted)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------- S18 Kasalliklar ----------
class _DiseasesTab extends ConsumerWidget {
  const _DiseasesTab({required this.q, required this.filter, required this.onFilter, required this.onClear});
  final String q, filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final diseases = ref.watch(diseasesProvider);
    return _loading(diseases, () => ref.invalidate(diseasesProvider), tr('Kasalliklar'), () {
      final list = diseases.value!;
      final names = {for (final d in list) if (d.plantName != null) d.plantName!}.toList()..sort();
      final shown = list.where((d) => (filter == 'all' || d.plantName == filter) &&
          (q.isEmpty || d.name.toLowerCase().contains(q) || (d.symptoms ?? '').toLowerCase().contains(q))).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChipTabs(tabs: [('all', tr('Barchasi')), for (final n in names) (n, n)], selected: filter, onSelect: onFilter),
        _count(context, shown.length, list.length, filter != 'all' || q.isNotEmpty, onClear),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.menu_book_outlined, color: c.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tr("Belgilar ob-havo va ekin turiga qarab turlicha ko'rinadi. Rasm yakuniy tashxis emas — shubha bo'lsa ekinni tekshiring."),
                  style: TextStyle(color: c.warning, fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        if (shown.isEmpty)
          _empty(tr('Hech narsa topilmadi'), onClear)
        else
          for (final d in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: DiseaseCard(d: d)),
      ]);
    });
  }
}

/// Kasallik kartasi (S18, S20): rasm, nom, ekin, qisqa belgi.
class DiseaseCard extends StatelessWidget {
  const DiseaseCard({super.key, required this.d, this.showPlant = true});
  final Disease d;
  final bool showPlant;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sub = [if (showPlant) d.plantName, d.symptoms].whereType<String>().join(' · ');
    return Semantics(
      button: true,
      label: '${d.name}. $sub',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => context.push('/catalog/disease/${d.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              CatalogImage(asset: CatalogImages.disease(d.aiLabel), url: AppConfig.mediaUrl(d.imageUrl), width: 76, height: 76, radius: 12, placeholderText: tr("Rasm yo'q")),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                  if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted, height: 1.3)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- S19 Dorilar ----------
class _MedicinesTab extends ConsumerWidget {
  const _MedicinesTab({required this.q, required this.filter, required this.onFilter, required this.onClear});
  final String q, filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final meds = ref.watch(medicinesProvider);
    return _loading(meds, () => ref.invalidate(medicinesProvider), tr('Dorilar'), () {
      final list = meds.value!;
      final cats = [for (final k in const ['fungicide', 'insecticide', 'acaricide', 'biological']) if (list.any((m) => m.category == k)) k];
      final shown = list.where((m) => (filter == 'all' || m.category == filter) &&
          (q.isEmpty || m.name.toLowerCase().contains(q) || (m.activeIngredient ?? '').toLowerCase().contains(q))).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          button: true,
          child: Material(
            color: c.warningBg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showSafetySheet(context),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: c.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr("Qo'llashdan oldin yorliq va mutaxassis tavsiyasini tekshiring."),
                        style: TextStyle(color: c.warning, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.warning),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChipTabs(tabs: [('all', tr('Barchasi')), for (final k in cats) (k, medicineCategory(k).label)], selected: filter, onSelect: onFilter),
        _count(context, shown.length, list.length, filter != 'all' || q.isNotEmpty, onClear),
        if (shown.isEmpty)
          _empty(tr('Hech narsa topilmadi'), onClear)
        else
          for (final m in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: MedicineCard(m: m)),
      ]);
    });
  }
}

/// Dori kartasi (S19, S21): toifa va tur yorlig'i; doza ko'rsatilmaydi.
class MedicineCard extends StatelessWidget {
  const MedicineCard({super.key, required this.m});
  final Medicine m;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cat = medicineCategory(m.category);
    final kind = medicineKindLabel(m.kind);
    return Semantics(
      button: true,
      label: [m.name, m.activeIngredient, cat.label, kind].whereType<String>().join('. '),
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => context.push('/catalog/medicine/${m.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: c.oliveSoft, shape: BoxShape.circle),
                child: Icon(cat.icon, color: c.onOliveSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                  if (m.activeIngredient != null) Text(m.activeIngredient!, style: TextStyle(fontSize: 14, color: c.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    InfoChip(icon: cat.icon, label: cat.label),
                    if (kind != null) InfoChip(icon: Icons.label_outline_rounded, label: kind, bg: c.cream2, fg: c.text),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ehtiyot eslatmasi → ma'lumot va manbalar oynasi (TZ S19: A05 ma'lumotiga, S22 ga emas).
Future<void> showSafetySheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) {
        final c = ctx.c;
        Widget item(IconData i, String t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i, color: c.olive),
                const SizedBox(width: 12),
                Expanded(child: Text(t, style: TextStyle(fontSize: 16, height: 1.45, color: c.text))),
              ]),
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr("Dorilar haqida ma'lumot"), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 12),
              item(Icons.menu_book_outlined, tr("Ma'lumotnoma tanishish uchun. Dorini tanlash va qo'llashda mutaxassis tavsiyasiga amal qiling.")),
              item(Icons.label_outline_rounded, tr("Me'yor faqat aniq mahsulot yorlig'idan olinadi. Faol modda nomi mahsulot dozasi emas.")),
              item(Icons.verified_outlined, tr("Mintaqada ro'yxatdan o'tganligi va ruxsati ma'lum bo'lmasa, dori tasdiqlangan deb ko'rsatilmaydi.")),
              item(Icons.masks_outlined, tr("Ishlov berishda qo'lqop va niqob taqing, shamolsiz paytda purkang, kutish muddatiga rioya qiling.")),
              item(Icons.shopping_cart_outlined, tr("Ilovada dori sotilmaydi.")),
            ]),
          ),
        );
      },
    );

// ---------- Ro'yxat qatorlari (boshqa ekranlarda ham ishlatiladi) ----------
class _Row extends StatelessWidget {
  const _Row({required this.leading, required this.title, this.sub, this.tags = const [], required this.onTap});
  final Widget leading;
  final String title;
  final String? sub;
  final List<Widget> tags;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.3)),
                  if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: tags)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.subtle),
            ]),
          ),
        ),
      ),
    );
  }
}

class PlantRow extends StatelessWidget {
  const PlantRow(this.p, {super.key, this.onTap});
  final Plant p;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => _Row(
        leading: CatalogImage(asset: CatalogImages.plant(p.name), url: p.imageUrl, width: 72, height: 72),
        title: p.name,
        sub: p.scientificName,
        onTap: onTap ?? () => context.push('/catalog/plant/${p.id}'),
      );
}

class DiseaseRow extends StatelessWidget {
  const DiseaseRow(this.d, {super.key, this.showPlant = true, this.sub, this.onTap});
  final Disease d;
  final bool showPlant;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final img = CatalogImages.disease(d.aiLabel);
    final url = AppConfig.mediaUrl(d.imageUrl);
    return _Row(
      leading: CatalogImage(asset: img, url: url, width: 72, height: 72),
      title: d.name,
      sub: sub ?? (showPlant ? d.plantName : null),
      tags: [RiskTag(d.riskLevel), if (img == null && url == null) StatusTag(tr("Rasm yo'q"), kind: StatusKind.neutral)],
      onTap: onTap ?? () => context.push('/catalog/disease/${d.id}'),
    );
  }
}

/// Dori turi: fungitsid (zamburug'ga qarshi), insektitsid (hasharot/kana), biologik.
(String, IconData, Color, Color) medicineType(BuildContext context, Medicine m) {
  final c = context.c;
  final t = '${m.name} ${m.description ?? ''}'.toLowerCase();
  if (t.contains('bio')) return (tr('Biologik'), Icons.spa_outlined, c.successBg, c.success);
  if (t.contains('insektitsid') || t.contains('kana') || t.contains('qurt')) return (tr('Insektitsid'), Icons.pest_control_outlined, c.warningBg, c.warning);
  return (tr('Fungitsid'), Icons.science_outlined, c.infoBg, c.info);
}

class MedicineRow extends StatelessWidget {
  const MedicineRow(this.m, {super.key, this.sub, this.onTap});
  final Medicine m;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = medicineType(context, m);
    return _Row(
      leading: Container(width: 56, height: 56, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(icon, color: fg)),
      title: m.name,
      sub: sub ?? m.activeIngredient,
      tags: [StatusTag(label, kind: label == tr('Biologik') ? StatusKind.healthy : label == tr('Insektitsid') ? StatusKind.risk : StatusKind.info, icon: icon)],
      onTap: onTap ?? () => context.push('/catalog/medicine/${m.id}'),
    );
  }
}

/// Eski chaqiruvlar uchun: kasallik sahifasini ochadi.
void showDiseaseSheet(BuildContext context, WidgetRef ref, String id) => context.push('/catalog/disease/$id');
