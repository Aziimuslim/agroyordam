import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

final _fmt = DateFormat('yyyy-MM-dd');

/// Tashxisdan davolash rejasi bo'yicha eslatmalar yaratadi.
Future<void> addRemindersFromDiagnosis(BuildContext context, WidgetRef ref, Diagnosis d) async {
  final repo = ref.read(gardenRepoProvider);
  final now = DateTime.now();
  final med = d.medicines.isNotEmpty ? d.medicines.first : null;
  final items = <Map<String, dynamic>>[
    {
      'title': med != null ? '${med.name} bilan ishlov berish' : '${d.title}: davolash',
      'description': med?.recommendation ?? d.treatment ?? d.recommendations,
      'reminder_type': 'treatment',
      'reminder_date': _fmt.format(now),
    },
    if (med != null)
      {
        'title': '${med.name} bilan qayta ishlov berish',
        'description': med.recommendation,
        'reminder_type': 'treatment',
        'reminder_date': _fmt.format(now.add(const Duration(days: 7))),
      },
    {
      'title': 'Qayta tashxis: ${d.title}',
      'description': "Yangi barglarni tekshiring va natijani AI tashxis orqali solishtiring.",
      'reminder_type': 'recheck',
      'reminder_date': _fmt.format(now.add(const Duration(days: 10))),
    },
  ];
  try {
    for (final it in items) {
      await repo.createReminder({...it, 'crop_id': d.cropId, 'diagnosis_id': d.id});
    }
    ref.invalidate(remindersProvider);
    if (context.mounted) showToast(context, "${items.length} ta eslatma qo'shildi");
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> shareDiagnosis(BuildContext context, WidgetRef ref, Diagnosis d) async {
  try {
    await ref.read(gardenRepoProvider).shareDiagnosis(d.id);
    ref.invalidate(feedProvider('all'));
    if (context.mounted) showToast(context, 'Jamoatda ulashildi');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
