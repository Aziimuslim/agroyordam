import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds.dart';
import '../../../domain/entities/entities.dart';

/// TZ S24/S35: telefon yoki email'ni o'zgartirish — kod yangi manzilga yuboriladi, tasdiqlangach profil yangilanadi.
/// Qayta yuborish taymeri, qolgan urinishlar, eskirgan kod — S35 qoidalari bilan. true — o'zgardi.
Future<bool> showContactChange(BuildContext context, {required String channel}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.c.card,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ContactSheet(channel: channel),
  );
  return ok ?? false;
}

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.channel});
  final String channel;
  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _dest = TextEditingController();
  final _code = TextEditingController();
  Challenge? _ch;
  String? _error;
  bool _busy = false;
  int _wait = 0;
  Timer? _timer;

  bool get _sms => widget.channel == 'sms';

  @override
  void dispose() {
    _timer?.cancel();
    _dest.dispose();
    _code.dispose();
    super.dispose();
  }

  void _countdown(int s) {
    _timer?.cancel();
    setState(() => _wait = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _wait <= 1) {
        t.cancel();
        if (mounted) setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _request() async {
    final d = _dest.text.trim();
    if (d.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ch = await ref.read(authRepoProvider).requestContact(widget.channel, d);
      if (!mounted) return;
      setState(() => _ch = ch);
      _countdown(ch.resendIn);
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final ch = _ch;
    if (ch == null || _wait > 0) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(authRepoProvider).resend(ch.id);
      if (!mounted) return;
      setState(() {
        _ch = n;
        _error = null;
        _code.clear();
      });
      _countdown(n.resendIn);
    } catch (e) {
      final err = ApiException.from(e);
      if (mounted) setState(() => _error = err.message);
      if (err.retryAfter != null) _countdown(err.retryAfter!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final ch = _ch;
    if (ch == null || _code.text.trim().length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepoProvider).verifyContact(ch.id, _code.text.trim());
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      setState(() => _error = err.attemptsLeft != null ? '${err.message}. ${trf('Qolgan urinishlar: {0}', [err.attemptsLeft])}' : err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ch = _ch;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_sms ? tr('Telefon raqamini o\'zgartirish') : tr("Email'ni o'zgartirish"),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 6),
          Text(
            ch == null
                ? (_sms ? tr('Yangi raqamga tasdiqlash kodi yuboriladi.') : tr('Yangi manzilga tasdiqlash kodi yuboriladi.'))
                : trf('Kod {0} ga yuborildi.', [ch.destinationMasked]),
            style: TextStyle(fontSize: 15, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (ch == null)
            TextField(
              controller: _dest,
              autofocus: true,
              keyboardType: _sms ? TextInputType.phone : TextInputType.emailAddress,
              style: const TextStyle(fontSize: 16),
              onSubmitted: (_) => _request(),
              decoration: InputDecoration(hintText: _sms ? '+998 90 123 45 67' : 'pochta@misol.uz'),
            )
          else ...[
            if (ch.devCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NoteBox(title: tr('Sinov rejimi'), text: trf("SMS/email yuborilmaydi. Sinov kodi: {0}", [ch.devCode]), icon: Icons.science_outlined),
              ),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) _verify();
              },
              decoration: InputDecoration(hintText: '••••••', counterText: '', labelText: tr('6 xonali kod')),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _wait > 0 || _busy ? null : _resend,
                child: Text(_wait > 0 ? trf('Qayta yuborish: {0} s', [_wait]) : tr('Kodni qayta yuborish')),
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 15))),
            ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
              onPressed: _busy ? null : (ch == null ? _request : (_code.text.trim().length == 6 ? _verify : null)),
              child: _busy
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                  : Text(ch == null ? tr('Kod yuborish') : tr('Tasdiqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
