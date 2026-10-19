import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/display_prefs.dart';
import '../../../application/theme_mode.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'settings_widgets.dart';

/// S31 Ko'rinish: mavzu (yorug'/qorong'i/tizimga mos), matn o'lchami, harakat. Tanlov shu ekrandagi namunada
/// ko'rinadi; "Saqlash"gacha global mavzu o'zgarmaydi. Saqlamasdan chiqilsa — avvalgi qiymat qoladi.
class AppearanceScreen extends ConsumerStatefulWidget {
  const AppearanceScreen({super.key});
  @override
  ConsumerState<AppearanceScreen> createState() => _AppearanceState();
}

class _AppearanceState extends ConsumerState<AppearanceScreen> {
  late ThemeMode _mode = ref.read(themeModeProvider);
  late DisplayPrefs _prefs = ref.read(displayPrefsProvider);

  bool get _dirty => _mode != ref.read(themeModeProvider) || _prefs != ref.read(displayPrefsProvider);

  Future<void> _save() async {
    await ref.read(themeModeProvider.notifier).set(_mode);
    await ref.read(displayPrefsProvider.notifier).set(_prefs);
    if (!mounted) return;
    showToast(context, tr('Saqlandi'));
    setState(() {});
    await WidgetsBinding.instance.endOfFrame; // PopScope yangi (saqlangan) holatni olsin
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    ref.watch(displayPrefsProvider);
    final c = context.c;
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final previewDark = _mode == ThemeMode.dark || (_mode == ThemeMode.system && platformDark);
    return UnsavedGuard(
      dirty: _dirty,
      child: PageShell(
        maxWidth: 640,
        padBottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TopBar(title: tr("Ko'rinish")),
            Text(
              tr('Namuna'),
              style: TextStyle(fontSize: 14, color: c.muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _Preview(dark: previewDark, textFactor: _prefs.textFactor),
            SettingsSection(tr('Mavzu')),
            for (final (m, icon, label, sub) in [
              (ThemeMode.light, Icons.light_mode_outlined, tr("Yorug'"), null),
              (ThemeMode.dark, Icons.dark_mode_outlined, tr("Qorong'i"), null),
              (ThemeMode.system, Icons.brightness_auto_outlined, tr('Tizimga mos'), tr("Telefon sozlamasiga qarab o'zgaradi")),
            ])
              ChoiceTile(
                selected: _mode == m,
                leading: Icon(icon, color: c.text),
                title: label,
                subtitle: sub,
                onTap: () => setState(() => _mode = m),
              ),
            SettingsSection(tr("Matn o'lchami")),
            ChoiceTile(selected: !_prefs.largeText, title: tr('Oddiy'), onTap: () => setState(() => _prefs = _prefs.copyWith(largeText: false))),
            ChoiceTile(
              selected: _prefs.largeText,
              title: tr('Katta'),
              subtitle: tr("Telefon shrift o'lchamiga qo'shimcha kattalashtiradi"),
              onTap: () => setState(() => _prefs = _prefs.copyWith(largeText: true)),
            ),
            SettingsSection(tr('Harakat')),
            ChoiceTile(selected: !_prefs.reduceMotion, title: tr('Tizimga mos'), onTap: () => setState(() => _prefs = _prefs.copyWith(reduceMotion: false))),
            ChoiceTile(
              selected: _prefs.reduceMotion,
              title: tr('Kamaytirilgan'),
              subtitle: tr("Ob-havo animatsiyasi va o'tishlar o'chadi"),
              onTap: () => setState(() => _prefs = _prefs.copyWith(reduceMotion: true)),
            ),
            const SizedBox(height: 18),
            SaveBar(enabled: _dirty, onSave: _save),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Tanlangan mavzu va matn o'lchamining kichik namunasi (haqiqiy komponent ranglari bilan).
class _Preview extends StatelessWidget {
  const _Preview({required this.dark, required this.textFactor});
  final bool dark;
  final double textFactor;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Theme(
      data: dark ? AppTheme.dark : AppTheme.light,
      child: MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * textFactor)),
        child: Builder(
          builder: (context) {
            final c = context.c;
            return ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr("Mening bog'im"),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.eco_outlined, color: c.olive),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('Pomidor'),
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
                                ),
                                Text(
                                  tr('Kuzatuv kerak'),
                                  style: TextStyle(fontSize: 13, color: c.warning, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        tr('Ekinni tekshirish'),
                        style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
