import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

final regions = uzRegions.keys.toList();

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _user = TextEditingController(), _email = TextEditingController();
  final _phone = TextEditingController(), _pass = TextEditingController();
  String? _region;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final phone = _phone.text.replaceAll(' ', '');
      await ref.read(authProvider.notifier).register(
            fullName: _name.text,
            username: _user.text,
            email: _email.text,
            phone: phone.isEmpty ? null : (phone.startsWith('+') ? phone : '+998$phone'),
            password: _pass.text,
            region: _region,
          );
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
          TopBar(title: tr("Ro'yxatdan o'tish")),
          Text(tr("Bir daqiqada hisob yarating va ekinlaringizni kuzatishni boshlang"), style: TextStyle(color: c.muted)),
          FieldLabel(tr("To'liq ism")),
          TextFormField(controller: _name, decoration: InputDecoration(hintText: tr('Masalan: Aziz Karimov')),
              validator: (v) => (v ?? '').trim().length < 2 ? tr('Ismni kiriting') : null),
          FieldLabel(tr('Foydalanuvchi nomi')),
          TextFormField(controller: _user, decoration: const InputDecoration(hintText: 'aziz_fermer'),
              validator: (v) => RegExp(r'^[A-Za-z0-9_.]{3,50}$').hasMatch(v ?? '') ? null : tr('Kamida 3 ta lotin harf/raqam')),
          FieldLabel(tr('Email')),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'email@misol.uz'),
              validator: (v) {
                if ((v ?? '').isEmpty && _phone.text.isEmpty) return tr('Email yoki telefon kerak');
                if ((v ?? '').isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!)) return tr("Email noto'g'ri");
                return null;
              }),
          FieldLabel(tr('Telefon (ixtiyoriy)')),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: InputDecoration(hintText: '90 123 45 67', prefixIcon: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: Text('+998', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)))),
              validator: (v) => (v ?? '').isEmpty || RegExp(r'^\+?[0-9 ]{9,15}$').hasMatch(v!) ? null : tr("Raqam noto'g'ri")),
          FieldLabel(tr('Viloyat')),
          DropdownButtonFormField<String>(
            initialValue: _region,
            isExpanded: true,
            hint: Text(tr('Tanlang')),
            dropdownColor: c.card,
            items: [for (final r in regions) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _region = v),
          ),
          FieldLabel(tr('Parol')),
          TextFormField(controller: _pass, obscureText: true, decoration: InputDecoration(hintText: tr('Kamida 8 ta belgi')),
              validator: (v) => (v ?? '').length < 8 ? tr('Kamida 8 ta belgi') : null),
          const SizedBox(height: 24),
          PillButton(label: tr("Ro'yxatdan o'tish"), block: true, loading: _loading, onPressed: _submit),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.pushReplacement('/login'),
              child: Text(tr('Hisobingiz bormi? Kirish'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
