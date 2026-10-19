import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

const providers = [('payme', 'Payme'), ('click', 'Click'), ('uzum', 'Uzum Bank')];

String providerLabel(String? id) => providers.firstWhere((p) => p.$1 == id, orElse: () => ('', id ?? '—')).$2;

String planLabel(String code) => switch (code) { 'monthly' => tr('1 oy'), 'yearly' => tr('1 yil'), _ => tr('Umrbod') };

String planPeriod(Plan p) => p.durationDays == null ? tr('Muddatsiz') : trf('{0} kun', [p.durationDays]);

/// S29 Obunam. Narx va imkoniyatlar faqat serverdan (yuklanmasa — sotilmaydi). Tarif → buyurtma xulosasi (A08) →
/// provayder. Premium faqat server tasdig'idan keyin ochiladi: to'lovdan qaytilganda buyurtma holati tekshiriladi.
/// Avtomatik yangilanish yo'q — UI uni va'da qilmaydi.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumState();
}

class _PremiumState extends ConsumerState<PremiumScreen> {
  String _plan = 'monthly';
  bool _busy = false;

  /// Provayderga yuborilgan, hali tasdiqlanmagan buyurtma.
  Subscription? _pending;
  late final AppLifecycleListener _life = AppLifecycleListener(onResume: () {
    if (_pending != null) _check(silent: true);
  });

  @override
  void initState() {
    super.initState();
    _life; // ilovaga qaytganda holat bir marta tekshiriladi
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await ref.read(authProvider.notifier).refreshUser();
    ref.invalidate(mySubscriptionProvider);
    ref.invalidate(paymentsProvider);
  }

