import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';

final notificationSettingsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) => ref.watch(communityRepoProvider).notificationSettings());

/// A05 Bildirishnoma turlari: vazifalar, xabarlar, jamoat, xizmat. Har o'zgarish darhol saqlanadi; xatoda qaytadi.
/// Telefon push bildirishnomasi hali ulanmagan — bu ochiq aytiladi (ilova ichidagi bildirishnomalar boshqariladi).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<NotificationSettingsScreen> {
  Map<String, bool>? _local;
  String? _saving;

  Future<void> _set(Map<String, bool> current, String key, bool value) async {
    final next = {...current, key: value};
    setState(() {
      _local = next;
      _saving = key;
    });
    try {
      final saved = await ref.read(communityRepoProvider).saveNotificationSettings(next);
      if (mounted) setState(() => _local = saved);
    } catch (e) {
      if (mounted) {
        setState(() => _local = current); // xatoda avvalgi holat
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(notificationSettingsProvider);
    final server = v.value;
    final prefs = _local ?? server;
    final items = [
      ('tasks', Icons.task_alt_rounded, tr('Vazifalar va eslatmalar'), tr("Parvarish vazifasi vaqti kelganda")),
      ('messages', Icons.chat_bubble_outline_rounded, tr('Xabarlar'), tr('Shaxsiy xabarlar va agronom javoblari')),
      ('community', Icons.groups_outlined, tr('Jamoat'), tr('Postingizga izoh, layk va yangi obunachilar')),
      ('service', Icons.info_outline_rounded, tr('Xizmat xabarlari'), tr("Tashxis tekshiruvi, obuna, ariza natijasi va e'lonlar")),
    ];
    return PageShell(
      maxWidth: 640,
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Bildirishnoma sozlamalari')),
        if (prefs == null && v.hasError)
          BlockError(error: v.error!, what: tr('Sozlamalar'), onRetry: () => ref.invalidate(notificationSettingsProvider))
        else if (prefs == null)
          const Skeleton(height: 260)
        else
          Container(
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
            child: Column(children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  decoration: BoxDecoration(border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: c.border))),
                  child: SwitchListTile(
                    value: prefs[items[i].$1] ?? true,
                    onChanged: _saving != null ? null : (val) => _set(prefs, items[i].$1, val),
                    secondary: Icon(items[i].$2, color: c.olive),
                    title: Text(items[i].$3, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                    subtitle: Text(items[i].$4, style: TextStyle(fontSize: 14, color: c.muted)),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.phone_android_rounded, color: c.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr("Telefon push bildirishnomalari hali ulanmagan — bildirishnomalar ilova ichidagi «Bildirishnomalar» bo'limida ko'rinadi. O'chirilgan turdagi yangi bildirishnomalar yaratilmaydi. Xavfsizlik xabarlari (masalan, parol tiklash) doim keladi."),
                style: TextStyle(fontSize: 14, height: 1.4, color: c.text),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
