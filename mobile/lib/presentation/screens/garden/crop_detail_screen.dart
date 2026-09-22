import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'add_crop_screen.dart';

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crop = ref.watch(cropProvider(id));
    return PageShell(
      padBottom: false,
      onRefresh: () async {
        ref.invalidate(cropProvider(id));
        ref.invalidate(cropHealthProvider(id));
        ref.invalidate(cropDiagnosesProvider(id));
        ref.invalidate(cropLogsProvider(id));
      },
      child: AsyncView(
        value: crop,
        onRetry: () => ref.invalidate(cropProvider(id)),
        data: (crop) => _Body(crop: crop),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.crop});
  final Crop crop;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(context, "Ekinni o'chirish", "${crop.name} va uning tarixi o'chiriladi.", ok: "O'chirish", danger: true)) return;
    try {
      await ref.read(gardenRepoProvider).deleteCrop(crop.id);
      ref.invalidate(cropsProvider);
      if (context.mounted) {
        showToast(context, "Ekin o'chirildi");
        context.go('/garden');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _addLog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final text = await showSheet<String>(context, title: 'Kundalikka yozuv', builder: (ctx) => Column(children: [
          TextField(controller: ctrl, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: "Bugun nima qildingiz? (sug'orish, o'g'itlash...)")),
          const SizedBox(height: 14),
          PillButton(label: 'Saqlash', block: true, onPressed: () => Navigator.pop(ctx, ctrl.text.trim())),
        ]));
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(gardenRepoProvider).addLog(crop.id, text);
      ref.invalidate(cropLogsProvider(crop.id));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final health = ref.watch(cropHealthProvider(crop.id));
    final diags = ref.watch(cropDiagnosesProvider(crop.id));
    final logs = ref.watch(cropLogsProvider(crop.id));
    final reminders = ref.watch(remindersProvider);
    final last = diags.value?.isNotEmpty == true ? diags.value!.first : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TopBar(title: crop.name, actions: [
        CircleIconButton(icon: AppIcons.edit, tooltip: 'Tahrirlash', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddCropScreen(crop: crop)))),
      ]),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            ThumbIcon(icon: AppIcons.forPlant(crop.plantName ?? crop.name), size: 70, radius: 20),
            const SizedBox(height: 12),
            Text(crop.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text([crop.plantName, crop.variety].whereType<String>().join(' · '), style: TextStyle(color: c.muted)),
            const SizedBox(height: 10),
            PctBadge(crop.healthScore, suffix: " sog'lom", fontSize: 15),
            if (crop.area != null || crop.plantingDate != null || crop.location != null) ...[
              const SizedBox(height: 12),
              Text(
                [
                  if (crop.area != null) '${crop.area} sotix',
                  if (crop.plantingDate != null) 'Ekilgan: ${formatDate(crop.plantingDate)}',
                  if (crop.location != null) crop.location!,
                ].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
            ],
          ]),
        ),
      ),
      health.maybeWhen(
        data: (points) => points.length < 2
            ? const SizedBox.shrink()
            : AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Sog'liq tarixi", style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  SizedBox(height: 90, child: _Sparkline(points: points)),
                ]),
              ),
        orElse: () => const SizedBox.shrink(),
      ),
      if (last != null && !last.isHealthy && last.diseaseName != null)
        AppCard(
          onTap: () => context.push('/diagnosis/${last.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Oxirgi aniqlangan kasallik', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${last.diseaseName} · ${last.confidence.toStringAsFixed(0)}% · ${timeAgo(last.diagnosedAt)}', style: TextStyle(color: c.muted)),
            if (last.medicines.isNotEmpty)
              InfoBox(label: 'Tavsiya etilgan dori', value: '${last.medicines.first.name}${last.medicines.first.recommendation != null ? ', ${last.medicines.first.recommendation}' : ''}'),
          ]),
        ),
      reminders.maybeWhen(
        data: (all) {
          final mine = all.where((r) => r.cropId == crop.id).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle('Vazifalar (${mine.length})', action: "+ Qo'shish", onAction: () => context.push('/reminders/add?crop=${crop.id}')),
            if (mine.isEmpty) const EmptyNote("Bu ekin uchun eslatma yo'q"),
            for (final r in mine)
              ListRow(
                icon: AppIcons.forReminder(r.type),
                label: r.title,
                chevron: false,
                value: r.isCompleted ? 'Bajarildi' : formatDate(r.date),
                onTap: () async {
                  await ref.read(gardenRepoProvider).toggleReminder(r.id);
                  ref.invalidate(remindersProvider);
                  ref.invalidate(cropProvider(crop.id));
                },
              ),
          ]);
        },
        orElse: () => const SizedBox.shrink(),
      ),
      SectionTitle('Ekin kundaligi', action: "+ Yozuv", onAction: () => _addLog(context, ref)),
      logs.maybeWhen(
        data: (list) => list.isEmpty
            ? const EmptyNote("Hali yozuv yo'q")
            : Column(children: [
                for (final l in list.take(10))
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.content, style: const TextStyle(fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(timeAgo(l.createdAt), style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ]),
                  ),
              ]),
        orElse: () => const SizedBox.shrink(),
      ),
      if ((diags.value?.length ?? 0) > 1) ...[
        const SectionTitle('Tashxislar tarixi'),
        for (final d in diags.value!)
          RowCard(
            leading: ThumbIcon(icon: AppIcons.image, imageUrl: d.imageUrl, size: 46),
            title: d.title,
            subtitle: '${d.confidence.toStringAsFixed(0)}% · ${timeAgo(d.diagnosedAt)}',
            trailing: Icon(AppIcons.chevron, color: c.muted),
            onTap: () => context.push('/diagnosis/${d.id}'),
          ),
      ],
      const SizedBox(height: 10),
      PillButton(label: 'Qayta tashxis qilish', icon: AppIcons.camera, block: true, onPressed: () => context.push('/diagnose?crop=${crop.id}')),
      const SizedBox(height: 10),
      PillButton(label: "Ekinni o'chirish", icon: AppIcons.trash, style: PillStyle.outline, fg: c.danger, block: true, onPressed: () => _delete(context, ref)),
    ]);
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points});
  final List<HealthPoint> points;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SparkPainter(points, context.c), size: Size.infinite);
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.c);
  final List<HealthPoint> points;
  final AppColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = c.border..strokeWidth = 1;
    for (final y in [0.0, 0.5, 1.0]) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), grid);
    }
    final dx = size.width / (points.length - 1);
    Offset at(int i) => Offset(i * dx, size.height * (1 - points[i].score / 100));
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(path, Paint()..color = c.primary..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(at(i), 4, Paint()..color = c.health(points[i].score));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.points != points;
}