  Future<void> _check({bool silent = false}) async {
    final p = _pending;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    try {
      final o = await ref.read(subscriptionRepoProvider).order(p.id);
      if (!mounted) return;
      setState(() => _pending = o.paymentStatus == 'pending' ? o : null);
      if (o.paymentStatus == 'paid') {
        await _refreshAll();
        if (mounted) showToast(context, tr('Premium faollashtirildi!'));
      } else if (o.paymentStatus == 'failed') {
        ref.invalidate(paymentsProvider);
        if (mounted) showToast(context, tr("To'lov amalga oshmadi. Premium berilmadi."));
      } else if (!silent) {
        showToast(context, tr("To'lov hali tasdiqlanmagan. Birozdan so'ng qayta tekshiring."));
      }
    } catch (e) {
      if (mounted && !silent) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _order(Plan plan, MySubscription? me) async {
    if (_busy) return;
    final provider = await showSheet<String>(context, title: tr('Buyurtma'), builder: (ctx) => _OrderSummary(plan: plan, me: me));
    if (provider == null || !mounted) return;
    setState(() => _busy = true);
    final repo = ref.read(subscriptionRepoProvider);
    try {
      final co = await repo.checkout(plan.code, provider);
      if (!mounted) return;
      if (co.sandbox) {
        final ok = await showSheet<bool>(context, title: trf('{0} — test to\'lov', [providerLabel(provider)]), builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('Sandbox rejimi: haqiqiy pul yechilmaydi.'), style: TextStyle(color: ctx.c.muted, fontSize: 15)),
              const SizedBox(height: 10),
              _SummaryRow(plan.title, formatMoney(co.amount)),
              const SizedBox(height: 14),
              PillButton(label: tr("To'lash"), icon: AppIcons.lock, block: true, onPressed: () => Navigator.pop(ctx, true)),
            ]));
        if (ok != true) {
          ref.invalidate(paymentsProvider);
          return;
        }
        await repo.sandboxConfirm(co.subscriptionId);
        await _refreshAll();
        if (mounted) showToast(context, tr('Premium faollashtirildi!'));
      } else {
        setState(() => _pending = Subscription(id: co.subscriptionId, plan: plan.code, status: 'pending', price: co.amount, provider: provider));
        ref.invalidate(paymentsProvider);
        final opened = await launchUrl(Uri.parse(co.paymentUrl), mode: LaunchMode.externalApplication);
        if (!opened && mounted) showToast(context, tr("To'lov sahifasi ochilmadi"));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meV = ref.watch(mySubscriptionProvider);
    final plansV = ref.watch(plansProvider);
    final me = meV.value;

    Widget status;
    if (me == null && meV.hasError) {
      status = BlockError(error: meV.error!, what: tr('Obuna holati'), onRetry: () => ref.invalidate(mySubscriptionProvider));
    } else if (me == null) {
      status = const Skeleton(height: 96);
    } else {
      final lifetime = me.premiumUntil != null && me.premiumUntil!.year >= 2100;
      status = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: me.isPremium ? c.oliveSoft : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: me.isPremium ? c.olive : c.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(me.isPremium ? AppIcons.star : Icons.eco_outlined, color: me.isPremium ? c.olive : c.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(me.isPremium ? tr('Premium faol') : tr('Bepul reja'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: me.isPremium ? c.onOliveSoft : c.text)),
            ),
          ]),
          const SizedBox(height: 6),
          if (me.isPremium)
            Text(lifetime ? tr('Muddatsiz') : trf('{0} gacha', [formatDate(me.premiumUntil)]), style: TextStyle(fontSize: 15, color: c.onOliveSoft))
          else ...[
            Text(trf('AI tashxis bugun: {0}/{1}', [me.aiUsedToday, me.aiDailyLimit ?? '∞']), style: TextStyle(fontSize: 15, color: c.text)),
            Text(trf("Ekinlar: {0}/{1}", [me.cropsUsed, me.cropLimit ?? '∞']), style: TextStyle(fontSize: 15, color: c.text)),
          ],
        ]),
      );
    }

    Widget offer;
    final plans = plansV.value;
    if (plans == null && plansV.hasError) {
      // Tarif olinmasa taxminiy narx ko'rsatilmaydi (TZ S29)
      offer = BlockError(error: plansV.error!, what: tr('Tariflar'), onRetry: () => ref.invalidate(plansProvider));
    } else if (plans == null) {
      offer = const Skeleton(height: 260);
    } else if (plans.isEmpty) {
      offer = EmptyNote(tr('Hozircha tarif mavjud emas'), icon: AppIcons.star);
    } else {
      final plan = plans.firstWhere((p) => p.code == _plan, orElse: () => plans.first);
      final lifetimeActive = me?.isPremium == true && me?.premiumUntil != null && me!.premiumUntil!.year >= 2100;
      offer = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ChipTabs(tabs: [for (final p in plans) (p.code, planLabel(p.code))], selected: plan.code, onSelect: (v) => setState(() => _plan = v)),
          const SizedBox(height: 6),
          Text(plan.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 2),
          Text('${formatMoney(plan.price)} · ${planPeriod(plan)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.primaryDark)),
          const SizedBox(height: 10),
          for (final f in plan.features) _Feat(tr(f)),
          const SizedBox(height: 4),
          Text(tr("Avtomatik yangilanmaydi: muddat tugagach o'zingiz uzaytirasiz."), style: TextStyle(fontSize: 13.5, color: c.muted)),
          const SizedBox(height: 14),
          if (lifetimeActive)
            Text(tr('Sizda muddatsiz Premium bor'), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.olive))
          else
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _busy || _pending != null ? null : () => _order(plan, me),
                child: _busy
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                    : Text(me?.isPremium == true ? tr('Muddatni uzaytirish') : tr("Premium'ga o'tish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );
    }

    return PageShell(
      maxWidth: 640,
      padBottom: false,
      onRefresh: () async {
        ref.invalidate(mySubscriptionProvider);
        ref.invalidate(plansProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Obunam')),
        status,
        if (_pending != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr("To'lov kutilmoqda"), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 4),
              Text(trf("{0} · {1}. Premium to'lov tasdiqlangandan keyin ochiladi.", [providerLabel(_pending!.provider), formatMoney(_pending!.price ?? 0)]),
                  style: TextStyle(fontSize: 14.5, color: c.text)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _busy ? null : () => _check(),
                    child: Text(tr('Tekshirish')),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _pending = null), child: Text(tr('Yopish'))),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        offer,
        const SizedBox(height: 12),
        ListRow(icon: AppIcons.card, label: tr("To'lovlar tarixi"), onTap: () => context.push('/premium/payments')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// A08 Buyurtma xulosasi: tarif, narx, davr, yangilanmasligi va to'lov usuli. Tasdiqlansa — provayder id qaytadi.
class _OrderSummary extends StatefulWidget {
  const _OrderSummary({required this.plan, required this.me});
  final Plan plan;
  final MySubscription? me;
  @override
  State<_OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<_OrderSummary> {
  String? _provider;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.plan;
    final extend = widget.me?.isPremium == true && widget.me?.premiumUntil != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SummaryRow(tr('Tarif'), p.title),
      _SummaryRow(tr('Davr'), planPeriod(p)),
      _SummaryRow(tr('Narx'), formatMoney(p.price), bold: true),
      _SummaryRow(tr('Avtomatik yangilanish'), tr("Yo'q")),
      if (extend) Padding(padding: const EdgeInsets.only(top: 4), child: Text(trf("Joriy muddat ({0}) ga qo'shiladi.", [formatDate(widget.me!.premiumUntil)]), style: TextStyle(color: c.muted, fontSize: 14))),
      const SizedBox(height: 14),
      Text(tr("To'lov usuli"), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
      const SizedBox(height: 6),
      RadioGroup<String>(
        groupValue: _provider,
        onChanged: (v) => setState(() => _provider = v),
        child: Column(children: [
          for (final (id, label) in providers) RadioListTile<String>(value: id, title: Text(label), contentPadding: EdgeInsets.zero),
        ]),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _provider == null ? null : () => Navigator.pop(context, _provider),
          child: Text(trf("{0} to'lash", [formatMoney(p.price)]), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 6),
      Text(tr("To'lov provayder sahifasida amalga oshadi. Premium server to'lovni tasdiqlagach ochiladi."), style: TextStyle(color: c.muted, fontSize: 13.5)),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false});
  final String label, value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c.muted))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 15, color: c.text, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
      ]),
    );
  }
}

