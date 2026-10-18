import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

/// Ekin holati (TZ 1-bo'lim): foiz ko'rsatilmaydi, AI ishonchi sog'lik emas.
/// "Sog'lom" faqat sanasi bilan — oxirgi kuzatuvdagi vaqtli xulosa.
enum CropState { noData, healthy, watch, attention }

CropState cropState(Crop c) {
  if (c.lastDiagnosisAt == null) return CropState.noData;
  final sick = c.lastDisease != null && c.lastDisease!.trim().isNotEmpty;
  if (sick && c.healthScore < 45) return CropState.attention;
  if (sick || c.healthScore < 70) return CropState.watch;
  return CropState.healthy;
}

/// Saralash: e'tibor kerak → kuzatuv → ma'lumot yo'q → sog'lom.
int cropStateRank(CropState s) => switch (s) {
      CropState.attention => 0,
      CropState.watch => 1,
      CropState.noData => 2,
      CropState.healthy => 3,
    };

String shortDate(DateTime d) => formatDayMonth(d);

({String label, IconData icon, Color bg, Color fg}) cropStateStyle(BuildContext context, Crop crop, {bool withDate = false}) {
  final c = context.c;
  return switch (cropState(crop)) {
    CropState.attention => (label: tr("E'tibor kerak"), icon: Icons.error_rounded, bg: c.dangerBg, fg: c.danger),
    CropState.watch => (label: tr('Kuzatuv kerak'), icon: Icons.visibility_outlined, bg: c.warningBg, fg: c.warning),
    CropState.noData => (label: tr("Ma'lumot yetarli emas"), icon: Icons.help_outline_rounded, bg: c.cream2, fg: c.muted),
    CropState.healthy => (
        // Sana karta izohida beriladi (tor kartada kesilmasin): "{sana} tekshiruvida…"
        label: withDate ? trf("Sog'lom · {0}", [shortDate(crop.lastDiagnosisAt!)]) : tr("Sog'lom"),
        icon: Icons.check_circle_rounded,
        bg: c.successBg,
        fg: c.success
      ),
  };
}

/// Holat belgisi: ikonka + matn (rang yolg'iz ma'no tashimaydi).
class CropStatusChip extends StatelessWidget {
  const CropStatusChip({super.key, required this.crop, this.withDate = false});
  final Crop crop;

  /// "Sog'lom" yonida oxirgi tekshiruv sanasi (keng joyda — S06 header).
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final s = cropStateStyle(context, crop, withDate: withDate);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: 16, color: s.fg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(s.label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.fg, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
