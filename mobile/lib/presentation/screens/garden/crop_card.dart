import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crop_status.dart';
import '../../../domain/entities/entities.dart';
import 'crop_photo.dart';

/// Ekin kartasi (S01, S02): surat, nom, holat belgisi (foizsiz), qisqa izoh.
class CropCard extends StatelessWidget {
  const CropCard({super.key, required this.crop, this.onMenu});
  final Crop crop;

  /// Berilsa — kartada "⋮" (tahrirlash/arxivlash) tugmasi (S02).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = cropState(crop);
    final s = cropStateStyle(context, crop);
    final note = switch (state) {
      CropState.attention || CropState.watch => crop.lastDisease ?? tr("Barglarda o'zgarishlar kuzatilmoqda"),
      CropState.noData => tr('Hali tekshirilmagan'),
      CropState.healthy => trf("{0} tekshiruvida muammo ko'rinmadi", [shortDate(crop.lastDiagnosisAt!)]),
    };
    final card = Semantics(
      button: true,
      label: '${crop.name}. ${s.label}. $note',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/garden/${crop.id}'),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: Stack(fit: StackFit.expand, children: [
                  CropPhoto(crop: crop),
                  if (state == CropState.attention || state == CropState.healthy)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                        child: Icon(s.icon, size: 24, color: s.fg),
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: EdgeInsets.only(right: onMenu != null ? 32 : 0),
                    child: Text(crop.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w800, color: c.text)),
                  ),
                  const SizedBox(height: 6),
                  CropStatusChip(crop: crop),
                  const SizedBox(height: 6),
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, height: 1.3, color: c.muted)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (onMenu == null) return card;
    // "⋮" kartaning semantik guruhidan tashqarida — ekran o'quvchida alohida tugma
    return LayoutBuilder(
      builder: (context, box) => Stack(children: [
        card,
        Positioned(
          right: 2,
          top: box.maxWidth / 1.5 + 2,
          child: IconButton(
            tooltip: trf('{0}: amallar', [crop.name]),
            onPressed: onMenu,
            icon: Icon(Icons.more_vert_rounded, color: c.muted),
          ),
        ),
      ]),
    );
  }
}

