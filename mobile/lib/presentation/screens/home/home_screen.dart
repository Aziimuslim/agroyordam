import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../garden/crop_photo.dart';
import '../reminders/today_tasks.dart';

/// Bosh sahifa — Figma "B · Yashil dala / Bosh sahifa" maketi asosida:
/// salomlashuv → ob-havo va kasallik xavfi → AI tashxis kartasi → bugungi vazifalar → mening bog'im → bo'limlar.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    final crops = ref.watch(cropsProvider);
    final notes = ref.watch(notificationsProvider);
    final unread = notes.value?.where((n) => !n.isRead).length ?? 0;
    final weather = ref.watch(weatherProvider).value;
    final firstName = (user?.fullName ?? '').trim().split(RegExp(r'\s+')).first;

    return PageShell(
      bottom: const AppBottomNav(current: '/home'),
      onRefresh: () async {
        ref.invalidate(cropsProvider);
        ref.invalidate(notificationsProvider);
        ref.invalidate(remindersProvider);
        ref.invalidate(weatherProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Avatar(name: user?.fullName ?? '?', url: user?.avatarUrl, size: 46, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(firstName.isEmpty ? greeting() : '${greetingShort()}, $firstName',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              Text(formatDayLong(), style: TextStyle(color: c.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          CircleIconButton(icon: AppIcons.bell, badge: unread > 0, tooltip: 'Bildirishnomalar', onTap: () => context.push('/notifications')),
        ]),
        const SizedBox(height: 20),
        if (weather != null) _WeatherCard(w: weather),
        _HeroCard(
          onCamera: () => context.push('/diagnose?source=camera'),
          onGallery: () => context.push('/diagnose?source=gallery'),
        ),
        _TasksSection(),
        SectionTitle("Mening bog'im", action: 'Barchasi', onAction: () => context.go('/garden')),
        AsyncView(
          value: crops,
          onRetry: () => ref.invalidate(cropsProvider),
          data: (list) => list.isEmpty ? const _EmptyGarden() : _CropStrip(crops: list),
        ),
        const SizedBox(height: 8),
        const SectionTitle("Bo'limlar"),
        Row(children: [
          _Shortcut(icon: AppIcons.book, label: 'Ensiklopediya', onTap: () => context.push('/catalog')),
          const SizedBox(width: 10),
          _Shortcut(icon: AppIcons.bot, label: 'AI yordamchi', onTap: () => context.push('/assistant')),
          const SizedBox(width: 10),
          _Shortcut(icon: AppIcons.history, label: 'Tashxislar', onTap: () => context.push('/diagnoses')),
        ]),
      ]),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.w});
  final Weather w;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, bg, fg) = switch (w.risk) {
      'high' => ('Yuqori xavf', c.dangerBg, c.danger),
      'medium' => ("O'rta xavf", c.warningBg, c.warning),
      _ => ('Past xavf', c.successBg, c.success),
    };
    final rainy = w.condition.contains("yomg'ir") || w.condition.contains('momaqaldiroq');
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: rainy ? c.infoBg : c.accentSoft, shape: BoxShape.circle),
          child: Icon(rainy ? AppIcons.rain : AppIcons.sun, color: rainy ? c.info : c.warning, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w.city} · ${w.temperature.round()}°, ${w.condition}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Namlik ${w.humidity}%${w.rainMm > 0 ? ' · yog\'in ${w.rainMm.toStringAsFixed(1)} mm' : ''} — ${switch (w.risk) { 'high' => "zamburug' kasalliklari xavfi yuqori", 'medium' => "zamburug' xavfi o'rtacha", _ => "kasallik xavfi past" }}',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.35, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 8),
        Tag(label, bg: bg, fg: fg),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera, onGallery;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const deep = Color(0xFF0F3D27), mid = Color(0xFF2E8B57); // Figma hero gradient (ikkala mavzuda bir xil)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [deep, mid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -18, top: 6, child: Icon(AppIcons.scan, size: 170, color: Colors.white.withValues(alpha: 0.10))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tag('AI · 97% aniqlik', bg: c.gold, fg: c.onGold),
            const SizedBox(height: 12),
            const Text("Ekiningiz sog'lig'ini tekshiring",
                style: TextStyle(color: Colors.white, fontSize: 23, height: 28 / 23, fontWeight: FontWeight.w800, letterSpacing: -0.35)),
            const SizedBox(height: 8),
            Text("Barg rasmini oling — AI bir necha soniyada tashxis qo'yib, davolash rejasini tuzadi",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            Row(children: [
              Material(
                color: c.gold,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onCamera,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 13, 20, 13),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.camera, size: 19, color: c.onGold),
                      const SizedBox(width: 8),
                      Text('Rasmga olish', style: TextStyle(color: c.onGold, fontSize: 15, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Galereyadan tanlash',
                child: Material(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onGallery,
                    child: const SizedBox(width: 46, height: 46, child: Icon(AppIcons.gallery, color: Colors.white, size: 20)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TasksSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final all = ref.watch(remindersProvider).value ?? const <Reminder>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todays = all.where((r) => r.date == today).toList();
    final done = todays.where((r) => r.isCompleted).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Row(children: [
          const Text('Bugungi vazifalar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
          const SizedBox(width: 8),
          if (todays.isNotEmpty) Tag('$done / ${todays.length}', bg: c.primaryLight, fg: c.primaryDark),
          const Spacer(),
          InkWell(
            onTap: () => context.push('/reminders'),
            child: Text('Barchasi', style: TextStyle(fontSize: 14, color: c.primary, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const TodayTasks(),
      const SizedBox(height: 8),
    ]);
  }
}

class _CropStrip extends StatelessWidget {
  const _CropStrip({required this.crops});
  final List<Crop> crops;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: crops.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => i == crops.length ? const _AddCropTile() : _CropCard(crop: crops[i]),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = crop.healthScore;
    final status = pct >= 70 ? "Sog'lom" : (pct >= 45 ? 'Kuzatuvda' : 'Davolanmoqda');
    return SizedBox(
      width: 168,
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/garden/${crop.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(height: 104, width: double.infinity, child: CropPhoto(crop: crop)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text([crop.plantName, crop.location].whereType<String>().join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Tag('$pct% · $status', bg: c.healthBg(pct), fg: c.health(pct)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AddCropTile extends StatelessWidget {
  const _AddCropTile();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/garden/add'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.border, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.primaryLight, shape: BoxShape.circle),
                child: Icon(AppIcons.plus, color: c.primary),
              ),
              const SizedBox(height: 8),
              Text("Ekin qo'shish", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: () => context.push('/garden/add'),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(AppIcons.leaf, color: c.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Birinchi ekiningizni qo'shing", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text("Sog'lig'ini kuzatib, eslatmalar olasiz", style: TextStyle(color: c.muted, fontSize: 12.5)),
          ]),
        ),
        Icon(AppIcons.plus, color: c.primary),
      ]),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          onTap: onTap,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.c.primaryLight, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: context.c.primary, size: 21),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}
