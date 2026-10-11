import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'catalog_screen.dart';

const _riskOrder = {'high': 0, 'medium': 1, 'low': 2};

Widget _hero(BuildContext context, {String? asset, String? url, String? caption, String? placeholder}) => Stack(children: [
      CatalogImage(asset: asset, url: url, width: double.infinity, height: 230, radius: AppRadius.lg, placeholderText: placeholder),
      if (caption != null && (asset != null || url != null))
        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: const Color(0x8C000000), borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: Text(caption, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 11.5)),
          ),
        ),
    ]);

Widget _title(BuildContext context, String title, String? sub) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (sub != null) Text(sub, style: TextStyle(color: context.c.muted, fontStyle: FontStyle.italic)),
      ]),
    );

Widget _section(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(t, style: Theme.of(context).textTheme.headlineSmall),
    );

// ---------- O'simlik ----------
class PlantScreen extends ConsumerWidget {
  const PlantScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageShell(
        padBottom: false,
        child: AsyncView(
          value: ref.watch(plantProvider(id)),
          onRetry: () => ref.invalidate(plantProvider(id)),
          data: (p) {
            final diseases = [...ref.watch(plantDiseasesProvider(id)).value ?? <Disease>[]]
              ..sort((a, b) => (_riskOrder[a.riskLevel] ?? 1).compareTo(_riskOrder[b.riskLevel] ?? 1));
            final meds = ref.watch(plantMedicinesProvider(id)).value ?? const <Medicine>[];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TopBar(title: p.name),
              _hero(context, asset: CatalogImages.plant(p.name), url: p.imageUrl, caption: "Sog'lom barg", placeholder: "Rasm hali yo'q"),
              _title(context, p.name, p.scientificName),
              TextBlock('Tavsif', p.description),
              TextBlock('Parvarish', p.careInfo),
              if (diseases.isNotEmpty) ...[
                _section(context, 'Kasalliklari · ${diseases.length}'),
                for (final d in diseases) DiseaseRow(d, showPlant: false),
              ],
              if (meds.isNotEmpty) ...[
                _section(context, 'Ishlatiladigan dorilar'),
                for (final m in meds) MedicineRow(m),
              ],
            ]);
          },
        ),
      );
}

// ---------- Kasallik ----------
class DiseaseScreen extends ConsumerWidget {
  const DiseaseScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: PillButton(label: 'Ekinimni tekshirish', icon: Icons.photo_camera_outlined, style: PillStyle.primary, block: true,
                  onPressed: () => context.push('/diagnose')),
            ),
          ),
        ),
      ),
      child: AsyncView(
        value: ref.watch(diseaseProvider(id)),
        onRetry: () => ref.invalidate(diseaseProvider(id)),
        data: (d) {
          final img = CatalogImages.disease(d.aiLabel);
          final healthy = CatalogImages.plant(d.plantName);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TopBar(title: d.plantName ?? 'Kasallik'),
            _hero(context, asset: img, caption: 'PlantVillage', placeholder: "Bu kasallik rasmi hali datasetda yo'q"),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              RiskTag(d.riskLevel),
              if (d.plantName != null) StatusTag(d.plantName!, kind: StatusKind.neutral),
            ]),
            const SizedBox(height: 8),
            Text(d.name, style: Theme.of(context).textTheme.headlineMedium),
            if (img != null && healthy != null) ...[
              const SizedBox(height: 14),
              AppCard(
                margin: EdgeInsets.zero,
                shadow: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SOLISHTIRING', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (a, label, color) in [(healthy, "Sog'lom", c.muted), (img, 'Kasal', c.danger)]) ...[
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          AspectRatio(aspectRatio: 1, child: CatalogImage(asset: a)),
                          const SizedBox(height: 4),
                          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                        ]),
                      ),
                      if (label == "Sog'lom") const SizedBox(width: 10),
                    ],
                  ]),
                ]),
              ),
            ],
            TextBlock('Belgilari', d.symptoms),
            TextBlock('Sababi', d.causes),
            if (d.treatment != null) ...[
              const SizedBox(height: 16),
              NoteBox(title: 'Davolash', text: d.treatment),
            ],
            if (d.medicines.isNotEmpty) ...[
              _section(context, 'Dorilar'),
              for (final m in d.medicines) MedicineRow(m, sub: m.recommendation ?? m.activeIngredient),
            ],
            TextBlock('Oldini olish', d.prevention),
            const SizedBox(height: 16),
          ]);
        },
      ),
    );
  }
}

// ---------- Dori ----------
class MedicineScreen extends ConsumerWidget {
  const MedicineScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageShell(
        padBottom: false,
        child: AsyncView(
          value: ref.watch(medicineProvider(id)),
          onRetry: () => ref.invalidate(medicineProvider(id)),
          data: (m) {
            final (label, icon, bg, fg) = medicineType(context, m);
            final uses = ref.watch(medicineDiseasesProvider(id)).value ?? const <Disease>[];
            final plants = {for (final d in uses) if (d.plantName != null) d.plantName!}.toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TopBar(title: 'Dori'),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Icon(icon, size: 64, color: fg),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                StatusTag(label, kind: label == 'Biologik' ? StatusKind.healthy : label == 'Insektitsid' ? StatusKind.risk : StatusKind.info, icon: icon),
                if (m.manufacturer != null) StatusTag(m.manufacturer!, kind: StatusKind.neutral),
              ]),
              _title(context, m.name, m.activeIngredient),
              if (m.description != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(m.description!, style: const TextStyle(fontSize: 16.5, height: 1.5))),
              if (m.usage != null) ...[const SizedBox(height: 16), NoteBox(title: "Qo'llash me'yori", text: m.usage, icon: Icons.water_drop_outlined)],
              if (m.precautions != null) ...[const SizedBox(height: 10), NoteBox(kind: NoteKind.risk, title: 'Ehtiyot choralari', text: m.precautions)],
              if (plants.isNotEmpty) ...[
                _section(context, 'Qaysi ekinlarda'),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final p in plants) StatusTag(p, kind: StatusKind.neutral)]),
              ],
              if (uses.isNotEmpty) ...[
                _section(context, 'Qaysi kasalliklarga qarshi · ${uses.length}'),
                for (final d in uses) DiseaseRow(d, sub: [d.plantName, d.recommendation].whereType<String>().join(' · ')),
              ],
              const SizedBox(height: 16),
            ]);
          },
        ),
      );
}
