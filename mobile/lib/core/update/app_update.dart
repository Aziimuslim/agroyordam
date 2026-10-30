import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';

/// Ilova ichidan yangilash (faqat Android APK): server `/app/latest` eng so'nggi versiyani aytadi,
/// yangi bo'lsa taklif qilinadi, APK hajmi bo'yicha progress bilan yuklanadi va tizim o'rnatuvchisi ochiladi.
class AppRelease {
  const AppRelease({required this.version, required this.url, this.size, this.notes = ''});
  final String version, url, notes;
  final int? size;

  static AppRelease? fromJson(Map<String, dynamic> j) {
    final v = j['version'], u = j['apk_url'];
    if (v is! String || u is! String || u.isEmpty) return null;
    return AppRelease(version: v, url: u, size: (j['size'] as num?)?.toInt(), notes: (j['notes'] as String?) ?? '');
  }
}

/// "0.8.20" > "0.8.19"? Raqam bo'lmagan qism 0 deb olinadi.
bool isNewerVersion(String remote, String local) {
  List<int> parse(String s) => s.split(RegExp(r'[.+-]')).take(3).map((p) => int.tryParse(p) ?? 0).toList()..addAll([0, 0, 0]);
  final a = parse(remote), b = parse(local);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Ilova yangilanishini qo'llab-quvvatlaydimi (web va boshqa platformalar — yo'q).
bool get appUpdateSupported => !kIsWeb && Platform.isAndroid;

/// MB ko'rinishida: 63,2 MB
String formatMb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';

const _channel = MethodChannel('uz.agroyordam/update');
const _snoozeKey = 'app_update_snooze';

Future<AppRelease?> fetchLatestRelease(Dio api) async {
  final r = await api.get('/app/latest');
  final data = r.data;
  return data is Map<String, dynamic> ? AppRelease.fromJson(data) : null;
}

/// Ilova ochilganda: yangi versiya bo'lsa (va "Keyinroq" bosilganiga 24 soat bo'lmagan bo'lsa) taklif qiladi.
Future<void> checkForUpdateOnStart(Dio api, BuildContext? Function() contextOf) async {
  if (!appUpdateSupported) return;
  try {
    final rel = await fetchLatestRelease(api);
    if (rel == null || !isNewerVersion(rel.version, AppConfig.version)) return;
    final prefs = await SharedPreferences.getInstance();
    final snooze = prefs.getString(_snoozeKey)?.split('|');
    if (snooze != null && snooze.length == 2 && snooze[0] == rel.version) {
      final at = DateTime.fromMillisecondsSinceEpoch(int.tryParse(snooze[1]) ?? 0);
      if (DateTime.now().difference(at) < const Duration(hours: 24)) return;
    }
    final ctx = contextOf();
    if (ctx == null || !ctx.mounted) return;
    final later = await showAppUpdateDialog(ctx, rel);
    if (later) await prefs.setString(_snoozeKey, '${rel.version}|${DateTime.now().millisecondsSinceEpoch}');
  } catch (e) {
    debugPrint('update check: $e'); // tarmoq bo'lmasa — jim, keyingi ochilishda qayta tekshiriladi
  }
}

/// Yangilanish oynasi. true — foydalanuvchi "Keyinroq"ni tanladi.
Future<bool> showAppUpdateDialog(BuildContext context, AppRelease rel) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(rel: rel),
  );
  return r ?? true;
}

