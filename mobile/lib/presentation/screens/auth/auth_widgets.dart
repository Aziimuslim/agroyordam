import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// Telefonni E.164 ko'rinishiga keltiradi: "90 123 45 67" → "+998901234567". Noto'g'ri bo'lsa null.
String? normalizePhone(String input) {
  final raw = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (raw.isEmpty) return null;
  if (raw.startsWith('+')) return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(raw) ? raw : null;
  if (RegExp(r'^998\d{9}$').hasMatch(raw)) return '+$raw';
  if (RegExp(r'^\d{9}$').hasMatch(raw)) return '+998$raw';
  return null;
}

bool validEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// Telefon maydoni: +998 prefiksi, faqat raqam va bo'sh joy.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, this.onSubmitted, this.errorText, this.autofocus = false});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(17)],
      style: const TextStyle(fontSize: 17),
      textInputAction: TextInputAction.next,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: '90 123 45 67',
        errorText: errorText,
        errorMaxLines: 2,
        prefixIcon: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 14), child: Text('+998', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: c.text))),
      ),
      validator: (v) => normalizePhone(v ?? '') == null ? tr("Telefon raqamini to'liq kiriting: 90 123 45 67") : null,
    );
  }
}

/// Parol maydoni: o'z "ko'z" tugmasi; parol hech qayerga saqlanmaydi.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.hint, this.validator, this.onSubmitted, this.newPassword = false, this.action = TextInputAction.done});
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final bool newPassword;
  final TextInputAction action;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: !_show,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: widget.action,
        onFieldSubmitted: widget.onSubmitted,
        style: const TextStyle(fontSize: 17),
        inputFormatters: [LengthLimitingTextInputFormatter(128)],
        decoration: InputDecoration(
          hintText: widget.hint,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: _show ? tr('Parolni yashirish') : tr("Parolni ko'rsatish"),
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
        validator: widget.validator,
      );
}

/// Yangi parol qoidasi (TZ S28 bilan bir xil): 8–128 belgi.
String? newPasswordRule(String? v) {
  final p = v ?? '';
  if (p.length < 8) return tr('Kamida 8 ta belgi');
  if (p.length > 128) return tr("Ko'pi bilan 128 ta belgi");
  return null;
}

/// Xato qutisi (kiritilgan ma'lumot saqlanadi).
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline_rounded, color: c.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: c.danger, fontSize: 15))),
        ]),
      ),
    );
  }
}

/// Soniyalarni teskari sanaydi (qurilma soatiga bog'liq emas — Stopwatch). Server baribir o'z vaqtini tekshiradi.
class Countdown {
  Countdown(this.onTick);
  final VoidCallback onTick;
  Timer? _t;
  final _sw = Stopwatch();
  int _total = 0;

  int get left => (_total - _sw.elapsed.inSeconds).clamp(0, _total);
  bool get running => left > 0;

  void start(int seconds) {
    _t?.cancel();
    _total = seconds;
    _sw
      ..reset()
      ..start();
    if (seconds <= 0) return;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      onTick();
      if (left <= 0) _t?.cancel();
    });
  }

  void dispose() => _t?.cancel();
}

String mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Auth sahifalari qolipi: sarlavha, til tugmasi, tor ustun.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.title, this.subtitle, required this.children, this.showBack = true});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageShell(
      maxWidth: 480,
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: '', showBack: showBack, actions: [
          TextButton.icon(
            onPressed: () => context.push('/settings/language'),
            icon: Icon(Icons.translate_rounded, color: c.text, size: 20),
            label: Text(I18n.lang.short, style: TextStyle(color: c.text, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text))),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 15, height: 1.4)),
        ],
        const SizedBox(height: 18),
        ...children,
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Asosiy tugma (52 px, yuklanish holati bilan).
class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Qoidalar havolasi (A05) — joriy forma yo'qolmaydi (push).
class TermsLink extends StatelessWidget {
  const TermsLink({super.key, this.text});
  final String? text;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.push('/settings/about'),
        child: Text(text ?? tr('Ilova qoidalari va maxfiylik'), textAlign: TextAlign.center, style: TextStyle(color: context.c.muted, fontSize: 14, decoration: TextDecoration.underline)),
      );
}
