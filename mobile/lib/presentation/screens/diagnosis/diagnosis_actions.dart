import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

Future<void> shareDiagnosis(BuildContext context, WidgetRef ref, Diagnosis d) async {
  try {
    await ref.read(gardenRepoProvider).shareDiagnosis(d.id);
    ref.invalidate(feedProvider('all'));
    if (context.mounted) showToast(context, tr('Jamoatda ulashildi'));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

/// Reja davomiyligi (backend care_plan.py bilan bir xil): xavf bo'yicha 10/14/21, sog'lom — 7 kun.
int planDays(Diagnosis d) => d.isHealthy ? 7 : switch (d.riskLevel) { 'high' => 21, 'low' => 10, _ => 14 };

/// "AI to'g'ri topdimi?" — javoblar dataset tekshiruvida ishlatiladi ("xato"lar birinchi ko'riladi).
class DiagnosisFeedback extends ConsumerStatefulWidget {
  const DiagnosisFeedback({super.key, required this.d});
  final Diagnosis d;
  @override
  ConsumerState<DiagnosisFeedback> createState() => _DiagnosisFeedbackState();
}

class _DiagnosisFeedbackState extends ConsumerState<DiagnosisFeedback> {
  late bool? _value = widget.d.userFeedback;

  /// "Yo'q"dan keyin ixtiyoriy sabab (TZ S08): bir marta yuboriladi yoki o'tkazib yuboriladi.
  late bool _reasonDone = widget.d.userFeedback != false || (widget.d.feedbackReason ?? '').isNotEmpty;
  final _reason = TextEditingController();
  String? _chip;
  bool _sending = false;

  static List<String> get _chips => [tr('Boshqa kasallik'), tr("O'simlik sog'lom"), tr('Boshqa ekin'), tr('Rasm sifatsiz')];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send(bool correct) async {
    setState(() => _value = correct);
    try {
      await ref.read(gardenRepoProvider).feedback(widget.d.id, correct);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _sendReason() async {
    final text = [if (_chip != null) _chip!, if (_reason.text.trim().isNotEmpty) _reason.text.trim()].join('. ');
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(gardenRepoProvider).feedback(widget.d.id, false, reason: text.length > 500 ? text.substring(0, 500) : text);
      if (mounted) setState(() => _reasonDone = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_value == false && !_reasonDone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Nima noto\'g\'ri? (ixtiyoriy)'), style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ch in _chips)
            ChoiceChip(label: Text(ch), selected: _chip == ch, onSelected: (v) => setState(() => _chip = v ? ch : null)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _reason,
          maxLength: 300,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 15),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('Izoh (masalan, aslida qanday kasallik)'), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        ),
        Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
          TextButton(onPressed: _sending ? null : () => setState(() => _reasonDone = true), child: Text(tr("O'tkazib yuborish"))),
          FilledButton(
            onPressed: _sending || (_chip == null && _reason.text.trim().isEmpty) ? null : _sendReason,
            child: Text(tr('Yuborish')),
          ),
        ]),
      ]);
    }
    if (_value != null) {
      return Row(children: [
        Icon(AppIcons.check, size: 18, color: c.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_value! ? tr("Rahmat! Fikringiz AI'ni yaxshilashga yordam beradi.") : tr("Rahmat! Mutaxassis rasmni tekshirib, AI'ni shu asosda o'rgatadi."),
              style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]);
    }
    Widget btn(bool v, IconData icon, String label) => Material(
          color: Colors.transparent,
          shape: StadiumBorder(side: BorderSide(color: c.border, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _send(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: c.text),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
            ),
          ),
        );
    return Row(children: [
      Expanded(child: Text(tr("AI to'g'ri topdimi?"), style: TextStyle(color: c.muted, fontSize: 13.5, fontWeight: FontWeight.w700))),
      btn(true, AppIcons.thumbUp, tr('Ha')),
      const SizedBox(width: 8),
      btn(false, AppIcons.thumbDown, tr("Yo'q")),
    ]);
  }
}
