import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../saved/bookmark_button.dart';
import 'catalog_common.dart';
import 'catalog_screen.dart' show DiseaseCard, MedicineCard, showSafetySheet;

const _ink = Color(0xFF20251B); // oq "shisha" tugma ustidagi ikonka (har ikki mavzuda)

/// Umumiy tafsilot qolipi: rasm-header (bosilsa kattalashadi), nom, tablar, kontent, pastki amal.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.title,
    this.subtitle,
    this.asset,
    this.url,
    this.imageLabel,
    this.chips = const [],
    required this.tabs,
    required this.tab,
    required this.onTab,
    required this.body,
    this.bottom,
    this.fallbackRoute = '/catalog',
    this.icon,
    this.bookmark,
  });
  final String title;
  final String? subtitle, asset, url, imageLabel, fallbackRoute;
  final List<Widget> chips;
  final List<(String, String)> tabs;
  final String tab;
  final ValueChanged<String> onTab;
  final Widget body;
  final Widget? bottom;
  final IconData? icon; // rasm o'rniga katta ikonka (dorilar)
  final Widget? bookmark; // A02 saqlash tugmasi

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final top = MediaQuery.paddingOf(context).top;
    final hasImage = asset != null || url != null;
    return Scaffold(
      backgroundColor: c.cream,
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
              child: SafeArea(
                top: false,
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: bottom)),
                ),
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 260 + top,
                child: Stack(fit: StackFit.expand, children: [
                  if (icon != null)
                    ColoredBox(color: c.oliveSoft, child: Icon(icon, size: 96, color: c.onOliveSoft))
                  else
                    Semantics(
                      button: hasImage,
                      label: hasImage ? tr('Rasmni kattalashtirish') : null,
                      child: GestureDetector(
                        onTap: hasImage ? () => showImageViewer(context, asset: asset, url: url, label: imageLabel ?? title) : null,
                        child: CatalogImage(asset: asset, url: url, radius: 0, placeholderText: title, width: double.infinity, height: double.infinity),
                      ),
                    ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x55000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                          stops: [0, 0.3, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top + 8,
                    left: 12,
                    child: Tooltip(
                      message: tr('Orqaga'),
                      child: Material(
                        color: const Color(0xE6FFFFFF),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            final handled = await Navigator.of(context).maybePop();
                            if (!handled && context.mounted) context.go(fallbackRoute ?? '/catalog');
                          },
                          child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_rounded, color: _ink)),
                        ),
                      ),
                    ),
                  ),
                  if (bookmark != null)
                    Positioned(
                      top: top + 8,
                      right: 12,
                      child: Material(color: const Color(0xE6FFFFFF), shape: const CircleBorder(), child: bookmark),
                    ),
                  if (imageLabel != null && hasImage)
                    Positioned(
                      right: 12,
                      top: top + (bookmark != null ? 64 : 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(999)),
                        child: Text(imageLabel!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(
                        header: true,
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.15, fontWeight: FontWeight.w800)),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (chips.isNotEmpty) ...[Wrap(spacing: 8, runSpacing: 8, children: chips), const SizedBox(height: 14)],
                  ChipTabs(tabs: tabs, selected: tab, onSelect: onTab),
                  AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(tab), child: body)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

Widget _heading(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(header: true, child: Text(t, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.c.text))),
    );

Widget _para(BuildContext context, String? t, {String? empty}) => t == null || t.trim().isEmpty
    ? Text(empty ?? tr("Ma'lumot hali kiritilmagan"), style: TextStyle(fontSize: 15, color: context.c.muted))
    : Text(t, style: TextStyle(fontSize: 16, height: 1.5, color: context.c.text));

/// Matnni gaplar bo'yicha belgilangan ro'yxatga ajratadi.
Widget _bullets(BuildContext context, String? t) {
  final c = context.c;
  final parts = (t ?? '').split(RegExp(r'(?<=[.;!])\s+')).map((s) => s.trim().replaceAll(RegExp(r'[.;]$'), '')).where((s) => s.length > 2).toList();
  if (parts.isEmpty) return _para(context, null);
  return Column(children: [
    for (final p in parts)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.olive, shape: BoxShape.circle))),
          const SizedBox(width: 12),
          Expanded(child: Text(p, style: TextStyle(fontSize: 16, height: 1.45, color: c.text))),
        ]),
      ),
  ]);
}

Widget _notFound(BuildContext context, WidgetRef ref, AsyncValue v, String title, VoidCallback retry) {
  final err = v.hasError ? ApiException.from(v.error!) : null;
  return PageShell(
    padBottom: false,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TopBar(title: title),
      if (err == null)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (err.statusCode == 404)
        Column(children: [
          EmptyNote(tr("Topilmadi yoki kirish huquqi yo'q"), icon: Icons.search_off_rounded),
          TextButton(onPressed: () => context.go('/catalog'), child: Text(tr("Ma'lumotnomaga qaytish"))),
        ])
      else
        BlockError(error: v.error!, what: title, onRetry: retry),
    ]),
  );
}

