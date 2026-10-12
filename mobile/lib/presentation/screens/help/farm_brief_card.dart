import 'package:flutter/material.dart';

import '../../../core/data/farm_options.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Agronom savolni o'qiyotganda: dehqon xo'jaligi haqida qisqacha (hudud, maydon, ekinlar, sug'orish).
class FarmBriefCard extends StatelessWidget {
  const FarmBriefCard(this.farm, {super.key});
  final FarmBrief farm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final place = placeText(farm.region, farm.district);
    final farmLine = [
      if (farm.farmType != null) farmTypes[farm.farmType] ?? farm.farmType,
      if (farm.farmArea != null) formatArea(farm.farmArea),
    ].join(' · ');
    final rows = <(IconData, String)>[
      if (place.isNotEmpty) (Icons.location_on_outlined, place),
      if (farmLine.isNotEmpty) (Icons.agriculture_outlined, farmLine),
      if (farm.irrigation != null) (Icons.water_drop_outlined, irrigationTypes[farm.irrigation] ?? farm.irrigation!),
      if (farm.experienceYears != null) (Icons.workspace_premium_outlined, '${farm.experienceYears} yillik tajriba'),
    ];
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      margin: const EdgeInsets.only(top: 12),
      color: c.expertBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("DEHQON XO'JALIGI", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.expert)),
        const SizedBox(height: 6),
        if (farm.isEmpty)
          Text("Dehqon xo'jalik ma'lumotlarini hali to'ldirmagan", style: TextStyle(color: c.muted, fontSize: 13.5)),
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: c.expert),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3))),
            ]),
          ),
        if (farm.mainCrops.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final crop in farm.mainCrops) StatusTag(crop, kind: StatusKind.expert),
          ]),
        ],
      ]),
    );
  }
}
