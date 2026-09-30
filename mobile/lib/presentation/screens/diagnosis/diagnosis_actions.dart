import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

Future<void> shareDiagnosis(BuildContext context, WidgetRef ref, Diagnosis d) async {
  try {
    await ref.read(gardenRepoProvider).shareDiagnosis(d.id);
    ref.invalidate(feedProvider('all'));
    if (context.mounted) showToast(context, 'Jamoatda ulashildi');
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

  Future<void> _send(bool correct) async {
    setState(() => _value = correct);
    try {
      await ref.read(gardenRepoProvider).feedback(widget.d.id, correct);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_value != null) {
      return Row(children: [
        Icon(AppIcons.check, size: 18, color: c.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_value! ? "Rahmat! Fikringiz AI'ni yaxshilashga yordam beradi." : "Rahmat! Mutaxassis rasmni tekshirib, AI'ni shu asosda o'rgatadi.",
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
      Expanded(child: Text("AI to'g'ri topdimi?", style: TextStyle(color: c.muted, fontSize: 13.5, fontWeight: FontWeight.w700))),
      btn(true, AppIcons.thumbUp, 'Ha'),
      const SizedBox(width: 8),
      btn(false, AppIcons.thumbDown, "Yo'q"),
    ]);
  }
}
