import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import 'auth_widgets.dart';
import 'verify_screen.dart';

/// S33 Kirish: Telefon/Email (yoki foydalanuvchi nomi) + parol. Server xatosi umumiy — hisob borligi oshkor
/// qilinmaydi. 429 da taymer. Kod bilan kirish faqat server kanal e'lon qilsa ko'rinadi. Muvaffaqiyatdan keyin
/// router xavfsiz returnTo yoki bosh sahifaga olib boradi. Parolni eslab qolish — faqat OS parol menejeri (autofill).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.via = 'phone'});
  final String via;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController(), _phone = TextEditingController(), _pass = TextEditingController();
  late String _via = widget.via == 'email' ? 'email' : 'phone';
  bool _loading = false;
  String? _error;
  late final _wait = Countdown(() => mounted ? setState(() {}) : null);

  @override
  void dispose() {
    _wait.dispose();
    for (final c in [_login, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _id => _via == 'phone' ? (normalizePhone(_phone.text) ?? '') : _login.text.trim();

  void _fail(Object e) {
    final err = ApiException.from(e);
    setState(() {
      _error = err.statusCode == 401 ? tr("Login yoki parol noto'g'ri. Ma'lumotlarni tekshiring.") : err.message;
      if (err.statusCode == 429) _wait.start(err.retryAfter ?? 60);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate() || _loading || _wait.running) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(_id, _pass.text);
      TextInput.finishAutofillContext();
      // Yo'naltirishni router qiladi (returnTo yoki /home)
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _codeLogin() async {
    setState(() => _error = null);
    final channel = _via == 'phone' ? 'sms' : 'email';
    final valid = _via == 'phone' ? normalizePhone(_phone.text) != null : validEmail(_login.text);
    if (!valid) {
      setState(() => _error = _via == 'phone' ? tr("Telefon raqamini to'liq kiriting: 90 123 45 67") : tr("Kod bilan kirish uchun email kiriting"));
      return;
    }
    setState(() => _loading = true);
    try {
      final ch = await ref.read(authRepoProvider).challenge(purpose: 'login', channel: channel, destination: _id);
      if (mounted) context.push('/auth/verify', extra: VerifyArgs(ch));
    } catch (e) {
      if (mounted) _fail(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final opts = ref.watch(authOptionsProvider).value;
    final codeAvailable = _via == 'phone' ? (opts?.sms ?? false) : (opts?.email ?? false);
    return AuthPage(
      title: tr('Hisobingizga kiring'),
      subtitle: _via == 'phone' ? tr("Ro'yxatdan o'tgan telefon raqami va parol") : tr('Email yoki foydalanuvchi nomi va parol'),
      children: [
        SegmentTabs(
          tabs: [('phone', tr('Telefon')), ('email', tr('Email'))],
          selected: _via,
          onSelect: (v) => setState(() {
            _via = v;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_via == 'phone')
                PhoneField(controller: _phone)
              else
                TextFormField(
                  key: const Key('login'),
                  controller: _login,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(hintText: tr('email yoki username')),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return tr('Email yoki foydalanuvchi nomini kiriting');
                    if (s.contains('@') && !validEmail(s)) return tr("Email noto'g'ri");
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              PasswordField(
                key: const Key('password'),
                controller: _pass,
                hint: tr('Parol'),
                onSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').isEmpty ? tr('Parolni kiriting') : null,
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/auth/recovery'),
            child: Text(tr('Parolni unutdingizmi?'), style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w700)),
          ),
        ),
        if (_error != null) ErrorBox(_wait.running ? trf("Juda ko'p urinish. {0} dan keyin qayta urinib ko'ring.", [mmss(_wait.left)]) : _error!),
        const SizedBox(height: 12),
        AuthButton(
          label: _wait.running ? trf('Kuting: {0}', [mmss(_wait.left)]) : tr('Kirish'),
          loading: _loading,
          onPressed: _wait.running ? null : _submit,
        ),
        if (codeAvailable) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _loading || _wait.running ? null : _codeLogin,
              child: Text(_via == 'phone' ? tr('SMS kod bilan kirish') : tr('Email kod bilan kirish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => context.pushReplacement('/auth/register'),
            child: Text(tr("Hisob yo'qmi? Ro'yxatdan o'tish"), style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
        const TermsLink(),
      ],
    );
  }
}
