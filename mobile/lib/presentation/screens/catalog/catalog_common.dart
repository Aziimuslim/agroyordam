import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../domain/entities/entities.dart';

/// O'simlik toifasi (TZ S17): uzum — "Tok", mevali daraxt emas.
String plantCategoryLabel(String? c) => switch (c) {
      'vegetable' => tr('Sabzavot'),
      'fruit' => tr('Mevali daraxt'),
      'vine' => tr('Tok'),
      'grain' => tr('Donli'),
      'berry' => tr('Rezavor'),
      'melon' => tr('Poliz'),
      _ => tr('Tasniflanmagan'),
    };

IconData plantCategoryIcon(String? c) => switch (c) {
      'vegetable' => Icons.eco_outlined,
      'fruit' => Icons.park_outlined,
      'vine' => Icons.spa_outlined,
      'grain' => Icons.grass_rounded,
      'berry' => Icons.local_florist_outlined,
      _ => Icons.eco_outlined,
    };

/// Dori toifasi — faqat katalogdagi tasnif (taxmin yo'q; TZ S19: filtr aynan tasnifga mos).
({String label, IconData icon}) medicineCategory(String? c) => switch (c) {
      'fungicide' => (label: tr('Fungitsid'), icon: Icons.science_outlined),
      'insecticide' => (label: tr('Insektitsid'), icon: Icons.pest_control_outlined),
      'acaricide' => (label: tr('Akaritsid'), icon: Icons.bug_report_outlined),
      'biological' => (label: tr('Biologik'), icon: Icons.spa_outlined),
      _ => (label: tr('Tasniflanmagan'), icon: Icons.inventory_2_outlined),
    };

/// Faol modda / tayyor mahsulot / aralashma — alohida turlar (TZ S19).
String? medicineKindLabel(String? k) => switch (k) {
      'active' => tr('Faol modda'),
      'product' => tr('Tayyor mahsulot'),
      'mixture' => tr('Aralashma'),
      _ => null,
    };

/// Me'yor faqat yorliq bo'yicha tasdiqlangan bo'lsa (TZ S22). Aks holda null — UI tushuntirish ko'rsatadi.
String? verifiedDose(Medicine m, [String? text]) => m.labelVerified ? (text ?? m.usage) : null;

/// Manba va yangilangan sana qatori (TZ S18/S21/S22). Manba yo'q bo'lsa — shunday deb yoziladi, uydirilmaydi.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, this.source, this.updatedAt, this.imageCredit});
  final String? source, imageCredit;
  final DateTime? updatedAt;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <(IconData, String)>[
      (Icons.menu_book_outlined, (source ?? '').trim().isEmpty ? tr("Manba ko'rsatilmagan — AgroYordam bilimlar bazasi") : trf('Manba: {0}', [source!.trim()])),
      if (updatedAt != null) (Icons.update_rounded, trf('Yangilangan: {0}', [formatDate(updatedAt)])),
      if (imageCredit != null) (Icons.image_outlined, trf('Rasm: {0}', [imageCredit!])),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final (icon, text) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: c.muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: c.muted, height: 1.35))),
          ]),
        ),
    ]);
  }
}

/// Rasmni to'liq ekranda kattalashtirish (ikki barmoq / g'ildirak), yorliq matn bilan — rangga bog'liq emas.
Future<void> showImageViewer(BuildContext context, {String? asset, String? url, required String label}) => showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: CatalogImage(asset: asset, url: url, radius: 0)),
          ),
        ),
        Positioned(
          left: 16,
          right: 72,
          top: MediaQuery.paddingOf(ctx).top + 14,
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Positioned(
          top: MediaQuery.paddingOf(ctx).top + 4,
          right: 8,
          child: IconButton(
            tooltip: tr('Yopish'),
            style: IconButton.styleFrom(backgroundColor: const Color(0x66000000), minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ]),
    );

/// Kartadagi kichik yorliq: ikonka + matn.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label, this.bg, this.fg});
  final IconData icon;
  final String label;
  final Color? bg, fg;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(color: bg ?? c.oliveSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: fg ?? c.onOliveSoft),
        const SizedBox(width: 4),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg ?? c.onOliveSoft))),
      ]),
    );
  }
}