Widget _primary(BuildContext context, String label, IconData icon, VoidCallback onTap) {
  final c = context.c;
  return SizedBox(
    width: double.infinity,
    child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
    ),
  );
}

// ---------- S20 O'simlik ----------
class PlantScreen extends ConsumerStatefulWidget {
  const PlantScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends ConsumerState<PlantScreen> {
  String _tab = 'overview';
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(plantProvider(widget.id));
    final p = v.value;
    if (p == null) return _notFound(context, ref, v, tr("O'simlik"), () => ref.invalidate(plantProvider(widget.id)));
    final diseases = [...ref.watch(plantDiseasesProvider(widget.id)).value ?? <Disease>[]]..sort((a, b) => a.name.compareTo(b.name));
    final asset = CatalogImages.plant(p.name);
    final body = switch (_tab) {
      'care' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Parvarish asoslari')),
          _bullets(context, p.careInfo),
          Text(tr("Tavsiyalar umumiy; mavsum va hududingiz sharoitiga moslang."), style: TextStyle(fontSize: 14, color: c.muted)),
        ]),
      'diseases' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, trf("Ko'p uchraydigan kasalliklar ({0})", [diseases.length])),
          if (diseases.isEmpty) _para(context, null, empty: tr("Bu ekin uchun kasallik kiritilmagan")),
          for (final d in diseases) Padding(padding: const EdgeInsets.only(bottom: 10), child: DiseaseCard(d: d, showPlant: false)),
        ]),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Qisqacha')),
          _para(context, p.description),
          const SizedBox(height: 16),
          SourceLine(imageCredit: asset != null ? tr("PlantVillage ma'lumotlar to'plami (sog'lom barg)") : null),
          Text(tr("Rasm o'simlikni tanish uchun; tashxis isboti emas."), style: TextStyle(fontSize: 14, color: c.muted)),
        ]),
    };
    return _DetailScaffold(
      bookmark: BookmarkButton(kind: 'plant', targetId: widget.id, color: _ink),
      title: p.name,
      subtitle: p.scientificName,
      asset: asset,
      url: AppConfig.mediaUrl(p.imageUrl),
      imageLabel: asset != null ? tr("Sog'lom barg") : null,
      chips: [InfoChip(icon: plantCategoryIcon(p.category), label: plantCategoryLabel(p.category))],
      tabs: [('overview', tr('Umumiy')), ('care', tr('Parvarish')), ('diseases', tr('Kasalliklar'))],
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      body: body,
      // S05: tur avtomatik tanlanadi, nom va joylashuv foydalanuvchida
      bottom: _primary(context, tr("Bog'imga qo'shish"), Icons.add_circle_outline_rounded, () => context.push('/garden/add?plant=${p.id}')),
    );
  }
}

// ---------- S21 Kasallik ----------
class DiseaseScreen extends ConsumerStatefulWidget {
  const DiseaseScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends ConsumerState<DiseaseScreen> {
  String _tab = 'symptoms';
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(diseaseProvider(widget.id));
    final d = v.value;
    if (d == null) return _notFound(context, ref, v, tr('Kasallik'), () => ref.invalidate(diseaseProvider(widget.id)));
    final img = CatalogImages.disease(d.aiLabel);
    final healthy = CatalogImages.plant(d.plantName);
    final body = switch (_tab) {
      'treatment' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Davolash')),
          _bullets(context, d.treatment),
          if (d.medicines.isNotEmpty) ...[
            _heading(context, tr('Tegishli vositalar')),
            for (final m in d.medicines) ...[
              MedicineCard(m: m),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                child: Text(
                  verifiedDose(m, m.recommendation) ?? tr("Me'yor ko'rsatilmaydi: mahsulot yorlig'i bo'yicha tasdiqlanmagan. Qadoqdagi yorliqqa amal qiling."),
                  style: TextStyle(fontSize: 14, color: m.labelVerified ? c.text : c.muted, height: 1.4),
                ),
              ),
            ],
          ],
        ]),
      'prevent' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_heading(context, tr('Oldini olish')), _bullets(context, d.prevention)]),
      'sources' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Manbalar')),
          SourceLine(source: d.source, updatedAt: d.updatedAt, imageCredit: img != null ? tr("PlantVillage ma'lumotlar to'plami") : null),
        ]),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Belgilari')),
          _bullets(context, d.symptoms),
          if ((d.causes ?? '').isNotEmpty) ...[_heading(context, tr('Sababi')), _para(context, d.causes)],
          if (img != null && healthy != null) ...[
            _heading(context, tr('Solishtiring')),
            Row(children: [
              for (final (a, label) in [(healthy, tr("Sog'lom barg")), (img, tr('Zararlangan barg'))]) ...[
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$label. ${tr('Rasmni kattalashtirish')}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => showImageViewer(context, asset: a, label: '$label · ${d.plantName ?? ''}'),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AspectRatio(aspectRatio: 1, child: CatalogImage(asset: a, radius: 12)),
                        const SizedBox(height: 6),
                        // Yorliq matn bilan — rangga bog'liq emas (TZ S21)
                        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                      ]),
                    ),
                  ),
                ),
                if (a == healthy) const SizedBox(width: 12),
              ],
            ]),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          Text(tr("Dog' surati yakuniy tashxis emas. Shubha bo'lsa ekiningizni tekshiring yoki agronomga murojaat qiling."),
              style: TextStyle(fontSize: 14, color: c.muted, height: 1.4)),
        ]),
    };
    return _DetailScaffold(
      bookmark: BookmarkButton(kind: 'disease', targetId: widget.id, color: _ink),
      title: d.name,
      subtitle: d.plantName,
      asset: img,
      url: AppConfig.mediaUrl(d.imageUrl),
      imageLabel: img != null ? tr('Zararlangan barg') : null,
      fallbackRoute: '/catalog?tab=diseases',
      chips: [if (d.plantName != null) InfoChip(icon: Icons.eco_outlined, label: d.plantName!)],
      tabs: [('symptoms', tr('Belgilar')), ('treatment', tr('Davolash')), ('prevent', tr('Oldini olish')), ('sources', tr('Manbalar'))],
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      body: body,
      bottom: _primary(context, tr('Ekinni tekshirish'), AppIcons.scan, () => context.push('/diagnose${d.plantId != null ? '?plant=${d.plantId}' : ''}')),
    );
  }
}

