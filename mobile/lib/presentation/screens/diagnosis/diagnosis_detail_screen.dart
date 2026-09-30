import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'diagnosis_actions.dart';

/// Tashxis natijasi — Figma "B · Yashil dala / Tashxis natijasi":
/// tepada rasm, ustida natija paneli (ekin/xavf chiplari, kasallik, AI ishonchi, Davolash/Belgilar/Oldini olish,
/// dori, "AI to'g'ri topdimi?") va pastda doimiy "Bog'imga qo'shish · N kunlik reja" tugmasi.
class DiagnosisDetailScreen extends ConsumerWidget {
  const DiagnosisDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final value = ref.watch(diagnosisProvider(id));
    return Scaffold(
      backgroundColor: c.cream,
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const TopBar(title: 'Tashxis natijasi'),
              AsyncView(value: value, onRetry: () => ref.invalidate(diagnosisProvider(id)), data: (_) => const SizedBox()),
            ]),
          ),
        ),
        data: (d) => _Body(d: d),
      ),
      bottomNavigationBar: value.maybeWhen(data: (d) => _PlanBar(d: d), orElse: () => null),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.d});
  final Diagnosis d;
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.d;
    final url = AppConfig.mediaUrl(d.imageUrl);
    final top = MediaQuery.paddingOf(context).top;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 340 + top,
              child: Stack(fit: StackFit.expand, children: [
                if (url != null)
                  Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _PhotoFallback())
                else
                  const _PhotoFallback(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Color(0x66000000), Color(0x00000000)]),
                  ),
                ),
                Positioned(
                  top: top + 10,
                  left: 16,
                  right: 16,
                  child: Row(children: [
                    _GlassButton(icon: AppIcons.back, tooltip: 'Orqaga', onTap: () => context.canPop() ? context.pop() : context.go('/home')),
                    const Spacer(),
                    _GlassButton(icon: AppIcons.share, tooltip: 'Jamoatda ulashish', onTap: () => shareDiagnosis(context, ref, d)),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(color: c.cream, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (d.plantName != null) _IconChip(icon: AppIcons.leaf, label: d.plantName!, bg: c.successBg, fg: c.success),
                    if (d.isHealthy)
                      _IconChip(icon: AppIcons.check, label: "Sog'lom", bg: c.successBg, fg: c.success)
                    else if (d.riskLevel != null)
                      _IconChip(
                        icon: AppIcons.alert,
                        label: riskLabels[d.riskLevel] ?? d.riskLevel!,
                        bg: d.riskLevel == 'high' ? c.dangerBg : c.warningBg,
                        fg: d.riskLevel == 'high' ? c.danger : c.warning,
                      ),
                    if (d.lowConfidence && !d.isHealthy) _IconChip(icon: Icons.help_outline_rounded, label: 'Taxminiy', bg: c.accentSoft, fg: c.warning),
                  ]),
                  const SizedBox(height: 10),
                  Text(d.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 25, height: 30 / 25)),
                  const SizedBox(height: 4),
                  Text(formatDate(d.diagnosedAt), style: TextStyle(color: c.muted, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _ConfidenceCard(d: d),
                  if (d.isHealthy)
                    AppCard(
                      child: Text(d.recommendations ?? "Parvarishni davom ettiring: muntazam sug'orish va haftalik ko'rik.",
                          style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w500)),
                    )
                  else ...[
                    _Segmented(labels: const ['Davolash', 'Belgilar', 'Oldini olish'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                    const SizedBox(height: 14),
                    _Steps(text: switch (_tab) { 0 => d.treatment ?? d.recommendations, 1 => [d.symptoms, d.causes].whereType<String>().join('. '), _ => d.prevention }),
                    const SizedBox(height: 8),
                    for (final (i, m) in d.medicines.indexed) _MedicineCard(m: m, primary: i == 0),
                  ],
                  const SizedBox(height: 8),
                  DiagnosisFeedback(d: d),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2F4A1C), Color(0xFF5E7A2E), Color(0xFF7A5A2C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Icon(AppIcons.leaf, size: 120, color: Colors.white.withValues(alpha: 0.2)),
      );
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.28),
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 22))),
        ),
      );
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.label, required this.bg, required this.fg});
  final IconData icon;
  final String label;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = d.confidence.clamp(0, 100).toDouble();
    final color = d.lowConfidence ? c.warning : c.primary;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('AI ishonchi', style: TextStyle(color: c.muted, fontSize: 13.5, fontWeight: FontWeight.w700))),
          Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct / 100, minHeight: 8, backgroundColor: c.cream2, color: color),
        ),
        if (d.lowConfidence && !d.isHealthy) ...[
          const SizedBox(height: 10),
          Text("AI to'liq ishonch hosil qilmadi — belgilarni quyidagi tavsif bilan solishtiring. Ekin turini tanlab qayta tekshirsangiz, natija aniqroq bo'ladi.",
              style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4)),
        ],
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: i == index ? c.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: i == index ? [BoxShadow(color: c.shadow, blurRadius: 4, offset: const Offset(0, 1))] : null,
                ),
                alignment: Alignment.center,
                child: Text(l, style: TextStyle(fontSize: 13.5, fontWeight: i == index ? FontWeight.w800 : FontWeight.w600, color: i == index ? c.text : c.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Matnni gaplarga bo'lib, raqamlangan qadamlar ko'rinishida chiqaradi.
class _Steps extends StatelessWidget {
  const _Steps({required this.text});
  final String? text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final parts = (text ?? '').split(RegExp(r'(?<=[.;!])\s+')).map((s) => s.trim().replaceAll(RegExp(r'[.;]$'), '')).where((s) => s.length > 2).toList();
    if (parts.isEmpty) return Text("Ma'lumot mavjud emas", style: TextStyle(color: c.muted));
    return Column(children: [
      for (final (i, p) in parts.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.primaryLight, shape: BoxShape.circle),
              child: Text('${i + 1}', style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(p, style: const TextStyle(fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w500))),
          ]),
        ),
    ]);
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.m, required this.primary});
  final Medicine m;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(14)),
          child: Icon(AppIcons.pill, color: c.danger, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(m.recommendation ?? m.activeIngredient ?? '', style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500)),
          ]),
        ),
        if (primary) ...[const SizedBox(width: 8), Tag('Asosiy', bg: c.primaryLight, fg: c.primaryDark)],
      ]),
    );
  }
}

class _PlanBar extends StatelessWidget {
  const _PlanBar({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!d.isHealthy && d.diseaseName == null) {
      return const SizedBox.shrink();
    }
    final label = d.cropId != null ? 'Davolash rejasi · ${planDays(d)} kun' : "Bog'imga qo'shish · ${planDays(d)} kunlik reja";
    return Container(
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: PillButton(label: label, icon: AppIcons.calendar, style: PillStyle.primary, block: true, onPressed: () => context.push('/diagnosis/${d.id}/plan')),
            ),
          ),
        ),
      ),
    );
  }
}
