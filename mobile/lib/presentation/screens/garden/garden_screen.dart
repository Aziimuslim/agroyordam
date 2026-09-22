import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});
  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  String sort = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final crops = ref.watch(cropsProvider);

    return PageShell(
      bottom: const AppBottomNav(current: '/garden'),
      onRefresh: () async => ref.invalidate(cropsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text("Mening bog'im", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          _PlusButton(onTap: () => context.push('/garden/add')),
        ]),
        const SizedBox(height: 18),
        AsyncView(
          value: crops,
          onRetry: () => ref.invalidate(cropsProvider),
          data: (list) {
            final avg = list.isEmpty ? 100 : (list.map((e) => e.healthScore).reduce((a, b) => a + b) / list.length).round();
            final sick = list.any((e) => e.healthScore < 70);
            final sorted = [...list];
            if (sort == 'az') sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (sort == 'health') sorted.sort((a, b) => a.healthScore.compareTo(b.healthScore));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppCard(
                child: Row(children: [
                  HealthRing(avg),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Umumiy sog'liq holati", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(sick ? Icons.warning_amber_rounded : AppIcons.check, size: 16, color: sick ? c.gold : c.success),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(sick ? "Ba'zi ekinlarga e'tibor kerak" : "Barcha ekinlar sog'lom",
                              style: TextStyle(color: sick ? c.primaryDark : c.success, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
              ChipTabs(
                tabs: const [('all', 'Barchasi'), ('az', 'A-Z'), ('health', "E'tibor kerak")],
                selected: sort,
                onSelect: (v) => setState(() => sort = v),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (final crop in sorted) _CropTile(crop: crop),
                  _AddTile(onTap: () => context.push('/garden/add')),
                ],
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

class CropRowCard extends StatelessWidget {
  const CropRowCard({super.key, required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) => RowCard(
        leading: ThumbIcon(icon: AppIcons.forPlant(crop.plantName ?? crop.name)),
        title: crop.name,
        subtitle: [crop.plantName, crop.lastDisease].whereType<String>().join(' · '),
        trailing: PctBadge(crop.healthScore),
        onTap: () => context.push('/garden/${crop.id}'),
      );
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/garden/${crop.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: c.tan,
            child: Icon(AppIcons.forPlant(crop.plantName ?? crop.name), size: 34, color: c.primaryDark),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(crop.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(crop.plantName ?? "Tur ko'rsatilmagan", style: TextStyle(fontSize: 12, color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            PctBadge(crop.healthScore),
          ]),
        ),
      ]),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: CustomPaint(
        painter: _DashedBorder(c.border),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _PlusButton(onTap: onTap),
            const SizedBox(height: 8),
            Text("Ekin qo'shish", style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: context.c.primaryLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(AppIcons.plus, color: context.c.primaryDark)),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(AppRadius.md)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => old.color != color;
}
