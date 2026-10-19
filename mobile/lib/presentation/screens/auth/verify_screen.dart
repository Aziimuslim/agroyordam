import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'auth_widgets.dart';

/// S35 uchun xotiradagi argument (URL'da kod yoki token bo'lmaydi).
class VerifyArgs {
  const VerifyArgs(this.challenge);
  final Challenge challenge;
}

/// S35 Kodni tasdiqlash: 6 raqam (paste/autofill), qolgan vaqt va qayta yuborish taymeri, qolgan urinishlar.
/// Noto'g'ri va eskirgan kod alohida xabar bilan. Maqsadga ko'ra: ro'yxatdan o'tish/kirish — sessiya (router
/// yo'naltiradi), tiklash — shu yerda yangi parol formasi (A08), recovery token faqat xotirada.
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, this.args});
  final VerifyArgs? args;
  @override
  ConsumerState<VerifyScreen> createState() => _VerifyState();
}

class _VerifyState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  final _pass = TextEditingController(), _repeat = TextEditingController();
  final _passForm = GlobalKey<FormState>();
  late Challenge? _ch = widget.args?.challenge;
  late final _expiry = Countdown(_tick), _resend = Countdown(_tick);
  bool _loading = false, _expired = false, _locked = false;
  String? _error, _recoveryToken;
  int? _attemptsLeft;

  void _tick() => mounted ? setState(() {}) : null;

  @override
  void initState() {
    super.initState();
    if (_ch != null) _startTimers(_ch!);
  }

  void _startTimers(Challenge ch) {
    _expiry.start(ch.expiresIn);
    _resend.start(ch.resendIn);
    _attemptsLeft = ch.attemptsLeft;
  }

  @override
  void dispose() {
    _expiry.dispose();
    _resend.dispose();
    for (final c in [_code, _pass, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6 || _loading || _ch == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref.read(authRepoProvider).verify(_ch!.id, code);
      _code.clear();
      if (token != null) {
        setState(() => _recoveryToken = token); // tiklash: yangi parol formasi
      } else {
        TextInput.finishAutofillContext();
        await ref.read(authProvider.notifier).completeSession(); // router bosh sahifaga (yoki returnTo) olib boradi
      }
    } catch (e) {
      final err = ApiException.from(e);
      _code.clear();
      if (!mounted) return;
      setState(() {
        switch (err.statusCode) {
          case 410:
            _expired = true;
            _error = tr("Kod muddati tugagan. Yangi kod so'rang.");
          case 429:
            _locked = true;
            _error = tr("Urinishlar tugadi. Yangi kod so'rang.");
          case 400:
            // Sarlavha kelmasa (eski server/proxy) — mahalliy hisob; server baribir o'zi cheklaydi
            _attemptsLeft = err.attemptsLeft ?? ((_attemptsLeft ?? 1) - 1).clamp(0, 99);
            _error = _attemptsLeft == null ? tr("Kod noto'g'ri") : trf("Kod noto'g'ri. {0} ta urinish qoldi.", [_attemptsLeft]);
            if (_attemptsLeft == 0) _locked = true;
          default:
            _error = err.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_ch == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ch = await ref.read(authRepoProvider).resend(_ch!.id);
      if (!mounted) return;
      setState(() {
        _ch = ch;
        _expired = false;
        _locked = false;
        _code.clear();
      });
      _startTimers(ch);
      showToast(context, tr('Yangi kod yuborildi. Eski kod endi ishlamaydi.'));
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      setState(() => _error = err.message);
      if (err.statusCode == 429 && err.retryAfter != null) _resend.start(err.retryAfter!);
      if (err.statusCode == 410) setState(() => _expired = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePassword() async {
    if (!(_passForm.currentState?.validate() ?? false) || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).recoveryReset(_recoveryToken!, _pass.text);
      _pass.clear();
      _repeat.clear();
      _recoveryToken = null;
      if (!mounted) return;
      showToast(context, tr('Parol yangilandi. Endi yangi parol bilan kiring.'));
      context.go('/auth/login');
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ch = _ch;
    if (ch == null) {
      return AuthPage(title: tr('Kodni tasdiqlash'), children: [
        EmptyNote(tr("Bu sahifa eskirgan. Kodni qaytadan so'rang."), icon: Icons.timer_off_outlined),
        AuthButton(label: tr('Kirishga qaytish'), onPressed: () => context.go('/auth/login')),
      ]);
    }

    if (_recoveryToken != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await confirm(context, tr('Chiqasizmi?'), tr('Yangi parol saqlanmaydi, tiklashni qaytadan boshlashingiz kerak bo\'ladi.'), ok: tr('Chiqish'), danger: true) &&
              context.mounted) {
            context.go('/auth/login');
          }
        },
        child: AuthPage(
          title: tr('Yangi parol'),
          subtitle: tr("Kod tasdiqlandi. Yangi parol o'rnating — barcha qurilmalardagi seanslar tugatiladi."),
          children: [
            Form(
              key: _passForm,
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FieldLabel(tr('Yangi parol')),
                  PasswordField(controller: _pass, newPassword: true, hint: tr('Kamida 8 ta belgi'), action: TextInputAction.next, validator: newPasswordRule),
                  FieldLabel(tr('Yangi parolni takrorlang')),
                  PasswordField(controller: _repeat, newPassword: true, validator: (v) => v != _pass.text ? tr('Parollar mos emas') : null, onSubmitted: (_) => _savePassword()),
                ]),
              ),
            ),
            if (_error != null) ErrorBox(_error!),
            const SizedBox(height: 18),
            AuthButton(label: tr('Parolni saqlash'), loading: _loading, onPressed: _savePassword),
          ],
        ),
      );
    }

    final dead = _expired || _locked || !_expiry.running;
    return AuthPage(
      title: tr('Kodni kiriting'),
      subtitle: trf('6 xonali kod {0} ga yuborildi.', [ch.destinationMasked]),
      children: [
        if (ch.devCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoteBox(title: tr('Sinov rejimi'), text: trf("SMS/email yuborilmaydi. Sinov kodi: {0}", [ch.devCode]), icon: Icons.science_outlined),
          ),
        TextField(
          controller: _code,
          autofocus: true,
          enabled: !dead,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w800, color: c.text),
          decoration: const InputDecoration(hintText: '••••••', counterText: ''),
          onChanged: (v) {
            setState(() {});
            if (v.length == 6) _verify();
          },
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 8),
        Text(
          dead ? tr('Kod endi ishlamaydi') : trf('Kod {0} davomida amal qiladi', [mmss(_expiry.left)]),
          textAlign: TextAlign.center,
          style: TextStyle(color: dead ? c.danger : c.muted, fontSize: 14),
        ),
        if (_error != null) ErrorBox(_error!),
        const SizedBox(height: 16),
        AuthButton(label: tr('Tasdiqlash'), loading: _loading, onPressed: dead || _code.text.length != 6 ? null : _verify),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.lineStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _resend.running || _loading ? null : _resendCode,
            child: Text(_resend.running ? trf("Qayta yuborish: {0}", [mmss(_resend.left)]) : tr('Kodni qayta yuborish')),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/auth/login'),
            child: Text(ch.channel == 'sms' ? tr("Raqamni o'zgartirish") : tr("Emailni o'zgartirish"), style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