class _Feat extends StatelessWidget {
  const _Feat(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(AppIcons.check, size: 18, color: context.c.olive),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, height: 1.35, color: context.c.text))),
        ]),
      );
}

/// S30 To'lovlar tarixi: filtr, buyurtma tafsiloti, kutilayotganini tekshirish. Holat va summa — serverdan.
/// Chek (receipt) — provayder integratsiyasida yo'q.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsState();
}

class _PaymentsState extends ConsumerState<PaymentsScreen> {
  String _filter = 'all';

  static Map<String, String> get _labels => {
        'paid': tr("To'langan"),
        'pending': tr('Kutilmoqda'),
        'failed': tr('Amalga oshmagan'),
        'refunded': tr('Qaytarilgan'),
      };

  (Color, Color) _colors(BuildContext context, String s) {
    final c = context.c;
    return switch (s) {
      'paid' => (c.successBg, c.success),
      'pending' => (c.warningBg, c.warning),
      _ => (c.dangerBg, c.danger),
    };
  }

  void _details(Subscription s) {
    final c = context.c;
    showSheet(context, title: trf('Premium — {0}', [planLabel(s.plan)]), builder: (ctx) {
      String dt(DateTime? d) => d == null ? '—' : '${formatDate(d)} ${hhmmLocal(d)}';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SummaryRow(tr('Holat'), _labels[s.paymentStatus] ?? s.paymentStatus, bold: true),
        _SummaryRow(tr('Summa'), s.price == null ? '—' : '${formatMoney(s.price!)}${s.currency == 'UZS' ? '' : ' ${s.currency}'}'),
        _SummaryRow(tr("To'lov usuli"), providerLabel(s.provider)),
        _SummaryRow(tr('Yaratilgan'), dt(s.createdAt)),
        if (s.paidAt != null) _SummaryRow(tr("To'langan"), dt(s.paidAt)),
        if (s.refundedAt != null) _SummaryRow(tr('Qaytarilgan'), dt(s.refundedAt)),
        if (s.paymentStatus == 'paid') _SummaryRow(tr('Amal qiladi'), s.expiresAt == null ? tr('Muddatsiz') : trf('{0} gacha', [formatDate(s.expiresAt)])),
        _SummaryRow(tr('Buyurtma raqami'), s.id.substring(0, 8).toUpperCase()),
        if (s.txnId != null) _SummaryRow(tr('Tranzaksiya'), s.txnId!),
        if (s.paymentStatus == 'pending') ...[
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final o = await ref.read(subscriptionRepoProvider).order(s.id);
                ref.invalidate(paymentsProvider);
                if (o.paymentStatus == 'paid') {
                  await ref.read(authProvider.notifier).refreshUser();
                  ref.invalidate(mySubscriptionProvider);
                }
                if (mounted) showToast(context, _labels[o.paymentStatus] ?? o.paymentStatus);
              } catch (e) {
                if (mounted) showError(context, e);
              }
            },
            child: Text(tr('Holatni yangilash')),
          ),
        ],
        const SizedBox(height: 8),
        Text(tr("Karta ma'lumotlari ilovada saqlanmaydi."), style: TextStyle(color: c.muted, fontSize: 13)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(paymentsProvider);
    final list = v.value;
    Widget body;
    if (list == null && v.hasError) {
      body = BlockError(error: v.error!, what: tr("To'lovlar"), onRetry: () => ref.invalidate(paymentsProvider));
    } else if (list == null) {
      body = Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 72))]);
    } else if (list.isEmpty) {
      body = EmptyNote(tr("Hali to'lov yo'q"), icon: AppIcons.card);
    } else {
      final shown = _filter == 'all' ? list : list.where((s) => s.paymentStatus == _filter).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (shown.isEmpty) EmptyNote(tr("Bu bo'limda yozuv yo'q"), icon: AppIcons.card),
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: c.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _details(s),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trf('Premium — {0}', [planLabel(s.plan)]), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                        Text('${providerLabel(s.provider)} · ${formatDate(s.paidAt ?? s.createdAt ?? s.startedAt)}', style: TextStyle(fontSize: 14, color: c.muted)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(s.price == null ? '—' : formatMoney(s.price!), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final (bg, fg) = _colors(context, s.paymentStatus);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                          child: Text(_labels[s.paymentStatus] ?? s.paymentStatus, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg)),
                        );
                      }),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    }
    return PageShell(
      maxWidth: 640,
      padBottom: false,
      onRefresh: () async => ref.invalidate(paymentsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr("To'lovlar tarixi")),
        ChipTabs(
          tabs: [('all', tr('Barchasi')), for (final e in _labels.entries) (e.key, e.value)],
          selected: _filter,
          onSelect: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 8),
        body,
      ]),
    );
  }
}
