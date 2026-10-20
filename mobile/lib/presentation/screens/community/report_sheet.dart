import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// A08 Shikoyat: sabab majburiy, izoh ixtiyoriy (≤ 1000). Yuborilgandan keyin tasdiq.
Future<void> showReportSheet(BuildContext context, WidgetRef ref, {String? postId, String? commentId, String? messageId}) async {
  final reasons = [tr('Spam yoki reklama'), tr("Haqoratli yoki hurmatsiz so'z"), tr("Noto'g'ri yoki xavfli maslahat"), tr('Boshqa sabab')];
  String? reason;
  final note = TextEditingController();
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.c.card,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final c = ctx.c;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Shikoyat qilish'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 4),
            Text(tr('Sababni tanlang — moderator ko\'rib chiqadi.'), style: TextStyle(fontSize: 14, color: c.muted)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (v) => set(() => reason = v),
              child: Column(children: [for (final r in reasons) RadioListTile<String>(value: r, title: Text(r), contentPadding: EdgeInsets.zero)]),
            ),
            TextField(
              controller: note,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(hintText: tr('Izoh (ixtiyoriy)')),
            ),
            const SizedBox(height: 8),
            PillButton(label: tr('Yuborish'), block: true, onPressed: reason == null ? null : () => Navigator.pop(ctx, true)),
          ]),
        ),
      );
    }),
  );
  if (sent != true || reason == null) return;
  // sabab (≤ 100) va izoh (≤ 1000) alohida maydonlarda — uzun izoh shikoyatni rad ettirmaydi
  try {
    await ref.read(communityRepoProvider).report(
        postId: postId, commentId: commentId, messageId: messageId, reason: reason!, description: note.text.trim().isEmpty ? null : note.text.trim());
    if (context.mounted) showToast(context, tr("Shikoyat yuborildi. Moderator ko'rib chiqadi."));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