enum _Stage { offer, downloading, permission, installing, error }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.rel});
  final AppRelease rel;
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.offer;
  int _received = 0;
  int? _total;
  String? _error;
  CancelToken? _cancel;
  File? _file;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _total = widget.rel.size;
    // Sozlamalardan ruxsat berib qaytganda — o'rnatishni davom ettiramiz
    _life = AppLifecycleListener(onResume: () {
      if (_stage == _Stage.permission) _install();
    });
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _life.dispose();
    super.dispose();
  }

  Future<File> _target() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    await dir.create(recursive: true);
    // Eski versiyalar fayllari joy egallamasin
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('AgroYordam-${widget.rel.version}.apk')) f.deleteSync();
    }
    return File('${dir.path}/AgroYordam-${widget.rel.version}.apk');
  }

  Future<void> _download() async {
    setState(() {
      _stage = _Stage.downloading;
      _received = 0;
      _error = null;
    });
    try {
      final file = await _target();
      final expected = widget.rel.size;
      // Avval to'liq yuklangan bo'lsa — qayta yuklamaymiz
      if (expected != null && await file.exists() && await file.length() == expected) {
        _file = file;
        return _install();
      }
      final part = File('${file.path}.part');
      _cancel = CancelToken();
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60))).download(
        widget.rel.url,
        part.path,
        cancelToken: _cancel,
        onReceiveProgress: (got, total) {
          if (!mounted) return;
          setState(() {
            _received = got;
            if (total > 0) _total = total;
          });
        },
      );
      final len = await part.length();
      if (expected != null && len != expected) throw Exception(tr("Fayl to'liq yuklanmadi"));
      await part.rename(file.path);
      _file = file;
      await _install();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _fail(e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
          ? tr("Internet aloqasi uzildi. Qayta urinib ko'ring")
          : trf("Yuklab bo'lmadi ({0})", ['${e.response?.statusCode ?? e.type.name}']));
    } catch (e) {
      _fail('$e');
    }
  }

  Future<void> _install() async {
    final file = _file;
    if (file == null || !mounted) return;
    try {
      final can = await _channel.invokeMethod<bool>('canInstall') ?? true;
      if (!can) {
        if (mounted) setState(() => _stage = _Stage.permission);
        return;
      }
      if (mounted) setState(() => _stage = _Stage.installing);
      await _channel.invokeMethod('install', {'path': file.path});
    } on PlatformException catch (e) {
      _fail(e.message ?? e.code);
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.error;
      _error = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rel = widget.rel;
    final total = _total;
    final size = total != null ? formatMb(total) : null;
    final progress = total != null && total > 0 ? (_received / total).clamp(0.0, 1.0) : null;
    final muted = TextStyle(fontSize: 14, color: c.muted, height: 1.4);

    final List<Widget> body;
    final List<Widget> actions;
    switch (_stage) {
      case _Stage.offer:
        body = [
          Text(trf('AgroYordam {0} chiqdi.', [rel.version]), style: TextStyle(fontSize: 16, color: c.text, height: 1.4)),
          const SizedBox(height: 4),
          Text(trf("O'rnatilgan: {0}", [AppConfig.version]) + (size != null ? ' · ${trf('Hajmi: {0}', [size])}' : ''), style: muted),
          if (rel.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(child: Text(rel.notes.replaceAll(RegExp(r'^- ', multiLine: true), '• '), style: TextStyle(fontSize: 14, color: c.text, height: 1.4))),
            ),
          ],
          const SizedBox(height: 10),
          Text(tr("Wi‑Fi orqali yuklash tavsiya etiladi. Ma'lumotlaringiz serverda — yangilanishda yo'qolmaydi."), style: muted),
        ];
        actions = [
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Keyinroq'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            onPressed: _download,
            child: Text(size != null ? trf('Yangilash ({0})', [size]) : tr('Yangilash')),
          ),
        ];
      case _Stage.downloading:
        body = [
          Text(tr('Yuklanmoqda…'), style: TextStyle(fontSize: 16, color: c.text, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 10, color: c.primary, backgroundColor: c.cream2),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              total != null && total > 0 ? '${formatMb(_received)} / ${formatMb(total)} · ${((progress ?? 0) * 100).round()}%' : formatMb(_received),
              style: muted,
            ),
          ),
        ];
        actions = [
          TextButton(
            onPressed: () {
              _cancel?.cancel();
              Navigator.pop(context, true);
            },
            child: Text(tr('Bekor qilish')),
          ),
        ];
      case _Stage.permission:
        body = [
          Text(tr("Yangilanish yuklandi. O'rnatish uchun AgroYordam'ga «Noma'lum ilovalarni o'rnatish» ruxsatini bering, so'ng ilovaga qayting."),
              style: TextStyle(fontSize: 15, color: c.text, height: 1.4)),
        ];
        actions = [
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Keyinroq'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            onPressed: () => _channel.invokeMethod('openInstallSettings'),
            child: Text(tr('Ruxsat berish')),
          ),
        ];
      case _Stage.installing:
        body = [
          Text(tr("O'rnatish oynasi ochildi. «O'rnatish» tugmasini bosing — ilova yangilanadi."), style: TextStyle(fontSize: 15, color: c.text, height: 1.4)),
          const SizedBox(height: 8),
          Text(tr("Oyna chiqmasa yoki «Ilova o'rnatilmadi» desa — avval eski ilovani o'chirib, so'ng qayta o'rnating."), style: muted),
        ];
        actions = [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Yopish'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            onPressed: _install,
            child: Text(tr("Qayta o'rnatish")),
          ),
        ];
      case _Stage.error:
        body = [
          Text(_error ?? tr('Xatolik'), style: TextStyle(fontSize: 15, color: c.danger, height: 1.4)),
        ];
        actions = [
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Keyinroq'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            onPressed: _download,
            child: Text(tr('Qayta urinish')),
          ),
        ];
    }
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: c.card,
        title: Row(children: [
          Icon(Icons.system_update_rounded, color: c.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('Yangi versiya'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text))),
        ]),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: body)),
        actions: actions,
      ),
    );
  }
}

/// "Ilova haqida" → "Yangilanishni tekshirish".
Future<void> checkForUpdateManually(BuildContext context, Dio api) async {
  try {
    final rel = await fetchLatestRelease(api);
    if (!context.mounted) return;
    if (rel == null || !isNewerVersion(rel.version, AppConfig.version)) {
      showToast(context, trf("Sizda eng so'nggi versiya: {0}", [AppConfig.version]));
      return;
    }
    await showAppUpdateDialog(context, rel);
  } catch (_) {
    if (context.mounted) showToast(context, tr("Yangilanishni tekshirib bo'lmadi. Internetni tekshiring"));
  }
}
