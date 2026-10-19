import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../profile/diagnoses_history_screen.dart' show diagnosisHeadline, diagnosisStatus;
import 'diagnosis_actions.dart';

/// S08 Tashxis natijasi: rasm (bosilsa — kattalashtirish), "{kasallik} ehtimoli", AI ishonchi (model
/// ma'lumoti, sog'lik emas), Belgilar / Keyingi qadamlar / Oldini olish, agronomga yuborish, fikr.
/// Ishonch past bo'lsa kasallik tasdiqlanmagan: dori va reja avtomatik taklif qilinmaydi.
class DiagnosisDetailScreen extends ConsumerWidget {
  const DiagnosisDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final value = ref.watch(diagnosisProvider(id));
    final d = value.value;
    if (d == null) {
      return PageShell(
        padBottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(title: tr('Tashxis natijasi')),
          if (!value.hasError)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            AsyncView(value: value, onRetry: () => ref.invalidate(diagnosisProvider(id)), data: (_) => const SizedBox()),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: c.cream,
      body: _Body(d: d),
      bottomNavigationBar: _ActionBar(d: d),
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
  String _tab = 'symptoms';

  Future<void> _share() async {
    // Ulashish — foydalanuvchi tasdig'idan keyin: rasm va natija jamoatda ommaviy ko'rinadi
    final ok = await confirm(context, tr('Jamoatda ulashish'),
        tr("Rasm va AI natijasi jamoat lentasida hammaga ko'rinadi. Joylashuv va shaxsiy ma'lumotlar qo'shilmaydi."), ok: tr('Ulashish'));
    if (ok && mounted) await shareDiagnosis(context, ref, widget.d);
  }

  void _zoom(String url) => showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (ctx) => Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: Image.network(url, fit: BoxFit.contain, semanticLabel: tr('Barg rasmi'))),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(ctx).top + 8,
            right: 8,
            child: IconButton(
              tooltip: tr('Yopish'),
              style: IconButton.styleFrom(backgroundColor: const Color(0x66000000), minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.d;
    final url = AppConfig.mediaUrl(d.imageUrl);
    final top = MediaQuery.paddingOf(context).top;
    final status = diagnosisStatus(context, d);
    final unsure = d.lowConfidence && !d.isHealthy;
    const ink = Color(0xFF20251B);
    Widget glass(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: Material(
            color: const Color(0xE6FFFFFF),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 44, height: 44, child: Icon(icon, color: ink))),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 300 + top,
              child: Stack(fit: StackFit.expand, children: [
                Semantics(
                  button: url != null,
                  label: tr('Rasmni kattalashtirish'),
                  child: GestureDetector(
                    onTap: url == null ? null : () => _zoom(url),
                    child: url != null
                        ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _PhotoFallback())
                        : const _PhotoFallback(),
                  ),
                ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Color(0x66000000), Color(0x00000000)]),
                    ),
                  ),
                ),
                Positioned(
                  top: top + 8,
                  left: 12,
                  right: 12,
                  child: Row(children: [
                    glass(Icons.arrow_back_rounded, tr('Orqaga'), () => context.canPop() ? context.pop() : context.go('/diagnoses')),
                    const Spacer(),
                    glass(AppIcons.share, tr('Jamoatda ulashish'), _share),
                  ]),
                ),
                if (d.plantName != null)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
                      decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.eco_outlined, size: 18, color: ink),
                        const SizedBox(width: 6),
                        Text(d.plantName!, style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Semantics(header: true, child: Text(diagnosisHeadline(d), style: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, color: c.text))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _Chip(icon: status.icon, label: status.label, bg: status.bg, fg: status.fg),
                  if (d.expertChecked) _Chip(icon: Icons.verified_user_outlined, label: tr('Agronom tekshirgan'), bg: c.oliveSoft, fg: c.onOliveSoft),
                  if (d.diagnosedAt != null) Text(formatDate(d.diagnosedAt), style: TextStyle(color: c.muted, fontSize: 14)),
                ]),
                const SizedBox(height: 16),
                _ConfidenceCard(d: d),
                if (unsure) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => context.push('/diagnose${d.cropId != null ? '?crop=${d.cropId}' : ''}'),
                      icon: const Icon(AppIcons.camera),
                      label: Text(tr('Qayta suratga olish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ExpertBlock(d: d),
                if (d.isHealthy)
                  AppCard(
                    child: Text(d.recommendations ?? tr("Parvarishni davom ettiring: muntazam sug'orish va haftalik ko'rik."),
                        style: TextStyle(fontSize: 16, height: 1.5, color: c.text)),
                  )
                else ...[
                  // ChipTabs: tor ekranda yozuv kichraymaydi, gorizontal suriladi
                  ChipTabs(
                    tabs: [('symptoms', tr('Belgilar')), ('next', tr('Keyingi qadamlar')), ('prevent', tr('Oldini olish'))],
                    selected: _tab,
                    onSelect: (v) => setState(() => _tab = v),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        'next' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            _Steps(text: d.treatment ?? d.recommendations),
                            if (unsure)
                              NoteBox(
                                kind: NoteKind.risk,
                                title: tr("Dori tavsiyasi ko'rsatilmaydi"),
                                text: tr("AI ishonchi past, kasallik tasdiqlanmagan. Dori va me'yorni agronom bilan maslahatlashib tanlang."),
                              )
                            else
                              for (final (i, m) in d.medicines.indexed) _MedicineCard(m: m, primary: i == 0),
                          ]),
                        'prevent' => _Steps(text: d.prevention),
                        _ => _Steps(text: [d.symptoms, d.causes].whereType<String>().join('. ')),
                      },
                    ),
                  ),
                ],
                if (d.diseaseId != null) ...[const SizedBox(height: 8), _CatalogLink(d: d)],
                const SizedBox(height: 12),
                DiagnosisFeedback(d: d),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.c.oliveSoft,
        child: Center(child: Icon(Icons.eco_outlined, size: 96, color: context.c.onOliveSoft)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.bg, required this.fg});
  final IconData icon;
  final String label;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// AI ishonchi — model ma'lumoti, o'simlik sog'lig'i emas (TZ 1, S08). Qiymat serverdan, hardcode yo'q.
