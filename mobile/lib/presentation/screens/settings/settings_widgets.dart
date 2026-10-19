import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// Radio qator (48 px+): tanlangani rangli chegara bilan.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.selected, required this.title, this.subtitle, this.leading, required this.onTap});
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        label: [title, if (subtitle != null) subtitle!].join(', '),
        excludeSemantics: true,
        child: Material(
          color: selected ? c.oliveSoft : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? c.olive : c.border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected ? c.onOliveSoft : c.text),
                          ),
                          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13.5, color: selected ? c.onOliveSoft : c.muted)),
                        ],
                      ),
                    ),
                    Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? c.olive : c.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saqlanmagan tanlov bilan chiqishda so'raydi (TZ S31/S32): chiqilsa eski qiymat qoladi.
class UnsavedGuard extends StatelessWidget {
  const UnsavedGuard({super.key, required this.dirty, required this.child, this.fallback = '/profile'});
  final bool dirty;
  final Widget child;
  final String fallback;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final leave = await confirm(context, tr("O'zgarishlar saqlanmagan"), tr('Saqlamasdan chiqsangiz, avvalgi sozlama qoladi.'), ok: tr('Chiqish'), danger: true);
      if (!leave || !context.mounted) return;
      if (context.canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(fallback);
      }
    },
    child: child,
  );
}

/// Pastdagi "Saqlash" tugmasi: o'zgarish bo'lmasa o'chiq.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.enabled, required this.onSave, this.label});
  final bool enabled;
  final VoidCallback onSave;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: enabled ? onSave : null,
        child: Text(label ?? tr('Saqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.c.text),
      ),
    ),
  );
}