// ---------- S22 Dori ----------
class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  String _tab = 'overview';
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(medicineProvider(widget.id));
    final m = v.value;
    if (m == null) return _notFound(context, ref, v, tr('Dori'), () => ref.invalidate(medicineProvider(widget.id)));
    final uses = ref.watch(medicineDiseasesProvider(widget.id)).value ?? const <Disease>[];
    final plants = {for (final d in uses) if (d.plantName != null) d.plantName!}.toList()..sort();
    final cat = medicineCategory(m.category);
    final kind = medicineKindLabel(m.kind);
    final dose = verifiedDose(m);
    final body = switch (_tab) {
      'label' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr("Qo'llash me'yori")),
          if (dose != null)
            NoteBox(title: tr("Yorliq bo'yicha tasdiqlangan"), text: dose, icon: Icons.verified_outlined)
          else
            NoteBox(
              kind: NoteKind.risk,
              title: tr("Me'yor ko'rsatilmaydi"),
              text: tr("Bu yozuv uchun aniq mahsulot yorlig'i (konsentratsiya, ekin, hudud, birlik) tasdiqlanmagan. Me'yorni sotib olingan mahsulot qadog'idagi yorliqdan oling."),
            ),
          const SizedBox(height: 12),
          Text(tr("Yorliq hujjati ilovaga hali yuklanmagan."), style: TextStyle(fontSize: 14, color: c.muted)),
        ]),
      'safety' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Ehtiyot choralari')),
          _bullets(context, m.precautions),
          const SizedBox(height: 4),
          TextButton.icon(onPressed: () => showSafetySheet(context), icon: const Icon(Icons.info_outline_rounded), label: Text(tr("Xavfsizlik bo'yicha umumiy qoidalar"))),
        ]),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heading(context, tr('Qisqacha')),
          _para(context, m.description),
          if (m.activeIngredient != null) ...[
            _heading(context, tr('Faol modda')),
            Text(m.activeIngredient!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
            Text(tr("Faol modda konsentratsiyasi mahsulot dozasi emas."), style: TextStyle(fontSize: 14, color: c.muted)),
          ],
          if (m.manufacturer != null) ...[_heading(context, tr('Ishlab chiqaruvchi')), _para(context, m.manufacturer)],
          if (plants.isNotEmpty) ...[
            _heading(context, tr('Qaysi ekinlarda')),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final p in plants) InfoChip(icon: Icons.eco_outlined, label: p, bg: c.cream2, fg: c.text)]),
          ],
          if (uses.isNotEmpty) ...[
            _heading(context, trf('Qaysi kasalliklarga qarshi ({0})', [uses.length])),
            for (final d in uses) Padding(padding: const EdgeInsets.only(bottom: 10), child: DiseaseCard(d: d)),
          ],
          const SizedBox(height: 8),
          SourceLine(source: m.source, updatedAt: m.updatedAt),
        ]),
    };
    return _DetailScaffold(
      bookmark: BookmarkButton(kind: 'medicine', targetId: widget.id, color: _ink),
      title: m.name,
      subtitle: m.activeIngredient,
      icon: cat.icon,
      fallbackRoute: '/catalog?tab=medicines',
      chips: [InfoChip(icon: cat.icon, label: cat.label), if (kind != null) InfoChip(icon: Icons.label_outline_rounded, label: kind, bg: c.cream2, fg: c.text)],
      tabs: [('overview', tr('Umumiy')), ('label', tr('Yorliq')), ('safety', tr('Ehtiyot choralari'))],
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      body: body,
    );
  }
}
