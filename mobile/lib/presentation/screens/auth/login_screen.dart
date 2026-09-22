import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.via = 'email'});
  final String via;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false, _obscure = true;

  bool get _phone => widget.via == 'phone';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      var login = _login.text.trim();
      if (_phone && !login.startsWith('+')) login = '+998${login.replaceAll(' ', '')}';
      await ref.read(authProvider.notifier).login(login, _pass.text);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TopBar(title: ''),
          const SizedBox(height: 30),
          Text(_phone ? 'Telefon raqamingiz bilan kiring' : 'Hisobingizga kiring', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_phone ? 'Ro\'yxatdan o\'tgan raqam va parolni kiriting' : 'Email yoki foydalanuvchi nomi va parol',
              style: TextStyle(color: c.muted, fontSize: 14)),
          const SizedBox(height: 22),
          TextFormField(
            key: const Key('login'),
            controller: _login,
            keyboardType: _phone ? TextInputType.phone : TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: _phone ? '90 123 45 67' : 'email yoki username',
              prefixIcon: _phone
                  ? Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: Text('+998', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)))
                  : null,
            ),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Maydonni to\'ldiring' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('password'),
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Parol',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: c.muted),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.isEmpty) ? 'Parolni kiriting' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot'),
              child: Text('Parolni unutdingizmi?', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 18),
          PillButton(label: 'Kirish', block: true, loading: _loading, onPressed: _submit),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => context.pushReplacement('/register'),
              child: Text("Hisob yo'qmi? Ro'yxatdan o'tish", style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
