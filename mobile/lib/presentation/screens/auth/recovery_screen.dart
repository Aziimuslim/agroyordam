import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/ds.dart';
import 'auth_widgets.dart';
import 'verify_screen.dart';

/// S36 Parolni tiklash: telefon yoki email → kod (S35) → yangi parol. Hisob bor-yo'qligidan qat'i nazar javob
/// bir xil. Kod yuborish kanali ulanmagan bo'lsa — buni ochiq aytamiz va ishlaydigan yo'lni ko'rsatamiz
/// (administrator vaqtinchalik parol beradi; kirgach Profil → Parol va xavfsizlik).
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});
  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController(), _email = TextEditingController();
  String? _via;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send(String channel) async {
    setState(() => _error = null);
    if (!_form.currentState!.validate() || _loading) return;
    setState(() => _loading = true);
    try {
      final dest = channel == 'sms' ? normalizePhone(_phone.text)! : _email.text.trim().toLowerCase();
      final ch = await ref.read(authRepoProvider).challenge(purpose: 'recovery', channel: channel, destination: dest);
      if (mounted) context.push('/auth/verify', extra: VerifyArgs(ch));
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final optsV = ref.watch(authOptionsProvider);
    final opts = optsV.value;
    Widget body;
    if (opts == null && optsV.hasError) {
      body = BlockError(error: optsV.error!, what: tr('Tiklash usullari'), onRetry: () => ref.invalidate(authOptionsProvider));
    } else if (opts == null) {
      body = const Skeleton(height: 160);
    } else if (!opts.any) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteBox(
            title: tr('Kod yuborish xizmati hali ulanmagan'),
            text: tr(
              "Hozircha parolni SMS yoki email orqali tiklab bo'lmaydi. Administratorga murojaat qiling: u vaqtinchalik parol beradi. Kirgach, Profil → Parol va xavfsizlik bo'limida o'zingiz yangi parol qo'yasiz.",
            ),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 16),
          AuthButton(label: tr('Kirishga qaytish'), onPressed: () => context.canPop() ? context.pop() : context.go('/auth/login')),
        ],
      );
    } else {
      final via = _via ?? (opts.sms ? 'phone' : 'email');
      final channel = via == 'phone' ? 'sms' : 'email';
      body = Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (opts.sms && opts.email) ...[
              SegmentTabs(tabs: [('phone', tr('Telefon')), ('email', tr('Email'))], selected: via, onSelect: (v) => setState(() => _via = v)),
              const SizedBox(height: 12),
            ],
            if (via == 'phone')
              PhoneField(controller: _phone, onSubmitted: (_) => _send(channel))
            else
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(hintText: 'email@misol.uz'),
                onFieldSubmitted: (_) => _send(channel),
                validator: (v) => validEmail(v ?? '') ? null : tr("Email noto'g'ri"),
              ),
            const SizedBox(height: 8),
            Text(tr("Agar shu ma'lumot bilan hisob bo'lsa, unga 6 xonali kod yuboriladi."), style: TextStyle(color: c.muted, fontSize: 14)),
            if (_error != null) ErrorBox(_error!),
            const SizedBox(height: 16),
            AuthButton(label: tr('Kodni yuborish'), loading: _loading, onPressed: () => _send(channel)),
          ],
        ),
      );
    }
    return AuthPage(
      title: tr('Parolni tiklash'),
      subtitle: tr("Ro'yxatdan o'tgan telefon yoki emailingizni kiriting"),
      children: [
        body,
        if (opts?.any ?? false) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/auth/login'),
              child: Text(
                tr('Kirishga qaytish'),
                style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
