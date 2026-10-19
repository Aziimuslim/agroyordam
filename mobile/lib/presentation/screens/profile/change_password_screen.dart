import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';

/// S28 Parolni o'zgartirish. Har maydonda o'z "ko'z" tugmasi; 8–128 belgi; yangi parol joriydan farq qiladi;
/// "boshqa qurilmalardan chiqish" — ixtiyoriy (standart o'chiq). Muvaffaqiyatda maydonlar tozalanadi.
/// Parol hech qayerga (qoralama, log) yozilmaydi.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController(), _new = TextEditingController(), _repeat = TextEditingController();
  final _show = [false, false, false];
  bool _loading = false, _logoutOthers = false, _submitted = false, _done = false;
  String? _error;

  bool get _dirty => _current.text.isNotEmpty || _new.text.isNotEmpty || _repeat.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final t in [_current, _new, _repeat]) {
      t.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _new, _repeat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear() {
    for (final c in [_current, _new, _repeat]) {
      c.clear();
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_form.currentState!.validate() || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepoProvider).changePassword(_current.text, _new.text, logoutOthers: _logoutOthers);
      _clear();
      if (!mounted) return;
      setState(() => _done = true);
      await WidgetsBinding.instance.endOfFrame; // PopScope yangi holatni olsin
      if (!mounted) return;
      showToast(context, _logoutOthers ? tr('Parol almashtirildi. Boshqa qurilmalardagi seanslar tugatildi.') : tr('Parol almashtirildi'));
      context.pop();
    } catch (e) {
      // Server matni ko'rsatiladi (masalan, "Joriy parol noto'g'ri"); parol qiymati hech qayerga yozilmaydi
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Yordamchi baho — qoida o'rnini bosmaydi (TZ S28).
  (int, String) _strength(String p) {
    if (p.isEmpty) return (0, '');
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[a-zа-я]').hasMatch(p) && RegExp(r'[A-ZА-Я]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    final level = score <= 2 ? 1 : (score <= 3 ? 2 : 3);
    return (level, [tr('Kuchsiz'), tr("O'rtacha"), tr('Kuchli')][level - 1]);
  }

  Widget _field(int i, TextEditingController ctrl, String label, {String? Function(String?)? validator, List<String>? hints}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FieldLabel(label),
      TextFormField(
        controller: ctrl,
        obscureText: !_show[i],
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: hints,
        maxLength: 128,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          counterText: '',
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: _show[i] ? tr('Parolni yashirish') : tr("Parolni ko'rsatish"),
            icon: Icon(_show[i] ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show[i] = !_show[i]),
          ),
        ),
        validator: validator,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (level, label) = _strength(_new.text);
    final color = [c.muted, c.danger, c.warning, c.success][level];
    return PopScope(
      canPop: !_dirty || _loading || _done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, tr('Chiqasizmi?'), tr("Kiritilgan parollar saqlanmaydi."), ok: tr('Chiqish'), danger: true);
        if (leave && context.mounted) {
          _clear();
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/profile');
          }
        }
      },
      child: PageShell(
        maxWidth: 640,
        padBottom: false,
        child: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TopBar(title: tr("Parolni o'zgartirish")),
              NoteBox(
                title: tr('Vaqtinchalik parol berilganmi?'),
                text: tr("Admin bergan parolni «Joriy parol»ga yozing va o'zingiz eslab qoladigan yangi parol qo'ying."),
              ),
              _field(0, _current, tr('Joriy parol'),
                  hints: const [AutofillHints.password], validator: (v) => (v ?? '').isEmpty ? tr('Parolni kiriting') : null),
              _field(1, _new, tr('Yangi parol'), hints: const [AutofillHints.newPassword], validator: (v) {
                final p = v ?? '';
                if (p.length < 8) return tr('Kamida 8 ta belgi');
                if (p.length > 128) return tr("Ko'pi bilan 128 ta belgi");
                if (p == _current.text) return tr('Yangi parol joriy paroldan farq qilishi kerak');
                return null;
              }),
              if (_new.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Semantics(
                  label: trf('Parol kuchi: {0}', [label]),
                  excludeSemantics: true,
                  child: Row(children: [
                    for (var i = 1; i <= 3; i++) ...[
                      Expanded(child: Container(height: 6, decoration: BoxDecoration(color: i <= level ? color : c.cream2, borderRadius: BorderRadius.circular(3)))),
                      const SizedBox(width: 6),
                    ],
                    Text(label, style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
              _field(2, _repeat, tr('Yangi parolni takrorlang'),
                  hints: const [AutofillHints.newPassword], validator: (v) => v != _new.text ? tr('Parollar mos emas') : null),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _logoutOthers,
                onChanged: (v) => setState(() => _logoutOthers = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(tr('Boshqa qurilmalardan chiqish'), style: TextStyle(fontSize: 16, color: c.text)),
                subtitle: Text(tr('Shu qurilmadagi seans saqlanadi'), style: TextStyle(fontSize: 13.5, color: c.muted)),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 15)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                      : Text(tr('Saqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}
