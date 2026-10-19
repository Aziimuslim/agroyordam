import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/lang.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lang_sheet.dart';
import '../../../core/widgets/widgets.dart';
import 'settings_widgets.dart';

/// S32 Til: qidiruv, radio tanlov va shu tildagi namuna. "Saqlash" butun ilovani o'zgartiradi; ochiq sahifa,
/// ma'lumot va sessiya saqlanadi. Foydalanuvchi yozgan post va ismlar tarjima qilinmaydi.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});
  @override
  ConsumerState<LanguageScreen> createState() => _LanguageState();
}

class _LanguageState extends ConsumerState<LanguageScreen> {
  late AppLang _lang = ref.read(langProvider);
  String _q = '';
  bool _saving = false;

  bool get _dirty => _lang != ref.read(langProvider);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(langProvider.notifier).set(_lang);
    if (!mounted) return;
    setState(() => _saving = false);
    showToast(context, tr('Saqlandi'));
    await WidgetsBinding.instance.endOfFrame; // PopScope yangi (saqlangan) holatni olsin
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(langProvider);
    final c = context.c;
    final q = _q.trim().toLowerCase();
    final langs = AppLang.values.where((l) => q.isEmpty || '${l.label} ${l.code} ${l.short}'.toLowerCase().contains(q)).toList();
    return UnsavedGuard(
      dirty: _dirty,
      child: PageShell(
        maxWidth: 640,
        padBottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar(title: tr('Ilova tili')),
            TextField(
              onChanged: (s) => setState(() => _q = s),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(hintText: tr('Tilni qidirish'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            ),
            const SizedBox(height: 12),
            if (langs.isEmpty) EmptyNote(tr('Hech narsa topilmadi'), icon: Icons.search_off_rounded),
            for (final l in langs) ChoiceTile(selected: _lang == l, leading: FlagIcon(l, size: 32), title: l.label, onTap: () => setState(() => _lang = l)),
            const SizedBox(height: 8),
            // Tanlangan tildagi namuna — global til hali o'zgarmagan
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Namuna'),
                    style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${trIn(_lang, 'Bosh sahifa')} · ${trIn(_lang, "Mening bog'im")} · ${trIn(_lang, 'Ekinni tekshirish')}',
                    style: TextStyle(fontSize: 16, color: c.text, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(tr("Siz va boshqalar yozgan postlar, ismlar tarjima qilinmaydi."), style: TextStyle(fontSize: 13.5, color: c.muted)),
            const SizedBox(height: 18),
            SaveBar(enabled: _dirty && !_saving, onSave: _save),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
