import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/crop_status.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../garden/crop_photo.dart';
import '../reminders/task_sheet.dart';
import '../reminders/today_tasks.dart' show dueTasks;
import 'landscape_header.dart';
import 'weather_screen.dart' show hhmm, weatherIcon;

/// S01 Bosh sahifa (Tabiiy Agro): bog' manzarasi va ob-havo effekti → "Ekinni tekshirish" →
/// bugungi vazifalar → bog'imdagi ekinlar → Ma'lumotnoma. Har blok o'z yuklanish/xato holatiga ega.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= Breakpoints.desktop;
    final side = width >= Breakpoints.tablet ? 32.0 : 16.0;

    Widget constrained(Widget child) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(padding: EdgeInsets.symmetric(horizontal: side), child: child),
          ),
        );

    final tasks = const _TasksBlock();
    final crops = const _CropsBlock();
    return Scaffold(
      backgroundColor: c.cream,
      bottomNavigationBar: desktop ? null : const AppBottomNav(current: '/home'),
      body: NavFrame(
        current: '/home',
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: () async {
            ref.invalidate(cropsProvider);
            ref.invalidate(notificationsProvider);
            ref.invalidate(remindersProvider);
            ref.invalidate(weatherProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Header(constrained: constrained),
              constrained(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _CheckButton(),
                const SizedBox(height: 24),
                if (width >= Breakpoints.desktop)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: tasks),
                    const SizedBox(width: 32),
                    Expanded(flex: 7, child: crops),
                  ])
                else ...[
                  tasks,
                  const SizedBox(height: 24),
                  crops,
                ],
                const SizedBox(height: 24),
                const _CatalogLink(),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Header: manzara + salomlashuv + ob-havo ----------------
class _Header extends ConsumerWidget {
  const _Header({required this.constrained});
  final Widget Function(Widget) constrained;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final user = ref.watch(currentUserProvider);
    final weather = ref.watch(weatherProvider);
    final unread = ref.watch(notificationsProvider).value?.where((n) => !n.isRead).length ?? 0;
    final firstName = (user?.fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final topPad = MediaQuery.paddingOf(context).top;
    final desktop = Breakpoints.isDesktop(context);
    final landscapeH = desktop ? 190.0 : 150.0;

    return SizedBox(
      // matn qismi + ko'rinadigan manzara
      height: topPad + 196 + landscapeH,
      child: Stack(fit: StackFit.expand, children: [
        LandscapeBackdrop(weather: weather.value),
        // Matn ostida krem/qorong'i gradient: kontrast manzara va animatsiyaga bog'liq emas
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.cream, c.cream, c.cream.withValues(alpha: 0.85), c.cream.withValues(alpha: 0)],
              stops: [0, (topPad + 150) / (topPad + 196 + landscapeH), (topPad + 190) / (topPad + 196 + landscapeH), (topPad + 250) / (topPad + 196 + landscapeH)],
            ),
          ),
        ),
        // Pastki egilgan qirra — kontent "varag'i" manzara ustiga chiqadi
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: 25,
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.cream, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: topPad),
          child: constrained(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 60,
              child: Row(children: [
                if (!desktop) ...[
                  const BrandLogo(size: 32),
                  const SizedBox(width: 8),
                  Text('AgroYordam', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.2)),
                ],
                const Spacer(),
                _HeaderIcon(
                  tooltip: unread > 0 ? trf('Bildirishnomalar: {0} ta yangi', [unread]) : tr('Bildirishnomalar'),
                  onTap: () => context.push('/notifications'),
                  child: Badge(
                    isLabelVisible: unread > 0,
                    backgroundColor: c.primary,
                    smallSize: 9,
                    child: Icon(Icons.notifications_none_rounded, color: c.text, size: 26),
                  ),
                ),
                const SizedBox(width: 4),
                _HeaderIcon(
                  tooltip: tr('Profil'),
                  onTap: () => context.go('/profile'),
                  child: Avatar(name: user?.fullName ?? '?', url: user?.avatarUrl, size: 36, color: c.olive, textColor: c.onOlive),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(firstName.isEmpty ? tr('Salom!') : trf('Salom, {0}!', [firstName]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.4)),
                  ),
                  const SizedBox(height: 6),
                  Text(tr("Bugun ham bog'ingizda unumli kun bo'lsin!"),
                      maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, height: 1.35, color: c.muted)),
                ]),
              ),
              const SizedBox(width: 12),
              _WeatherChip(value: weather, onRetry: () => ref.invalidate(weatherProvider)),
            ]),
          ])),
        ),
      ]),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.child, required this.onTap, required this.tooltip});
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          excludeSemantics: true,
          child: InkResponse(
            onTap: onTap,
            radius: 24,
            child: SizedBox(width: 44, height: 44, child: Center(child: child)),
          ),
        ),
      );
}