class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = d.confidence.clamp(0, 100).round();
    final unsure = d.lowConfidence && !d.isHealthy;
    final bg = unsure ? c.warningBg : c.cream2;
    final fg = unsure ? c.warning : c.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(unsure ? Icons.error_rounded : Icons.auto_awesome_outlined, color: unsure ? c.warning : c.olive),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf('AI ishonch darajasi: {0}%', [pct]), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)),
            const SizedBox(height: 4),
            Text(
              unsure
                  ? tr("Natija taxminiy. Aniqroq surat bilan qayta tekshiring yoki agronomga yuboring.")
                  : tr("Bu modelning javobiga ishonchi — o'simlik sog'lig'i foizi emas."),
              style: TextStyle(fontSize: 15, height: 1.4, color: unsure ? c.warning : c.muted),
            ),
          ]),
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
    if (parts.isEmpty) return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(tr("Ma'lumot mavjud emas"), style: TextStyle(color: c.muted, fontSize: 15)));
    return Column(children: [
      for (final (i, p) in parts.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.oliveSoft, shape: BoxShape.circle),
              child: Text('${i + 1}', style: TextStyle(color: c.onOliveSoft, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(p, style: TextStyle(fontSize: 16, height: 1.45, color: c.text))),
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
          decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(AppIcons.pill, color: c.onOliveSoft, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 2),
            // Me'yor faqat yorliq bo'yicha tasdiqlangan bo'lsa (TZ S22)
            Text((m.labelVerified ? m.recommendation : null) ?? m.activeIngredient ?? '', style: TextStyle(color: c.muted, fontSize: 14, height: 1.35)),
          ]),
        ),
        if (primary) ...[const SizedBox(width: 8), Tag(tr('Asosiy'), bg: c.primaryLight, fg: c.primaryDark)],
      ]),
    );
  }
}

/// Pastki amallar: kasallik aniq bo'lsa — reja (bog'ga bog'lash shu oqim ichida); ishonch past bo'lsa
/// reja taklif qilinmaydi (kasallik tasdiqlanmagan), faqat "Agronomga yuborish" blokdagi tugma.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unsure = d.lowConfidence && !d.isHealthy;
    if (unsure || (!d.isHealthy && d.diseaseName == null)) return const SizedBox.shrink();
    final label = d.cropId != null ? trf('Parvarish rejasi · {0} kun', [planDays(d)]) : trf("Bog'imga qo'shish · {0} kunlik reja", [planDays(d)]);
    return Container(
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => context.push('/diagnosis/${d.id}/plan'),
                  icon: const Icon(Icons.event_note_outlined),
                  label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Agronom bilan bog'liq holat: javob, kutilmoqda yoki "Agronomga yuborish" taklifi (ishonch past bo'lsa ustuvor).
