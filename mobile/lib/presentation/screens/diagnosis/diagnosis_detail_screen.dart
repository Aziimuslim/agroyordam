import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import 'diagnosis_actions.dart';

final _diagProvider = FutureProvider.autoDispose.family((ref, String id) => ref.watch(gardenRepoProvider).diagnosis(id));

class DiagnosisDetailScreen extends ConsumerWidget {
  const DiagnosisDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      child: AsyncView(
        value: ref.watch(_diagProvider(id)),
        onRetry: () => ref.invalidate(_diagProvider(id)),
        data: (d) {
          Widget section(String title, String? body) => body == null || body.isEmpty
              ? const SizedBox.shrink()
              : AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(body, style: const TextStyle(height: 1.5)),
                  ]),
                );
          final url = AppConfig.mediaUrl(d.imageUrl);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TopBar(title: 'Tashxis natijasi', subtitle: formatDate(d.diagnosedAt)),
            if (url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(aspectRatio: 4 / 3, child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.tan))),
              ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Tag('Ishonch ${d.confidence.toStringAsFixed(0)}%'),
                  if (d.riskLevel != null && !d.isHealthy)
                    Tag(riskLabels[d.riskLevel] ?? '', bg: d.riskLevel == 'high' ? c.dangerBg : c.primaryLight, fg: d.riskLevel == 'high' ? c.danger : c.primaryDark),
                  if (d.plantName != null) Tag(d.plantName!, bg: c.tagCare, fg: c.onTagCare),
                ]),
              ]),
            ),
            section('Belgilari', d.symptoms),
            section('Sabablari', d.causes),
            section('Davolash', d.treatment ?? d.recommendations),
            section("Oldini olish", d.prevention),
            if (d.medicines.isNotEmpty) ...[
              const SectionTitle('Tavsiya etilgan vositalar'),
              for (final m in d.medicines)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if (m.activeIngredient != null) Text(m.activeIngredient!, style: TextStyle(color: c.muted, fontSize: 12.5)),
                    if (m.recommendation != null) InfoBox(label: 'Doza', value: m.recommendation!),
                    if (m.precautions != null) Text('Ehtiyot choralari: ${m.precautions}', style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                ),
            ],
            if (!d.isHealthy && !d.lowConfidence) ...[
              PillButton(label: "Eslatmalar qo'shish", icon: Icons.notifications_active_outlined, block: true, onPressed: () => addRemindersFromDiagnosis(context, ref, d)),
              const SizedBox(height: 10),
            ],
            PillButton(label: 'Jamoatda ulashish', style: PillStyle.outline, block: true, onPressed: () => shareDiagnosis(context, ref, d)),
          ]);
        },
      ),
    );
  }
}