/// Ob-havo kartasi (header o'ng tomoni) → A06. Holatlar: yuklanmoqda, yangi, eskirgan (> 2 soat),
/// oflayn (oxirgi ma'lumot), mavjud emas + qayta urinish.
class _WeatherChip extends StatelessWidget {
  const _WeatherChip({required this.value, required this.onRetry});
  final AsyncValue<Weather> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = value.value;
    final box = BoxDecoration(
      color: c.card.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: c.border),
    );
    Widget shell(Widget child, {String? label}) => Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/weather'),
              child: Container(
                constraints: const BoxConstraints(minWidth: 128, maxWidth: 172, minHeight: 96),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: box,
                child: child,
              ),
            ),
          ),
        );

    if (w == null && value.isLoading) {
      return Container(width: 140, height: 104, decoration: box, child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))));
    }
    if (w == null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 172),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: box,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: c.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(tr('Ob-havo hozir mavjud emas'), style: TextStyle(fontSize: 14, height: 1.3, color: c.text, fontWeight: FontWeight.w600))),
          ]),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4), foregroundColor: c.primaryDark),
            onPressed: onRetry,
            child: Text(tr('Qayta urinish'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ]),
      );
    }
    final offline = value.hasError;
    final stale = !offline && w.isStale;
    final time = w.updatedAt != null ? hhmm(w.updatedAt!) : null;
    final note = offline
        ? (time != null ? trf('Oflayn · {0}', [time]) : tr('Oflayn'))
        : stale
            ? trf('Eskirgan · {0}', [time!])
            : (time != null ? trf('{0} da yangilandi', [time]) : null);
    return shell(
      label: [w.city, '${w.temperature.round()}°', tr(w.condition), if (note != null) note].join(', '),
      ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(w.city, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(weatherIcon(w), size: 26, color: w.isDay ? c.warning : c.text),
            const SizedBox(width: 6),
            Text('${w.temperature.round()}°', style: TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w800, color: c.text)),
          ]),
          Text(tr(w.condition), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted)),
          if (note != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (offline || stale) ...[Icon(offline ? Icons.cloud_off_rounded : Icons.schedule_rounded, size: 14, color: c.warning), const SizedBox(width: 4)],
              Flexible(
                child: Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: offline || stale ? c.warning : c.muted)),
              ),
            ]),
        ]),
      ),
    );
  }
}

// ---------------- "Ekinni tekshirish" ----------------
class _CheckButton extends StatelessWidget {
  const _CheckButton();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: tr('Ekinni tekshirish'),
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/diagnose'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(AppIcons.scan, color: c.onPrimary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('Ekinni tekshirish'), style: TextStyle(color: c.onPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text(tr("Barg suratini oling — AI mumkin bo'lgan sabablarni ko'rsatadi"),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onPrimary, fontSize: 14, height: 1.3)),
                  ]),
                ),
                Icon(AppIcons.chevron, color: c.onPrimary, size: 28),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Blok sarlavhasi ----------------
class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.title, {this.trailing, this.action, this.onAction});
  final String title;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
            Semantics(header: true, child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text))),
            if (trailing != null) trailing!,
          ]),
        ),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: onAction,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Icon(AppIcons.chevron, size: 20),
            ]),
          ),
      ]),
    );
  }
}

class _BlockError extends StatelessWidget {
  const _BlockError({required this.error, required this.onRetry, required this.what});
  final Object error;
  final VoidCallback onRetry;
  final String what;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, color: c.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf("{0} yuklanmadi", [what]), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
            Text(ApiException.from(error).message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 14)),
          ]),
        ),
        TextButton(onPressed: onRetry, child: Text(tr('Qayta urinish'))),
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: context.c.cream2, borderRadius: BorderRadius.circular(16)),
      );
}

// ---------------- Bugungi vazifalar ----------------
class _TasksBlock extends ConsumerWidget {
  const _TasksBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final value = ref.watch(remindersProvider);
    final all = value.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = all == null ? const <Reminder>[] : [...dueTasks(all), ...all.where((r) => r.isCompleted && r.date == today)];
    final todays = all?.where((r) => r.date == today).toList() ?? const <Reminder>[];
    final done = todays.where((r) => r.isCompleted).length;
    const limit = 4;

