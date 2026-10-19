import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

void _refresh(WidgetRef ref, String id) {
  ref.invalidate(cropsProvider);
  ref.invalidate(archivedCropsProvider);
  ref.invalidate(cropProvider(id));
  // Arxivlangan ekin vazifalari umumiy ro'yxatdan chiqadi (server filtri)
  ref.invalidate(remindersProvider);
  ref.invalidate(cropRemindersProvider);
}

/// Arxivlash (TZ S02): tasdiq → server → ro'yxat yangilanadi, "Bekor qilish" taklif qilinadi.
/// Tarix (tashxis, kundalik, vazifalar) o'chmaydi.
Future<bool> archiveCrop(BuildContext context, WidgetRef ref, Crop crop) async {
  final ok = await confirm(
    context,
    tr('Ekinni arxivlash'),
    trf("{0} faol ro'yxatdan olinadi, vazifalari umumiy ro'yxatda ko'rinmaydi. Tarix saqlanadi va istalgan vaqtda tiklash mumkin.", [crop.name]),
    ok: tr('Arxivlash'),
  );
  if (!ok || !context.mounted) return false;
  final repo = ref.read(gardenRepoProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await repo.setCropArchived(crop.id, true);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
  _refresh(ref, crop.id);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(trf('{0} arxivlandi', [crop.name])),
        action: SnackBarAction(
          label: tr('Bekor qilish'),
          onPressed: () async {
            try {
              await repo.setCropArchived(crop.id, false);
              _refresh(ref, crop.id);
            } catch (_) {
              messenger.showSnackBar(SnackBar(content: Text(tr("Bekor qilib bo'lmadi. Qayta urinib ko'ring"))));
            }
          },
        ),
      ),
    );
  return true;
}

/// Arxivdan tiklash. Bepul rejada ekin limiti bo'lsa server 402 qaytaradi → Premium sahifasi.
Future<bool> restoreCrop(BuildContext context, WidgetRef ref, Crop crop) async {
  try {
    await ref.read(gardenRepoProvider).setCropArchived(crop.id, false);
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
  _refresh(ref, crop.id);
  if (context.mounted) showToast(context, trf('{0} tiklandi', [crop.name]));
  return true;
}

/// A04 Kuzatuv yozish (1–2000 belgi). Saqlash ekin kundaligiga yozadi; tashxisga aylanmaydi.
Future<void> addObservation(BuildContext context, WidgetRef ref, String cropId) async {
  final ctrl = TextEditingController();
  final text = await showSheet<String>(context, title: tr('Kuzatuv yozish'), builder: (ctx) {
    return StatefulBuilder(builder: (ctx, set) {
      final len = ctrl.text.trim().length;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: ctrl,
          maxLines: 5,
          maxLength: 2000,
          autofocus: true,
          onChanged: (_) => set(() {}),
          decoration: InputDecoration(hintText: tr("Bugun nimani kuzatdingiz? (barglar, sug'orish, o'g'itlash...)")),
        ),
        const SizedBox(height: 12),
        PillButton(label: tr('Saqlash'), block: true, onPressed: len == 0 ? null : () => Navigator.pop(ctx, ctrl.text.trim())),
      ]);
    });
  });
  if (text == null || text.isEmpty) return;
  try {
    await ref.read(gardenRepoProvider).addLog(cropId, text);
    ref.invalidate(cropLogsProvider(cropId));
    if (context.mounted) showToast(context, tr('Kuzatuv saqlandi'));
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
