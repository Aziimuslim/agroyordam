import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'landscape_header.dart';

String hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

IconData weatherIcon(Weather w) => codeIcon(w.code, isDay: w.isDay);

IconData codeIcon(int code, {bool isDay = true}) => switch (sceneFor(code)) {
      SkyScene.rain => Icons.water_drop_outlined,
      SkyScene.snow => Icons.ac_unit_rounded,
      SkyScene.fog => Icons.foggy,
      SkyScene.clouds => isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined,
      SkyScene.clear => isDay ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
    };

/// A06 Hudud va ob-havo: joriy ob-havo, kasallik xavfi, manba va yangilanish vaqti; hudud tanlash
/// (profilga saqlanadi — aniq GPS koordinata olinmaydi). Soatlik (24 soat) va kunlik (7 kun) prognoz — Open-Meteo.
class WeatherScreen extends ConsumerStatefulWidget {
  const WeatherScreen({super.key});
  @override
  ConsumerState<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherScreen> {
  final _q = TextEditingController();
  String? _saving;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _pick(String region) async {
    setState(() => _saving = region);
    try {
      await ref.read(authProvider.notifier).updateProfile({'region': region});
      // weatherProvider foydalanuvchi hududini kuzatadi — o'zi qayta yuklanadi
      if (mounted) showToast(context, trf('Hudud saqlandi: {0}', [tr(region)]));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final weather = ref.watch(weatherProvider);
    final current = ref.watch(currentUserProvider)?.region;
    final q = _q.text.trim().toLowerCase();
    final regions = uzRegions.keys.where((r) => q.isEmpty || r.toLowerCase().contains(q) || tr(r).toLowerCase().contains(q)).toList();
    return PageShell(
      maxWidth: 720,
      padBottom: false,
      onRefresh: () async => ref.invalidate(weatherProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: tr('Hudud va ob-havo')),
        _Current(value: weather, onRetry: () => ref.invalidate(weatherProvider)),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text(tr('Hudud'), style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 4),
        Text(tr("Ob-havo va kasallik xavfi shu hudud bo'yicha hisoblanadi. Aniq joylashuvingiz olinmaydi."),
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.4)),
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Hududni qidirish')),
        ),
        const SizedBox(height: 8),
        if (regions.isEmpty) EmptyNote(tr('Hudud topilmadi'), icon: Icons.search_off_rounded),
        for (final r in regions)
          Semantics(
            selected: r == current,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _saving != null || r == current ? null : () => _pick(r),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Row(children: [
                  Icon(Icons.place_outlined, color: r == current ? c.olive : c.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(tr(r),
                        style: TextStyle(fontSize: 16, fontWeight: r == current ? FontWeight.w800 : FontWeight.w500, color: c.text)),
                  ),
                  if (_saving == r)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (r == current)
                    Icon(AppIcons.check, color: c.olive),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.value, required this.onRetry});
  final AsyncValue<Weather> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = value.value;
    if (w == null) {
      if (value.isLoading) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.cloud_off_rounded, color: c.muted),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('Ob-havo hozir mavjud emas'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          if (value.hasError) ...[
            const SizedBox(height: 6),
            Text(ApiException.from(value.error!).message, style: TextStyle(color: c.muted, fontSize: 14)),
          ],
          const SizedBox(height: 12),
          PillButton(label: tr('Qayta urinish'), style: PillStyle.soft, onPressed: onRetry),
        ]),
      );
    }
    final offline = value.hasError;
    final (riskLabel, riskBg, riskFg) = switch (w.risk) {
      'high' => (tr('Yuqori xavf'), c.dangerBg, c.danger),
      'medium' => (tr("O'rta xavf"), c.warningBg, c.warning),
      _ => (tr('Past xavf'), c.successBg, c.success),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 180,
          child: Stack(fit: StackFit.expand, children: [
            LandscapeBackdrop(weather: w),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                decoration: BoxDecoration(color: c.card.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(weatherIcon(w), color: c.text, size: 30),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${w.temperature.round()}°', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.text, height: 1.1)),
                    Text('${w.city} · ${tr(w.condition)}', style: TextStyle(fontSize: 14, color: c.muted, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (offline || w.isStale)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Icon(offline ? Icons.cloud_off_rounded : Icons.schedule_rounded, size: 18, color: c.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(offline ? tr("Tarmoq yo'q — oxirgi saqlangan ma'lumot ko'rsatilmoqda") : tr("Ma'lumot 2 soatdan eski bo'lishi mumkin"),
                  style: TextStyle(color: c.warning, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (offline) TextButton(onPressed: onRetry, child: Text(tr('Qayta urinish'))),
          ]),
        ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Fact(Icons.water_drop_outlined, tr('Namlik'), '${w.humidity}%'),
          _Fact(Icons.umbrella_outlined, tr("Yog'in (48 soat)"), '${w.rainMm.toStringAsFixed(1)} mm'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(Icons.coronavirus_outlined, size: 20, color: c.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(tr("Zamburug' kasalliklari xavfi"), style: TextStyle(color: c.muted, fontSize: 14))),
              Tag(riskLabel, bg: riskBg, fg: riskFg),
            ]),
          ),
          if (w.riskText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr(w.riskText), style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
            ),
        ]),
      ),
      Text(
        [
          trf('Manba: {0}', ['Open-Meteo']),
          if (w.updatedAt != null) trf('{0} da yangilandi', [hhmm(w.updatedAt!)]),
        ].join(' · '),
        style: TextStyle(color: c.muted, fontSize: 14),
      ),
      if (w.hourly.isNotEmpty) ...[
        const SizedBox(height: 20),
        Semantics(header: true, child: Text(tr('Keyingi 24 soat'), style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: w.hourly.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final h = w.hourly[i];
              final label = i == 0 ? tr('Hozir') : '${h.time.hour.toString().padLeft(2, '0')}:00';
              return Semantics(
                label: [label, '${h.temperature.round()}°', if ((h.rainProbability ?? 0) > 0) trf("yog'in ehtimoli {0}%", [h.rainProbability])].join(', '),
                excludeSemantics: true,
                child: Container(
                  width: 66,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == 0 ? c.oliveSoft : c.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i == 0 ? c.olive : c.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == 0 ? c.onOliveSoft : c.muted)),
                    Icon(codeIcon(h.code, isDay: h.isDay), color: c.text, size: 22),
                    Text('${h.temperature.round()}°', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                    Text((h.rainProbability ?? 0) > 0 ? '${h.rainProbability}%' : ' ', style: TextStyle(fontSize: 12.5, color: c.primaryDark, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
      if (w.daily.isNotEmpty) ...[
        const SizedBox(height: 20),
        Semantics(header: true, child: Text(tr('7 kunlik prognoz'), style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Column(children: [
            for (var i = 0; i < w.daily.length; i++)
              _DayRow(d: w.daily[i], first: i == 0, last: i == w.daily.length - 1, minAll: w.daily.map((e) => e.tMin).reduce((a, b) => a < b ? a : b), maxAll: w.daily.map((e) => e.tMax).reduce((a, b) => a > b ? a : b)),
          ]),
        ),
        const SizedBox(height: 8),
        Text(tr("Prognoz — taxmin. Purkash va sug'orishni rejalashtirishda yaqin kunlarga ko'proq tayaning."), style: TextStyle(color: c.muted, fontSize: 14)),
      ],
    ]);
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.d, required this.first, required this.last, required this.minAll, required this.maxAll});
  final DayForecast d;
  final bool first, last;
  final double minAll, maxAll;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = first ? tr('Bugun') : weekdayName(d.date);
    final span = (maxAll - minAll).abs() < 1 ? 1.0 : maxAll - minAll;
    return Semantics(
      label: [name, tr(d.condition), trf('eng yuqori {0}°, eng past {1}°', [d.tMax.round(), d.tMin.round()]), if ((d.rainProbability ?? 0) > 0) trf("yog'in ehtimoli {0}%", [d.rainProbability])].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
        child: Row(children: [
          SizedBox(width: 92, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: first ? FontWeight.w800 : FontWeight.w600, color: c.text))),
          Icon(codeIcon(d.code), size: 22, color: c.text),
          SizedBox(
            width: 44,
            child: Text((d.rainProbability ?? 0) > 0 ? '${d.rainProbability}%' : '', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: c.primaryDark, fontWeight: FontWeight.w700)),
          ),
          Text('${d.tMin.round()}°', style: TextStyle(fontSize: 15, color: c.muted)),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (_, box) {
              final left = (d.tMin - minAll) / span * box.maxWidth;
              final width = ((d.tMax - d.tMin) / span * box.maxWidth).clamp(6.0, box.maxWidth);
              return SizedBox(
                height: 6,
                child: Stack(children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(3)))),
                  Positioned(
                    left: left.clamp(0.0, box.maxWidth - width),
                    top: 0,
                    bottom: 0,
                    child: Container(width: width, decoration: BoxDecoration(color: c.olive, borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text('${d.tMax.round()}°', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: c.muted),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(color: c.muted, fontSize: 14))),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
      ]),
    );
  }
}
