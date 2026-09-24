import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Tashxis → "Mening bog'im": kasallik haqida ma'lumot, kunlik parvarish rejasi va uni eslatmalar sifatida boshlash.
class CarePlanScreen extends ConsumerStatefulWidget {
  const CarePlanScreen({super.key, required this.diagnosisId});
  final String diagnosisId;
  @override
  ConsumerState<CarePlanScreen> createState() => _CarePlanState();
}

class _CarePlanState extends ConsumerState<CarePlanScreen> {
  String _target = 'new';
  String? _cropId;
  String? _plantId;
  final _name = TextEditingController();
  bool _nameTouched = false;
  bool _allDays = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _apply(CarePlan plan) async {
    setState(() => _saving = true);
    try {
      final linked = plan.cropId != null;
      final cropId = await ref.read(gardenRepoProvider).applyCarePlan(
            widget.diagnosisId,
            cropId: linked ? null : (_target == 'existing' ? _cropId : null),
            cropName: !linked && _target == 'new' ? _name.text.trim() : null,
            plantId: !linked && _target == 'new' ? (plan.plantId ?? _plantId) : null,
          );
      ref.invalidate(cropsProvider);
      ref.invalidate(remindersProvider);
      ref.invalidate(diagnosesProvider);
      ref.invalidate(cropProvider(cropId));
      ref.invalidate(cropLogsProvider(cropId));
      ref.invalidate(cropDiagnosesProvider(cropId));
      ref.invalidate(cropHealthProvider(cropId));
      if (!mounted) return;
      showToast(context, 'Reja boshlandi: ${plan.tasks.length} ta vazifa eslatmalarga qo\'shildi');
      context.go('/garden/$cropId');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diag = ref.watch(diagnosisProvider(widget.diagnosisId));
    final plan = ref.watch(carePlanProvider(widget.diagnosisId));
    return PageShell(
      padBottom: false,
      child: AsyncView(
        value: plan,
        onRetry: () => ref.invalidate(carePlanProvider(widget.diagnosisId)),
        data: (p) {
          if (!_nameTouched && _name.text.isEmpty) _name.text = p.plantName ?? '';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const TopBar(title: 'Parvarish rejasi', subtitle: 'AI tashxis va bilimlar bazasi asosida'),
            _Summary(plan: p, diagnosis: diag.value),
            if (diag.value != null) _About(d: diag.value!),
            _PlanView(plan: p, allDays: _allDays, onToggle: () => setState(() => _allDays = !_allDays)),
            _targetSection(p),
            const SizedBox(height: 6),
            PillButton(
              label: p.cropId != null ? 'Rejani boshlash' : "Bog'imga qo'shish va rejani boshlash",
              icon: AppIcons.check,
              style: PillStyle.primary,
              block: true,
              loading: _saving,
              onPressed: _canApply(p) ? () => _apply(p) : null,
            ),
            const SizedBox(height: 8),
            Text(
              "Har bir vazifa o'z kuni va vaqtida bildirishnoma bo'lib keladi. Bajarganingizni belgilab borasiz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: context.c.muted, fontSize: 12),
            ),
          ]);
        },
      ),
    );
  }

  bool _canApply(CarePlan p) {
    if (p.cropId != null) return true;
    return _target == 'existing' ? _cropId != null : _name.text.trim().isNotEmpty;
  }

  Widget _targetSection(CarePlan p) {
    final c = context.c;
    if (p.cropId != null) {
      return AppCard(
        color: c.cream2,
        shadow: false,
        child: Row(children: [
          Icon(AppIcons.leaf, color: c.success),
          const SizedBox(width: 10),
          const Expanded(child: Text("Tashxis bog'ingizdagi ekinga bog'langan — reja shu ekinga qo'shiladi.")),
        ]),
      );
    }
    final crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final plants = ref.watch(plantsProvider).value ?? const <Plant>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle("Qaysi ekinga?"),
      ChipTabs(
        tabs: [('new', 'Yangi ekin'), if (crops.isNotEmpty) ('existing', 'Bog\'imdagi ekin')],
        selected: _target,
        onSelect: (v) => setState(() => _target = v),
      ),
      if (_target == 'new') ...[
        const FieldLabel('Ekin nomi'),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() => _nameTouched = true),
          decoration: const InputDecoration(hintText: 'Masalan: Pomidor, issiqxona'),
        ),
        if (p.plantId == null) ...[
          const SizedBox(height: 12),
          const FieldLabel('Ekin turi'),
          DropdownButtonFormField<String?>(
            initialValue: _plantId,
            isExpanded: true,
            dropdownColor: c.card,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tanlang')),
              for (final pl in plants) DropdownMenuItem<String?>(value: pl.id, child: Text(pl.name)),
            ],
            onChanged: (v) => setState(() => _plantId = v),
          ),
        ],
      ] else ...[
        const FieldLabel('Ekin'),
        DropdownButtonFormField<String?>(
          initialValue: _cropId,
          isExpanded: true,
          dropdownColor: c.card,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tanlang')),
            for (final cr in crops) DropdownMenuItem<String?>(value: cr.id, child: Text('${cr.name}${cr.plantName != null ? ' · ${cr.plantName}' : ''}')),
          ],
          onChanged: (v) => setState(() => _cropId = v),
        ),
      ],
      const SizedBox(height: 16),
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, this.diagnosis});
  final CarePlan plan;
  final Diagnosis? diagnosis;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = diagnosis;
    final pct = plan.confidence;
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ThumbIcon(icon: AppIcons.image, imageUrl: d?.imageUrl, size: 64, radius: 16),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (plan.plantName != null) Text(plan.plantName!, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
            Text(plan.isHealthy ? "O'simlik sog'lom" : (plan.diseaseName ?? 'Aniqlanmadi'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag('${d?.lowConfidence == true ? 'Taxminiy · ' : 'Ishonch '}${pct.toStringAsFixed(0)}%',
                  bg: d?.lowConfidence == true ? c.primaryLight : c.successBg, fg: d?.lowConfidence == true ? c.primaryDark : c.success),
              if (d?.riskLevel != null && !plan.isHealthy)
                Tag(riskLabels[d!.riskLevel] ?? '', bg: d.riskLevel == 'high' ? c.dangerBg : c.primaryLight, fg: d.riskLevel == 'high' ? c.danger : c.primaryDark),
              Tag('${plan.durationDays} kun', bg: c.tagCare, fg: c.onTagCare),
            ]),
            if (d?.lowConfidence == true) ...[
              const SizedBox(height: 8),
              Text('AI bu natijaga to\'liq ishonch hosil qilmadi. Belgilarni quyidagi tavsif bilan solishtirib ko\'ring.',
                  style: TextStyle(color: c.muted, fontSize: 12.5)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.d});
  final Diagnosis d;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget row(String label, String? text) => text == null || text.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text.rich(
              TextSpan(children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: text)]),
              style: const TextStyle(height: 1.45, fontSize: 13.5),
            ),
          );
    final med = d.medicines.isNotEmpty ? d.medicines.first : null;
    if (d.isHealthy) {
      return AppCard(child: row('Tavsiya', d.recommendations ?? 'Parvarishni davom ettiring.'));
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Kasallik haqida', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 10),
        row('Belgilari', d.symptoms),
        row('Sababi', d.causes),
        row('Davolash', d.treatment ?? d.recommendations),
        row("Oldini olish", d.prevention),
        if (med != null) InfoBox(label: 'Tavsiya etilgan dori', value: '${med.name}${med.recommendation != null ? ', ${med.recommendation}' : ''}'),
      ]),
    );
  }
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan, required this.allDays, required this.onToggle});
  final CarePlan plan;
  final bool allDays;
  final VoidCallback onToggle;

  static const _preview = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final byDay = <int, List<CarePlanTask>>{};
    for (final t in plan.tasks) {
      byDay.putIfAbsent(t.day, () => []).add(t);
    }
    final days = byDay.keys.toList()..sort();
    final shown = allDays ? days : days.take(_preview).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Kunlik vazifalar (${plan.tasks.length})'),
      for (final day in shown)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${day == 0 ? 'Bugun' : '${day + 1}-kun'} · ${formatDate(byDay[day]!.first.date)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: c.primaryDark, fontSize: 13)),
            const SizedBox(height: 8),
            for (final t in byDay[day]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: c.tan, shape: BoxShape.circle),
                    child: Icon(AppIcons.forReminder(t.type), size: 16, color: c.primaryDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t.time.substring(0, 5)} · ${t.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      if (t.description != null && t.description!.isNotEmpty)
                        Text(t.description!, maxLines: allDays ? 3 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      if (days.length > _preview)
        Center(
          child: TextButton(
            onPressed: onToggle,
            child: Text(allDays ? 'Yig\'ish' : "Barcha ${days.length} kunni ko'rsatish", style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}
