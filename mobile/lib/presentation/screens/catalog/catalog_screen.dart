import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Ma'lumotnoma — to'liq katalog: O'simliklar · Kasalliklar · Dorilar, rasmlari bilan. Qidiruv uchala bo'limdan.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.tab = 'plants'});
  final String tab;
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogState();
}

const _riskOrder = {'high': 0, 'medium': 1, 'low': 2};

class _CatalogState extends ConsumerState<CatalogScreen> {
  late String _tab = const {'plants', 'diseases', 'medicines'}.contains(widget.tab) ? widget.tab : 'plants';

  @override
  void didUpdateWidget(covariant CatalogScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && const {'plants', 'diseases', 'medicines'}.contains(widget.tab)) _tab = widget.tab;
  }
  String _q = '';
  String _plant = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plants = ref.watch(plantsProvider);
    final diseases = ref.watch(diseasesProvider);
    final medicines = ref.watch(medicinesProvider);
    final counts = [plants.value?.length, diseases.value?.length, medicines.value?.length];
    return PageShell(
      padBottom: false,
      onRefresh: () async {
        ref.invalidate(plantsProvider);
        ref.invalidate(diseasesProvider);
        ref.invalidate(medicinesProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(
          title: tr("Ma'lumotnoma"),
          subtitle: counts.contains(null) ? null : trf("{0} o'simlik · {1} kasallik · {2} dori", [counts[0], counts[1], counts[2]]),
        ),
        TextField(
          onChanged: (v) => setState(() => _q = v.trim()),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: tr("O'simlik, kasallik yoki dori nomi"), prefixIcon: Icon(Icons.search_rounded, color: c.muted)),
        ),
        const SizedBox(height: 12),
        if (_q.isNotEmpty)
          _SearchResults(q: _q.toLowerCase())
        else ...[
          SegmentTabs(
            tabs: [('plants', tr("O'simliklar")), ('diseases', tr('Kasalliklar')), ('medicines', tr('Dorilar'))],
            selected: _tab,
            onSelect: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: 14),
          if (_tab == 'plants')
            AsyncView(
              value: plants,
              onRetry: () => ref.invalidate(plantsProvider),
              data: (list) => _PlantGrid(plants: list, diseases: diseases.value ?? const []),
            ),
          if (_tab == 'diseases')
            AsyncView(
              value: diseases,
              onRetry: () => ref.invalidate(diseasesProvider),
              data: (list) {
                final names = {for (final d in list) if (d.plantName != null) d.plantName!}.toList()..sort();
                final shown = list.where((d) => _plant == 'all' || d.plantName == _plant).toList()
                  ..sort((a, b) => (_riskOrder[a.riskLevel] ?? 1).compareTo(_riskOrder[b.riskLevel] ?? 1));
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ChipTabs(tabs: [('all', tr('Barchasi')), for (final n in names) (n, n)], selected: _plant, onSelect: (v) => setState(() => _plant = v)),
                  Text(trf('{0} ta kasallik · avval xavflilari', [shown.length]), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  for (final d in shown) DiseaseRow(d),
                ]);
              },
            ),
          if (_tab == 'medicines')
            AsyncView(
              value: medicines,
              onRetry: () => ref.invalidate(medicinesProvider),
              data: (list) => Column(children: [
                NoteBox(kind: NoteKind.risk, title: tr("Ehtiyot bo'ling"), text: tr("Har doim yorliqdagi me'yorga amal qiling, qo'lqop va niqob taqing.")),
                const SizedBox(height: 12),
                for (final m in list) MedicineRow(m),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.q});
  final String q;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool has(String? s) => (s ?? '').toLowerCase().contains(q);
    final plants = (ref.watch(plantsProvider).value ?? []).where((p) => has(p.name)).toList();
    final diseases = (ref.watch(diseasesProvider).value ?? []).where((d) => has(d.name) || has(d.symptoms)).toList();
    final meds = (ref.watch(medicinesProvider).value ?? []).where((m) => has(m.name) || has(m.activeIngredient) || has(m.description)).toList();
    if (plants.isEmpty && diseases.isEmpty && meds.isEmpty) {
      return EmptyNote(tr("Hech narsa topilmadi. Boshqacha yozib ko'ring, masalan «zang» yoki «mis»."), icon: Icons.search_off_rounded);
    }
    Widget head(String t) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(t.toUpperCase(), style: Theme.of(context).textTheme.labelSmall));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (plants.isNotEmpty) ...[head(trf("O'simliklar · {0}", [plants.length])), for (final p in plants) PlantRow(p)],
      if (diseases.isNotEmpty) ...[head(trf('Kasalliklar · {0}', [diseases.length])), for (final d in diseases) DiseaseRow(d)],
      if (meds.isNotEmpty) ...[head(trf('Dorilar · {0}', [meds.length])), for (final m in meds) MedicineRow(m)],
    ]);
  }
}

class _PlantGrid extends StatelessWidget {
  const _PlantGrid({required this.plants, required this.diseases});
  final List<Plant> plants;
  final List<Disease> diseases;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final p in plants)
          SizedBox(
            width: w,
            child: Material(
              color: c.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: c.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/catalog/plant/${p.id}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CatalogImage(asset: CatalogImages.plant(p.name), url: p.imageUrl, width: w, height: w * 0.75, radius: 0, placeholderText: tr("Rasm hali yo'q")),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      Text(trf('{0} ta kasallik', [diseases.where((d) => d.plantId == p.id).length]), style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}

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
