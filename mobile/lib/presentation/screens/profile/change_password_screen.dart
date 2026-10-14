import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';

/// Parolni o'zgartirish (admin bergan vaqtinchalik parolni almashtirish uchun ham).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(), _new = TextEditingController(), _repeat = TextEditingController();
  bool _loading = false, _show = false;

  @override
  void dispose() {
    for (final c in [_current, _new, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).changePassword(_current.text, _new.text);
      if (mounted) {
        showToast(context, tr('Parol almashtirildi. Boshqa qurilmalardagi seanslar tugatildi.'));
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
    final eye = IconButton(
      tooltip: _show ? tr('Parolni yashirish') : tr("Parolni ko'rsatish"),
      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _show = !_show),
    );
    return PageShell(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TopBar(title: tr("Parolni o'zgartirish")),
          NoteBox(
            title: tr('Vaqtinchalik parol berilganmi?'),
            text: tr("Admin bergan parolni «Joriy parol»ga yozing va o'zingiz eslab qoladigan yangi parol qo'ying."),
          ),
          FieldLabel(tr('Joriy parol')),
          TextFormField(
            controller: _current,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(suffixIcon: eye),
            validator: (v) => (v ?? '').isEmpty ? tr('Parolni kiriting') : null,
          ),
          FieldLabel(tr('Yangi parol')),
          TextFormField(
            controller: _new,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(hintText: tr('Kamida 8 ta belgi')),
            validator: (v) => (v ?? '').length < 8 ? tr('Kamida 8 ta belgi') : null,
          ),
          FieldLabel(tr('Yangi parolni takrorlang')),
          TextFormField(
            controller: _repeat,
            obscureText: !_show,
            validator: (v) => v != _new.text ? tr('Parollar mos emas') : null,
          ),
          const SizedBox(height: 24),
          PillButton(label: tr('Saqlash'), style: PillStyle.primary, block: true, loading: _loading, onPressed: _save),
        ]),
      ),
    );
  }
}
