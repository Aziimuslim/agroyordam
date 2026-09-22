import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Ensiklopediya: O'simliklar / Kasalliklar / Dorilar (bilimlar bazasi).
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.tab = 'plants'});
  final String tab;
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<CatalogScreen> {
  late String _tab = widget.tab;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    bool match(String? s) => _q.isEmpty || (s ?? '').toLowerCase().contains(_q.toLowerCase());
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Ensiklopediya'),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(hintText: 'Qidirish...', prefixIcon: Icon(Icons.search_rounded, color: c.muted)),
        ),
        const SizedBox(height: 14),
        ChipTabs(
          tabs: const [('plants', "O'simliklar"), ('diseases', 'Kasalliklar'), ('medicines', 'Dorilar')],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        if (_tab == 'plants')
          AsyncView(
            value: ref.watch(plantsProvider),
            onRetry: () => ref.invalidate(plantsProvider),
            data: (list) {
              final diseases = ref.watch(diseasesProvider).value ?? [];
              return Column(children: [
                for (final p in list.where((p) => match(p.name) || match(p.scientificName)))
                  RowCard(
                    leading: ThumbIcon(icon: AppIcons.forPlant(p.name), size: 46),
                    title: p.name,
                    subtitle: p.scientificName,
                    trailing: Text('${diseases.where((d) => d.plantId == p.id).length} kasallik', style: TextStyle(color: c.muted, fontSize: 13)),
                    onTap: () => _plantSheet(context, p, diseases.where((d) => d.plantId == p.id).toList()),
                  ),
              ]);
            },
          ),
        if (_tab == 'diseases')
          AsyncView(
            value: ref.watch(diseasesProvider),
            onRetry: () => ref.invalidate(diseasesProvider),
            data: (list) => Column(children: [
              for (final d in list.where((d) => match(d.name) || match(d.symptoms) || match(d.plantName)))
                AppCard(
                  onTap: () => showDiseaseSheet(context, ref, d.id),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(AppIcons.bug, size: 20, color: c.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                      if (d.riskLevel != null)
                        Tag(riskLabels[d.riskLevel]!, bg: d.riskLevel == 'high' ? c.dangerBg : c.primaryLight, fg: d.riskLevel == 'high' ? c.danger : c.primaryDark),
                    ]),
                    if (d.plantName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d.plantName!, style: TextStyle(color: c.primary, fontSize: 12.5, fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    Text(d.symptoms ?? '', style: TextStyle(color: c.muted, fontSize: 13, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
            ]),
          ),
        if (_tab == 'medicines')
          AsyncView(
            value: ref.watch(medicinesProvider),
            onRetry: () => ref.invalidate(medicinesProvider),
            data: (list) => Column(children: [
              for (final m in list.where((m) => match(m.name) || match(m.activeIngredient)))
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(AppIcons.pill, size: 20, color: c.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                    ]),
                    if (m.activeIngredient != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m.activeIngredient!, style: TextStyle(color: c.muted, fontSize: 12.5))),
                    if (m.description != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(m.description!, style: const TextStyle(fontSize: 13))),
                    if (m.usage != null) InfoBox(label: "Qo'llash", value: m.usage!),
                    if (m.precautions != null) Text('Ehtiyot choralari: ${m.precautions}', style: TextStyle(fontSize: 12.5, color: c.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }

  void _plantSheet(BuildContext context, Plant p, List<Disease> diseases) {
    final c = context.c;
    showSheet(context, title: p.name, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.scientificName != null) Text(p.scientificName!, style: TextStyle(color: c.muted, fontStyle: FontStyle.italic)),
          if (p.description != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(p.description!)),
          if (p.careInfo != null) InfoBox(label: 'Parvarish', value: p.careInfo!),
          if (diseases.isNotEmpty) const FieldLabel('Uchraydigan kasalliklar'),
          for (final d in diseases)
            ListRow(icon: AppIcons.bug, label: d.name, onTap: () {
              Navigator.pop(ctx);
              showDiseaseSheet(context, ref, d.id);
            }),
        ]));
  }
}

void showDiseaseSheet(BuildContext context, WidgetRef ref, String id) {
  showSheet(context, title: 'Kasallik', builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final c = ctx.c;
        return AsyncView(
          value: ref.watch(diseaseProvider(id)),
          data: (d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            if (d.plantName != null) Text(d.plantName!, style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (d.symptoms != null) Text.rich(TextSpan(children: [const TextSpan(text: 'Alomatlari: ', style: TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: d.symptoms)]), style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            if (d.causes != null) Text.rich(TextSpan(children: [const TextSpan(text: 'Sababi: ', style: TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: d.causes)]), style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            if (d.treatment != null) Text.rich(TextSpan(children: [const TextSpan(text: 'Davolash: ', style: TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: d.treatment)]), style: const TextStyle(height: 1.5)),
            for (final m in d.medicines) InfoBox(label: 'Tavsiya etilgan dori', value: '${m.name}${m.recommendation != null ? ', ${m.recommendation}' : ''}'),
            if (d.prevention != null) ...[
              const FieldLabel("Oldini olish"),
              Text(d.prevention!, style: const TextStyle(height: 1.5)),
            ],
            const SizedBox(height: 16),
            PillButton(label: 'Yopish', block: true, onPressed: () => Navigator.pop(ctx)),
          ]),
        );
      }));
}