    Widget body;
    if (all == null && value.hasError) {
      body = _BlockError(error: value.error!, onRetry: () => ref.invalidate(remindersProvider), what: tr('Vazifalar'));
    } else if (all == null) {
      body = const Column(children: [_Skeleton(height: 64), SizedBox(height: 8), _Skeleton(height: 64)]);
    } else if (rows.isEmpty) {
      body = AppCard(
        margin: EdgeInsets.zero,
        child: Row(children: [
          Icon(Icons.task_alt_rounded, color: c.success),
          const SizedBox(width: 12),
          Expanded(child: Text(tr("Bugun bajariladigan vazifa yo'q"), style: TextStyle(color: c.text, fontSize: 16))),
          TextButton(onPressed: () => context.push('/reminders/add'), child: Text(tr("Qo'shish"))),
        ]),
      );
    } else {
      final shown = rows.take(limit).toList();
      body = Column(children: [
        for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 8), child: _TaskRow(r: r)),
        if (rows.length > limit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push('/reminders'),
              child: Text(trf('yana {0} ta vazifa', [rows.length - limit])),
            ),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _BlockTitle(
        tr('Bugungi vazifalar'),
        trailing: todays.isEmpty
            ? null
            : Semantics(
                label: trf('{0} tadan {1} tasi bajarildi', [todays.length, done]),
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text('$done/${todays.length}', style: TextStyle(color: c.onOliveSoft, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
        action: tr("Barchasini ko'rish"),
        onAction: () => context.push('/reminders'),
      ),
      body,
    ]);
  }
}

class _TaskRow extends ConsumerStatefulWidget {
  const _TaskRow({required this.r});
  final Reminder r;
  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = widget.r;
    final now = DateTime.now();
    final overdue = !r.isCompleted && r.date.isBefore(DateTime(now.year, now.month, now.day));
    final time = overdue ? tr("Kechikkan") : (r.time != null ? r.time!.substring(0, 5) : tr('Bugun'));
    final meta = [if (r.cropName != null) r.cropName!, if (overdue) shortDate(r.date)].join(' · ');
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTaskSheet(context, r),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(children: [
            // Checkbox — alohida 48 px bosish maydoni; holat server tasdig'idan keyin
            Semantics(
              checked: r.isCompleted,
              button: true,
              label: r.isCompleted ? trf('{0}: bajarilgan. Qaytarish', [r.title]) : trf('{0}: bajarildi deb belgilash', [r.title]),
              excludeSemantics: true,
              child: InkResponse(
                radius: 24,
                onTap: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await toggleTask(context, ref, r);
                        if (mounted) setState(() => _busy = false);
                      },
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: r.isCompleted ? c.olive : Colors.transparent,
                              shape: BoxShape.circle,
                              border: r.isCompleted ? null : Border.all(color: overdue ? c.danger : c.lineStrong, width: 2),
                            ),
                            child: r.isCompleted ? Icon(AppIcons.check, size: 17, color: c.onOlive) : null,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(time,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: overdue ? c.danger : c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: r.isCompleted ? c.muted : c.text,
                        decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                      )),
                  if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: overdue ? c.danger : c.muted)),
                ]),
              ),
            ),
            Icon(AppIcons.chevron, color: c.muted),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Bog'imdagi ekinlar ----------------
class _CropsBlock extends ConsumerWidget {
  const _CropsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(cropsProvider);
    final list = value.value;
    Widget body;
    if (list == null && value.hasError) {
      body = _BlockError(error: value.error!, onRetry: () => ref.invalidate(cropsProvider), what: tr('Ekinlar'));
    } else if (list == null) {
      body = const Row(children: [Expanded(child: _Skeleton(height: 220)), SizedBox(width: 12), Expanded(child: _Skeleton(height: 220))]);
    } else if (list.isEmpty) {
      body = const _EmptyGarden();
    } else {
      final sorted = [...list]..sort((a, b) => cropStateRank(cropState(a)).compareTo(cropStateRank(cropState(b))));
      body = LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 840 ? 4 : (box.maxWidth >= 520 ? 3 : 2);
        final shown = sorted.take(cols * 2).toList();
        const gap = 12.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in shown) SizedBox(width: w, child: _CropCard(crop: c))]);
      });
    }
    final attention = list?.where((c) => cropState(c) == CropState.attention).length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _BlockTitle(
        attention > 0 ? tr("Bog'imda e'tibor kerak") : tr("Bog'imdagi ekinlar"),
        action: tr("Barchasini ko'rish"),
        onAction: () => context.go('/garden'),
      ),
      body,
    ]);
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop});
  final Crop crop;

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
    return Semantics(
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
                  Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
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
  }
}

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.eco_outlined, color: c.onOliveSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr("Bog'ingiz hali bo'sh"), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
              Text(tr("Ekin qo'shsangiz, vazifalar va kuzatuvlar shu yerda ko'rinadi"), style: TextStyle(color: c.muted, fontSize: 14)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.primaryDark,
              side: BorderSide(color: c.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.push('/garden/add'),
            icon: const Icon(AppIcons.plus),
            label: Text(tr('Birinchi ekinni qo\'shing'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}

// ---------------- Ma'lumotnoma havolasi (S17) ----------------
class _CatalogLink extends StatelessWidget {
  const _CatalogLink();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: tr("Ma'lumotnoma: o'simliklar, kasalliklar va dorilar"),
      excludeSemantics: true,
      child: Material(
        color: c.cream2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/catalog?tab=plants'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(AppIcons.book, color: c.olive, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr("Ma'lumotnoma"), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                  Text(tr("O'simliklar, kasalliklar va dorilar haqida"), style: TextStyle(fontSize: 14, color: c.muted)),
                ]),
              ),
              Icon(AppIcons.chevron, color: c.muted),
            ]),
          ),
        ),
      ),
    );
  }
}