class _ExpertBlock extends ConsumerStatefulWidget {
  const _ExpertBlock({required this.d});
  final Diagnosis d;
  @override
  ConsumerState<_ExpertBlock> createState() => _ExpertBlockState();
}

class _ExpertBlockState extends ConsumerState<_ExpertBlock> {
  bool _busy = false;

  Future<void> _send() async {
    final note = TextEditingController();
    final ok = await showSheet<bool>(context, title: tr('Agronomga yuborish'), builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr("Rasm va AI natijasi biriktiriladi. Agronom tasdiqlaydi yoki to'g'ri kasallikni ko'rsatadi — javob bildirishnoma bo'lib keladi."),
              style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 3, decoration: InputDecoration(hintText: tr('Izoh (ixtiyoriy): qachondan beri, qancha joyda'))),
          const SizedBox(height: 16),
          PillButton(label: tr('Yuborish'), icon: Icons.send_rounded, style: PillStyle.primary, block: true, onPressed: () => Navigator.pop(ctx, true)),
        ]));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(gardenRepoProvider).requestReview(widget.d.id, note: note.text.trim());
      ref.invalidate(diagnosisProvider(widget.d.id));
      if (mounted) showToast(context, tr('Agronomga yuborildi. Javob kelsa xabar beramiz.'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.d;
    Widget pad(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w);
    if (d.expertChecked) {
      return pad(NoteBox(kind: NoteKind.expert, title: d.reviewStatus == 'corrected' ? tr('Agronom tashxisni tuzatdi') : tr('Agronom tashxisni tasdiqladi'),
          text: d.expertComment));
    }
    if (d.reviewStatus == 'rejected') {
      return pad(NoteBox(kind: NoteKind.risk, title: tr('Agronom: rasmni qayta oling'),
          text: d.expertComment ?? tr("Bargni yorug' joyda, yaqinroqdan, tiniq qilib suratga oling.")));
    }
    if (d.reviewRequested) {
      return pad(NoteBox(title: tr('Agronomga yuborildi'), text: tr("Agronom tekshirib javob beradi. Javob kelsa bildirishnoma keladi."),
          icon: Icons.hourglass_top_rounded));
    }
    final expertButton = TextButton.icon(
      onPressed: _busy ? null : _send,
      style: TextButton.styleFrom(
        backgroundColor: c.expert,
        foregroundColor: c.onExpert,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      icon: _busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onExpert)) : const Icon(Icons.send_rounded),
      label: Text(tr('Agronomga yuborish'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    );
    final askLink = TextButton(
      onPressed: () => context.push('/help/ask?diagnosis=${d.id}${d.cropId != null ? '&crop=${d.cropId}' : ''}'),
      child: Text(tr('Yoki agronomga savol bering'), style: TextStyle(color: c.expert, fontWeight: FontWeight.w700)),
    );
    if (d.lowConfidence && !d.isHealthy) {
      return pad(Column(children: [
        NoteBox(kind: NoteKind.risk, title: tr('AI ishonchi past'),
            text: tr("Natija taxminiy. Agronomga yuboring yoki bargni yorug' joyda yaqinroqdan qayta oling.")),
        const SizedBox(height: 10),
        expertButton,
        askLink,
      ]));
    }
    return pad(Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _busy ? null : _send,
        icon: Icon(Icons.verified_user_outlined, color: c.expert),
        label: Text(tr("Agronomga ko'rsatish"), style: TextStyle(color: c.expert, fontWeight: FontWeight.w700)),
      ),
    ));
  }
}

/// Kasallik sahifasiga o'tish (ma'lumotnoma rasmi bilan solishtirish).
class _CatalogLink extends StatelessWidget {
  const _CatalogLink({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) => AppCard(
        shadow: false,
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/catalog/disease/${d.diseaseId}'),
        child: Row(children: [
          CatalogImage(asset: CatalogImages.disease(d.diseaseLabel ?? d.aiLabel), width: 60, height: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr("Ma'lumotnomada ko'rish"), style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              Text(tr("Rasm bilan solishtiring, dorilar va me'yorlar"), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: context.c.subtle),
        ]),
      );
}
