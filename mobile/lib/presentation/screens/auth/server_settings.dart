import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// Server manzilini sozlash (telefonda backend kompyuterda ishlaganda: http://192.168.x.x:8000).
Future<void> showServerSettings(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController(text: AppConfig.apiUrl);
  await showSheet(context, title: 'Server manzili', builder: (ctx) => _ServerForm(ctrl: ctrl, ref: ref));
}

class _ServerForm extends StatefulWidget {
  const _ServerForm({required this.ctrl, required this.ref});
  final TextEditingController ctrl;
  final WidgetRef ref;
  @override
  State<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  String? _status;
  bool _ok = false, _loading = false;

  String get _url => widget.ctrl.text.trim().replaceAll(RegExp(r'/+$'), '');

  Future<void> _check() async {
    setState(() => _loading = true);
    try {
      final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 6), receiveTimeout: const Duration(seconds: 6))).get('$_url/health');
      _ok = r.data is Map && r.data['status'] != null;
      _status = _ok ? 'Server bilan aloqa bor (versiya ${r.data['version']})' : 'Javob noto\'g\'ri';
    } catch (_) {
      _ok = false;
      _status = "Serverga ulanib bo'lmadi. Manzil va Wi-Fi tarmog'ini tekshiring.";
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefsKey, _url);
    AppConfig.runtimeOverride = _url;
    widget.ref.invalidate(apiClientProvider);
    if (mounted) {
      Navigator.pop(context);
      showToast(context, 'Server manzili saqlandi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Backend (FastAPI) ishlayotgan kompyuterning manzili. Telefon va kompyuter bitta Wi-Fi\'da bo\'lishi kerak.',
          style: TextStyle(color: c.muted, fontSize: 13)),
      const SizedBox(height: 12),
      TextField(controller: widget.ctrl, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'http://192.168.1.10:8000')),
      if (_status != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_status!, style: TextStyle(color: _ok ? c.success : c.danger, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: PillButton(label: 'Tekshirish', style: PillStyle.outline, block: true, loading: _loading, onPressed: _check)),
        const SizedBox(width: 10),
        Expanded(child: PillButton(label: 'Saqlash', block: true, onPressed: _save)),
      ]),
    ]);
  }
}
