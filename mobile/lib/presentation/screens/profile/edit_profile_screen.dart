import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../auth/register_screen.dart' show regions;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  late final user = ref.read(currentUserProvider)!;
  late final _name = TextEditingController(text: user.fullName);
  late final _email = TextEditingController(text: user.email);
  late final _phone = TextEditingController(text: user.phone);
  late String? _region = regions.contains(user.region) ? user.region : null;
  bool _loading = false;

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).updateProfile({
        'full_name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'region': _region,
      });
      if (mounted) {
        showToast(context, 'Saqlandi');
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
        const TopBar(title: 'Profilni tahrirlash'),
        const FieldLabel("To'liq ism"),
        TextField(controller: _name),
        const FieldLabel('Email'),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress),
        const FieldLabel('Telefon'),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+998901234567')),
        const FieldLabel('Viloyat'),
        DropdownButtonFormField<String>(
          initialValue: _region,
          isExpanded: true,
          dropdownColor: context.c.card,
          items: [for (final r in regions) DropdownMenuItem(value: r, child: Text(r))],
          onChanged: (v) => setState(() => _region = v),
        ),
        const SizedBox(height: 24),
        PillButton(label: 'Saqlash', block: true, loading: _loading, onPressed: _save),
      ]),
    );
  }
}
