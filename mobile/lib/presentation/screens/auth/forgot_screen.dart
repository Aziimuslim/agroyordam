import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotState();
}

class _ForgotState extends ConsumerState<ForgotPasswordScreen> {
  final _login = TextEditingController(), _token = TextEditingController(), _pass = TextEditingController();
  bool _sent = false, _loading = false;

  Future<void> _send() async {
    setState(() => _loading = true);
    try {
      final devToken = await ref.read(authRepoProvider).forgotPassword(_login.text.trim());
      if (devToken != null) _token.text = devToken; // dev rejimida token avtomatik to'ldiriladi
      setState(() => _sent = true);
      if (mounted) showToast(context, tr('Tiklash kodi yuborildi'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).resetPassword(_token.text.trim(), _pass.text);
      if (mounted) {
        showToast(context, tr('Parol yangilandi. Endi kiring.'));
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: tr('Parolni tiklash')),
        Text(tr('Email, telefon yoki foydalanuvchi nomingizni kiriting'), style: TextStyle(color: context.c.muted)),
        FieldLabel(tr('Login')),
        TextField(controller: _login, decoration: InputDecoration(hintText: tr('email / telefon / username'))),
        if (_sent) ...[
          FieldLabel(tr('Tiklash kodi')),
          TextField(controller: _token, maxLines: 2, decoration: InputDecoration(hintText: tr('SMS/email orqali kelgan kod'))),
          FieldLabel(tr('Yangi parol')),
          TextField(controller: _pass, obscureText: true, decoration: InputDecoration(hintText: tr('Kamida 8 ta belgi'))),
        ],
        const SizedBox(height: 24),
        PillButton(label: _sent ? tr('Parolni yangilash') : tr('Kod yuborish'), block: true, loading: _loading, onPressed: _sent ? _reset : _send),
      ]),
    );
  }
}
