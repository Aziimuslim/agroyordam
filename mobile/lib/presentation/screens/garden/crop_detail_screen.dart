import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../reminders/today_tasks.dart';
import 'add_crop_screen.dart';
import 'crop_photo.dart';

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
    if (!await confirm(context, tr("Ekinni o'chirish"), trf("{0} va uning tarixi o'chiriladi.", [crop.name]), ok: tr("O'chirish"), danger: true)) return;
    try {
      await ref.read(gardenRepoProvider).deleteCrop(crop.id);
      ref.invalidate(cropsProvider);
      if (context.mounted) {
        showToast(context, tr("Ekin o'chirildi"));
        context.go('/garden');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _addLog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final text = await showSheet<String>(context, title: tr('Kundalikka yozuv'), builder: (ctx) => Column(children: [
          TextField(controller: ctrl, maxLines: 4, autofocus: true, decoration: InputDecoration(hintText: tr("Bugun nima qildingiz? (sug'orish, o'g'itlash...)"))),
          const SizedBox(height: 14),
          PillButton(label: tr('Saqlash'), block: true, onPressed: () => Navigator.pop(ctx, ctrl.text.trim())),
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
        CircleIconButton(icon: AppIcons.edit, tooltip: tr('Tahrirlash'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddCropScreen(crop: crop)))),
      ]),
      // Figma "Yashil dala": surat-banner, ustida nom va sog'liq; pastida ma'lumot chiplari
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        child: SizedBox(
          height: 200,
          child: Stack(fit: StackFit.expand, children: [
            CropPhoto(crop: crop, iconSize: 64),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB3000000)]),
              ),
            ),
            Positioned(top: 12, right: 12, child: PctBadge(crop.healthScore, suffix: tr(" sog'lom"), fontSize: 13)),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(crop.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                if (crop.plantName != null || crop.variety != null)
                  Text([crop.plantName, crop.variety].whereType<String>().join(' · '),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (crop.area != null || crop.plantingDate != null || crop.location != null)
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (crop.area != null) Tag(trf('{0} sotix', [crop.area]), bg: c.cream2, fg: c.text),
          if (crop.plantingDate != null) Tag(trf('Ekilgan: {0}', [formatDate(crop.plantingDate)]), bg: c.cream2, fg: c.text),
          if (crop.location != null) Tag(crop.location!, bg: c.cream2, fg: c.text),
        ]),
      const SizedBox(height: 14),
      health.maybeWhen(
        data: (points) => points.length < 2
            ? const SizedBox.shrink()
            : AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Sog'liq tarixi"), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
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
            Text(tr('Oxirgi aniqlangan kasallik'), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${last.diseaseName} · ${last.confidence.toStringAsFixed(0)}% · ${timeAgo(last.diagnosedAt)}', style: TextStyle(color: c.muted)),
            if (last.medicines.isNotEmpty)
              InfoBox(label: tr('Tavsiya etilgan dori'), value: '${last.medicines.first.name}${last.medicines.first.recommendation != null ? ', ${last.medicines.first.recommendation}' : ''}'),
            Align(
              alignment: Alignment.centerLeft,
              child: MiniButton(label: tr('Parvarish rejasi'), icon: AppIcons.bell, filled: true, onTap: () => context.push('/diagnosis/${last.id}/plan')),
            ),
          ]),
        ),
      reminders.maybeWhen(
        data: (all) {
          final mine = all.where((r) => r.cropId == crop.id).toList();
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final done = mine.where((r) => r.isCompleted).length;
          final upcoming = mine.where((r) => !r.isCompleted && r.date.isAfter(today)).toList()..sort((a, b) => a.date.compareTo(b.date));
          final planDays = mine.isEmpty ? 0 : mine.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b).difference(today).inDays;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(tr('Vazifalar'), action: tr("+ Qo'shish"), onAction: () => context.push('/reminders/add?crop=${crop.id}')),
            if (mine.isEmpty)
              EmptyNote(tr("Bu ekin uchun vazifa yo'q. Tashxisdan keyin \"Parvarish rejasi\"ni boshlang."))
            else ...[
              AppCard(
                color: c.cream2,
                shadow: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(trf('Bajarildi: {0} / {1}', [done, mine.length]), style: const TextStyle(fontWeight: FontWeight.w800))),
                    if (planDays > 0) Text(trf('yana {0} kun', [planDays]), style: TextStyle(color: c.muted, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: done / mine.length, minHeight: 8, backgroundColor: c.border, color: c.success),
                  ),
                ]),
              ),
              Text(tr('Bugun'), style: TextStyle(fontWeight: FontWeight.w800, color: c.primaryDark)),
              const SizedBox(height: 8),
              TodayTasks(cropId: crop.id, limit: 6),
              if (upcoming.isNotEmpty) ...[
                Text(tr('Keyingi vazifalar'), style: TextStyle(fontWeight: FontWeight.w800, color: c.primaryDark)),
                const SizedBox(height: 8),
                for (final r in upcoming.take(3))
                  ListRow(icon: AppIcons.forReminder(r.type), label: r.title, chevron: false, value: formatDate(r.date)),
              ],
              Center(
                child: TextButton(
                  onPressed: () => context.push('/reminders?crop=${crop.id}'),
                  child: Text(trf('Barcha vazifalar ({0})', [mine.length]), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ]);
        },
        orElse: () => const SizedBox.shrink(),
      ),
      SectionTitle(tr('Ekin kundaligi'), action: tr("+ Yozuv"), onAction: () => _addLog(context, ref)),
      logs.maybeWhen(
        data: (list) => list.isEmpty
            ? EmptyNote(tr("Hali yozuv yo'q"))
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
        SectionTitle(tr('Tashxislar tarixi')),
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
      PillButton(label: tr('Qayta tashxis qilish'), icon: AppIcons.camera, block: true, onPressed: () => context.push('/diagnose?crop=${crop.id}')),
      const SizedBox(height: 10),
      PillButton(label: tr("Ekinni o'chirish"), icon: AppIcons.trash, style: PillStyle.outline, fg: c.danger, block: true, onPressed: () => _delete(context, ref)),
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
