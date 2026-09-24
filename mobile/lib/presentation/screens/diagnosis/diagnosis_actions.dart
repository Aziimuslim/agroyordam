import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
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
