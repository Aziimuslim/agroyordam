import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_widgets.dart';
import 'verify_screen.dart';

/// S34 Ro'yxatdan o'tish: ism, aloqa kanali (telefon/email), parol va tasdig'i, qoidalarga rozilik (oldindan
/// belgilanmagan). Server kod yuborish kanalini e'lon qilsa — hisob faqat kod tasdiqlangach yaratiladi (S35).
/// Kanal ulanmagan bo'lsa hisob darhol yaratiladi va bu ekranda ochiq aytiladi. Parol qoralamaga yozilmaydi.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController(), _email = TextEditingController();
  final _pass = TextEditingController(), _repeat = TextEditingController();
  String _via = 'phone';
  bool _terms = false, _loading = false, _submitted = false, _done = false;
  String? _error, _contactError;

  bool get _dirty => [_name, _phone, _email, _pass, _repeat].any((c) => c.text.isNotEmpty);

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pass, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _contact => _via == 'phone' ? (normalizePhone(_phone.text) ?? '') : _email.text.trim().toLowerCase();

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
      _contactError = null;
    });
    final ok = _form.currentState!.validate();
    if (!ok || !_terms || _loading) return;
    setState(() => _loading = true);
    final opts = ref.read(authOptionsProvider).value;
    final channel = _via == 'phone' ? 'sms' : 'email';
    try {
      if (opts != null && opts.channels.contains(channel)) {
        final ch = await ref.read(authRepoProvider).challenge(purpose: 'register', channel: channel, destination: _contact, signup: {
          'full_name': _name.text.trim(),
          'password': _pass.text,
          'language': I18n.lang.code,
          'accept_terms': true,
        });
        if (mounted) context.push('/auth/verify', extra: VerifyArgs(ch));
      } else {
        setState(() => _done = true); // router muvaffaqiyatda bosh sahifaga o'tkazadi — chiqish dialogi chiqmasin
        await ref.read(authProvider.notifier).register(
              fullName: _name.text.trim(),
              phone: _via == 'phone' ? _contact : null,
              email: _via == 'email' ? _contact : null,
              password: _pass.text,
              language: I18n.lang.code,
              acceptTerms: true,
            );
      }
    } catch (e) {
      final err = ApiException.from(e);
      if (mounted) {
        setState(() {
          _done = false;
          if (err.statusCode == 409) {
            _contactError = err.message;
          } else {
            _error = err.message;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final opts = ref.watch(authOptionsProvider).value;
    final channel = _via == 'phone' ? 'sms' : 'email';
    final verified = opts?.channels.contains(channel) ?? false;
    return PopScope(
      canPop: !_dirty || _done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, tr("O'zgarishlar saqlanmagan"), tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi."), ok: tr('Chiqish'), danger: true);
        if (leave && context.mounted) {
          setState(() => _done = true);
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/welcome');
          }
        }
      },
      child: AuthPage(
        title: tr("Ro'yxatdan o'tish"),
        subtitle: tr('Bir daqiqada hisob yarating va ekinlaringizni kuzatishni boshlang'),
        children: [
          Form(
            key: _form,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FieldLabel(tr("To'liq ism")),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(hintText: tr('Masalan: Aziz Karimov'), counterText: ''),
                  validator: (v) => (v ?? '').trim().length < 2 ? tr("Ism kamida 2 ta belgidan iborat bo'lsin") : null,
                ),
                const SizedBox(height: 14),
                SegmentTabs(
                  tabs: [('phone', tr('Telefon')), ('email', tr('Email'))],
                  selected: _via,
                  onSelect: (v) => setState(() {
                    _via = v;
                    _contactError = null;
                  }),
                ),
                const SizedBox(height: 10),
                if (_via == 'phone')
                  PhoneField(controller: _phone, errorText: _contactError)
                else
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 17),
                    decoration: InputDecoration(hintText: 'email@misol.uz', errorText: _contactError, errorMaxLines: 2),
                    validator: (v) => validEmail(v ?? '') ? null : tr("Email noto'g'ri"),
                  ),
                FieldLabel(tr('Parol')),
                PasswordField(controller: _pass, hint: tr('Kamida 8 ta belgi'), newPassword: true, action: TextInputAction.next, validator: newPasswordRule),
                FieldLabel(tr('Parolni takrorlang')),
                PasswordField(
                  controller: _repeat,
                  newPassword: true,
                  validator: (v) => v != _pass.text ? tr('Parollar mos emas') : null,
                  onSubmitted: (_) => _submit(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _terms,
            onChanged: (v) => setState(() => _terms = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('Ilova qoidalari va maxfiylik shartlariga roziman'), style: TextStyle(fontSize: 15.5, color: c.text)),
            subtitle: _submitted && !_terms ? Text(tr('Davom etish uchun rozilik kerak'), style: TextStyle(color: c.danger, fontSize: 14)) : null,
          ),
          const TermsLink(text: null),
          if (_error != null) ErrorBox(_error!),
          const SizedBox(height: 12),
          AuthButton(label: verified ? tr('Kod olish') : tr("Ro'yxatdan o'tish"), loading: _loading, onPressed: _submit),
          const SizedBox(height: 8),
          Text(
            verified
                ? (_via == 'phone' ? tr("Raqamga 6 xonali kod yuboriladi. Hisob kod tasdiqlangach yaratiladi.") : tr("Emailga 6 xonali kod yuboriladi. Hisob kod tasdiqlangach yaratiladi."))
                : tr("Kod yuborish xizmati hali ulanmagan — telefon yoki email hozircha tasdiqlanmaydi."),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.pushReplacement('/auth/login'),
              child: Text(tr('Hisobingiz bormi? Kirish'), style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
