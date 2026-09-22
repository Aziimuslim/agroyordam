import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

const providers = [('payme', 'Payme'), ('click', 'Click'), ('uzum', 'Uzum Bank')];

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumState();
}

class _PremiumState extends ConsumerState<PremiumScreen> {
  String _plan = 'monthly';

  Future<void> _checkout(Plan plan) async {
    final provider = await showSheet<String>(context, title: "To'lov usulini tanlang", builder: (ctx) => Column(children: [
          for (final (id, label) in providers)
            ListRow(icon: AppIcons.card, label: label, onTap: () => Navigator.pop(ctx, id)),
          PillButton(label: 'Bekor qilish', style: PillStyle.soft, block: true, onPressed: () => Navigator.pop(ctx)),
        ]));
    if (provider == null || !mounted) return;
    final repo = ref.read(subscriptionRepoProvider);
    try {
      final co = await repo.checkout(plan.code, provider);
      if (!mounted) return;
      if (co.sandbox) {
        final label = providers.firstWhere((p) => p.$1 == provider).$2;
        final ok = await showSheet<bool>(context, title: '$label — test to\'lov', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sandbox rejimi: haqiqiy pul yechilmaydi.', style: TextStyle(color: ctx.c.muted)),
              InfoBox(label: plan.title, value: formatMoney(co.amount)),
              const SizedBox(height: 10),
              PillButton(label: "To'lash", icon: AppIcons.lock, block: true, onPressed: () => Navigator.pop(ctx, true)),
            ]));
        if (ok != true) return;
        await repo.sandboxConfirm(co.subscriptionId);
      } else {
        await launchUrl(Uri.parse(co.paymentUrl), mode: LaunchMode.externalApplication);
        if (mounted) showToast(context, "To'lovdan so'ng ilovaga qayting — Premium avtomatik faollashadi");
        return;
      }
      await ref.read(authProvider.notifier).refreshUser();
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(paymentsProvider);
      if (mounted) showToast(context, 'Premium faollashtirildi!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cancel() async {
    if (!await confirm(context, 'Obunani bekor qilish', "Avto-yangilanish o'chadi. Premium joriy muddat oxirigacha ishlaydi.", ok: 'Bekor qilish', danger: true)) return;
    try {
      await ref.read(subscriptionRepoProvider).cancel();
      ref.invalidate(mySubscriptionProvider);
      if (mounted) showToast(context, 'Avto-yangilanish o\'chirildi');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(mySubscriptionProvider);
    final plans = ref.watch(plansProvider);
    return PageShell(
      padBottom: false,
      onRefresh: () async {
        ref.invalidate(mySubscriptionProvider);
        ref.invalidate(plansProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Obunam'),
        me.maybeWhen(
          data: (s) => RowCard(
            leading: const ThumbIcon(icon: AppIcons.clock),
            title: 'Joriy reja: ${s.isPremium ? 'Premium' : 'Bepul'}',
            subtitle: s.isPremium
                ? (s.premiumUntil != null && s.premiumUntil!.year < 2100 ? '${formatDate(s.premiumUntil)} gacha · AI tashxis cheksiz' : 'Umrbod · AI tashxis cheksiz')
                : 'AI tashxis: bugun ${s.aiUsedToday}/${s.aiDailyLimit} · Ekinlar: ${s.cropsUsed}/${s.cropLimit}',
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: softShadow(context)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Text('Bepul', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), Text("0 so'm", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))]),
            const SizedBox(height: 6),
            _Feat('AI tashxis — kuniga 3 marta', c.success),
            _Feat("\"Mening bog'im\" — 3 tagacha ekin", c.success),
            _Feat("Ensiklopediya, eslatmalar, jamoat — to'liq ochiq", c.success),
          ]),
        ),
        plans.maybeWhen(
          data: (list) {
            final plan = list.firstWhere((p) => p.code == _plan, orElse: () => list.first);
            final isPremium = me.value?.isPremium ?? false;
            return Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: c.dark, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(AppIcons.star, color: c.gold, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Premium', style: TextStyle(color: c.card, fontSize: 17, fontWeight: FontWeight.w800))),
                  Text(formatMoney(plan.price) + (plan.code == 'monthly' ? '/oy' : plan.code == 'yearly' ? '/yil' : ''), style: TextStyle(color: c.gold, fontWeight: FontWeight.w900, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final p in list)
                    Material(
                      color: _plan == p.code ? c.gold : c.card.withValues(alpha: 0.12),
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => _plan = p.code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Text(switch (p.code) { 'monthly' => '1 oy', 'yearly' => '1 yil', _ => 'Umrbod' },
                              style: TextStyle(color: _plan == p.code ? c.onGold : c.card, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                for (final f in plan.features) _Feat(f, c.gold, dark: true),
                const SizedBox(height: 8),
                isPremium
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: c.card.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                        alignment: Alignment.center,
                        child: Text('Faol reja', style: TextStyle(color: c.card, fontWeight: FontWeight.w800)),
                      )
                    : PillButton(label: "Premium'ga o'tish", style: PillStyle.light, block: true, onPressed: () => _checkout(plan)),
              ]),
            );
          },
          orElse: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        ),
        ListRow(icon: AppIcons.card, label: "To'lovlar tarixi", onTap: () => context.push('/premium/payments')),
        if (me.value?.active?.autoRenew == true) ListRow(icon: Icons.cancel_outlined, label: 'Avto-yangilanishni bekor qilish', danger: true, onTap: _cancel),
      ]),
    );
  }
}

class _Feat extends StatelessWidget {
  const _Feat(this.text, this.color, {this.dark = false});
  final String text;
  final Color color;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(AppIcons.check, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.35, color: dark ? context.c.card : context.c.text))),
        ]),
      );
}

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    const statusLabels = {'active': 'Muvaffaqiyatli', 'expired': 'Muddati tugagan', 'cancelled': 'Bekor qilingan', 'trial': 'Sinov'};
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: "To'lovlar tarixi"),
        AsyncView(
          value: ref.watch(paymentsProvider),
          onRetry: () => ref.invalidate(paymentsProvider),
          data: (list) => list.isEmpty
              ? const EmptyNote("To'lovlar yo'q", icon: AppIcons.card)
              : Column(children: [
                  for (final s in list)
                    RowCard(
                      leading: ThumbIcon(icon: AppIcons.star, bg: s.status == 'cancelled' ? c.dangerBg : c.primaryLight, fg: s.status == 'cancelled' ? c.danger : c.primaryDark),
                      title: switch (s.plan) { 'monthly' => 'Premium obuna — 1 oy', 'yearly' => 'Premium obuna — 1 yil', _ => 'Premium — umrbod' },
                      subtitle: '${providers.firstWhere((p) => p.$1 == s.provider, orElse: () => ('', s.provider ?? '')).$2} · ${formatDate(s.startedAt)}',
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatMoney(s.price ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                        Text(statusLabels[s.status] ?? s.status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s.status == 'cancelled' ? c.danger : c.success)),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
