import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';
import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'widgets.dart';

/// TZ S12/S16: bitta post yoki xabarda 5 tagacha rasm, har biri ≤ 10 MB, jami ≤ 25 MB.
const kMaxPhotos = 5;
const kMaxPhotoBytes = 10 * 1024 * 1024;
const kMaxPhotosTotal = 25 * 1024 * 1024;

/// Tanlangan rasm: yangi (bayt) yoki serverdagi (url). Yuklangach [url] to'ladi — qayta urinishda qayta yuklanmaydi.
class PickedPhoto {
  PickedPhoto.bytes(Uint8List this.bytes, String this.name);
  PickedPhoto.url(String this.url)
      : bytes = null,
        name = null;
  final Uint8List? bytes;
  final String? name;
  String? url;
  bool uploading = false, failed = false;
  int get size => bytes?.length ?? 0;
  bool get ready => url != null;
}

/// Rasm tanlash xatosining foydalanuvchiga tushunarli sababi (haqiqiy kod bilan — telefonda sinovda aniqlash uchun).
String pickErrorText(Object e) {
  final code = e is PlatformException ? e.code : e.runtimeType.toString();
  return switch (code) {
    'camera_access_denied' => tr("Kameraga ruxsat berilmadi. Galereyadan tanlashingiz mumkin"),
    'photo_access_denied' => tr("Galereyaga ruxsat berilmadi. Telefon sozlamalarida ruxsat bering"),
    'no_available_camera' => tr('Telefonda kamera ilovasi topilmadi. Galereyadan tanlang'),
    'already_active' => tr('Rasm tanlash oynasi hali yopilmagan. Biroz kutib qayta urinib ko\'ring'),
    _ => trf("Rasm tanlab bo'lmadi ({0})", [code]),
  };
}

/// Android: kamera ruxsati ochiq so'raladi (tizim oynasi). Rad etilsa — sababi; butunlay o'chirilgan bo'lsa —
/// telefon sozlamalarini ochish taklifi. true — kamerani ochish mumkin.
Future<bool> ensureCameraPermission(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  var st = await Permission.camera.status;
  if (st.isGranted) return true;
  if (!st.isPermanentlyDenied) st = await Permission.camera.request();
  if (st.isGranted) return true;
  if (!context.mounted) return false;
  if (st.isPermanentlyDenied || st.isRestricted) {
    final open = await confirm(context, tr("Kameraga ruxsat o'chirilgan"),
        tr("Rasmga olish uchun telefon sozlamalarida AgroYordam → Ruxsatlar → Kamera'ni yoqing. Galereyadan tanlash ruxsatsiz ishlaydi."),
        ok: tr('Sozlamalarni ochish'));
    if (open) await openAppSettings();
    return false;
  }
  showToast(context, tr("Kameraga ruxsat berilmadi. Galereyadan tanlashingiz mumkin"));
  return false;
}

/// Bitta rasm (kamera yoki galereya): xato yashirilmaydi — sababi toast bilan aytiladi, null qaytadi.
Future<XFile?> pickOnePhoto(BuildContext context, ImageSource source, {double maxWidth = 1600, int quality = 85}) async {
  if (source == ImageSource.camera && !await ensureCameraPermission(context)) return null;
  if (!context.mounted) return null;
  try {
    return await ImagePicker().pickImage(source: source, maxWidth: maxWidth, imageQuality: quality);
  } catch (e) {
    if (context.mounted) showToast(context, pickErrorText(e));
    return null;
  }
}

/// Galereyadan bir nechta rasm tanlash; chegaralar buzilsa sabab toast bilan aytiladi.
Future<List<PickedPhoto>> pickPhotos(BuildContext context, {required List<PickedPhoto> current}) async {
  final remaining = kMaxPhotos - current.length;
  if (remaining <= 0) return [];
  final picker = ImagePicker();
  final List<XFile> files;
  try {
    files = remaining == 1
        ? [if (await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85) case final f?) f]
        : await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: remaining);
  } catch (e) {
    if (context.mounted) showToast(context, pickErrorText(e));
    return [];
  }
  final out = <PickedPhoto>[];
  var total = current.fold<int>(0, (s, p) => s + p.size);
  String? problem;
  for (final f in files) {
    if (out.length >= remaining) {
      problem = trf("Ko'pi bilan {0} ta rasm", [kMaxPhotos]);
      break;
    }
    final bytes = await f.readAsBytes();
    if (bytes.length > kMaxPhotoBytes) {
      problem = tr("Rasm 10 MB dan katta bo'lmasin");
      continue;
    }
    if (total + bytes.length > kMaxPhotosTotal) {
      problem = tr("Rasmlar jami 25 MB dan oshmasin");
      continue;
    }
    total += bytes.length;
    out.add(PickedPhoto.bytes(bytes, f.name.contains('.') ? f.name : '${f.name}.jpg'));
  }
  if (problem != null && context.mounted) showToast(context, problem);
  return out;
}

/// Hali yuklanmagan rasmlarni ketma-ket yuklaydi. Hammasi yuklansa true; biror rasm xato bo'lsa u belgilanadi.
Future<bool> uploadPhotos(List<PickedPhoto> photos, Future<String> Function(Uint8List bytes, String name) upload, VoidCallback changed) async {
  var ok = true;
  for (final p in photos) {
    if (p.ready) continue;
    p
      ..uploading = true
      ..failed = false;
    changed();
    try {
      p.url = await upload(p.bytes!, p.name!);
    } catch (_) {
      p.failed = true;
      ok = false;
    } finally {
      p.uploading = false;
      changed();
    }
  }
  return ok;
}

/// Tanlangan rasmlar: kichik ko'rinish, olib tashlash, yuklanmagani belgisi va "qo'shish" katagi.
class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({super.key, required this.photos, required this.onRemove, this.onAdd, this.size = 96});
  final List<PickedPhoto> photos;
  final ValueChanged<int> onRemove;
  final VoidCallback? onAdd;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < photos.length; i++)
        Semantics(
          label: [trf('Rasm {0}', [i + 1]), if (photos[i].failed) tr('Yuklanmadi')].join(', '),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photos[i].bytes != null
                    ? Image.memory(photos[i].bytes!, fit: BoxFit.cover)
                    : Image.network(AppConfig.mediaUrl(photos[i].url)!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(color: c.cream2, child: Icon(AppIcons.image, color: c.muted))),
              ),
              if (photos[i].uploading)
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x66000000), borderRadius: BorderRadius.all(Radius.circular(12))),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))),
                ),
              if (photos[i].failed)
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: const Color(0x99000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.danger, width: 2)),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                      Text(tr('Yuklanmadi'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: tr('Rasmni olib tashlash'),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xE6FFFFFF), minimumSize: const Size(36, 36), padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.padded),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF20251B), size: 18),
                  onPressed: photos[i].uploading ? null : () => onRemove(i),
                ),
              ),
            ]),
          ),
        ),
      if (onAdd != null && photos.length < kMaxPhotos)
        Semantics(
          button: true,
          label: trf("Rasm qo'shish ({0}/{1})", [photos.length, kMaxPhotos]),
          excludeSemantics: true,
          child: Material(
            color: c.cream2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.primary, width: 1.5)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onAdd,
              child: SizedBox(
                width: size,
                height: size,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, color: c.primaryDark, size: 28),
                  const SizedBox(height: 4),
                  Text('${photos.length}/$kMaxPhotos', style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Post/xabar rasmlari: 1 — keng, 2 — yonma-yon, 3 — katta + ikkita, 4+ — 2×2 va "+N".
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key, required this.urls, this.onTap, this.label = ''});
  final List<String> urls;
  final ValueChanged<int>? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final n = urls.length;
    if (n == 0) return const SizedBox.shrink();
    Widget tile(int i, {int more = 0}) => _Tile(url: urls[i], index: i, count: n, more: more, label: label, onTap: onTap == null ? null : () => onTap!(i));
    const gap = SizedBox(width: 2, height: 2);
    return switch (n) {
      1 => AspectRatio(aspectRatio: 16 / 10, child: tile(0)),
      2 => AspectRatio(aspectRatio: 2 / 1, child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))])),
      3 => AspectRatio(
          aspectRatio: 16 / 10,
          child: Row(children: [
            Expanded(flex: 2, child: tile(0)),
            gap,
            Expanded(child: Column(children: [Expanded(child: tile(1)), gap, Expanded(child: tile(2))])),
          ]),
        ),
      _ => AspectRatio(
          aspectRatio: 4 / 3,
          child: Column(children: [
            Expanded(child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))])),
            gap,
            Expanded(child: Row(children: [Expanded(child: tile(2)), gap, Expanded(child: tile(3, more: n - 4))])),
          ]),
        ),
    };
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.url, required this.index, required this.count, required this.more, required this.label, this.onTap});
  final String url, label;
  final int index, count, more;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: onTap != null,
      image: true,
      label: [if (label.isNotEmpty) label, trf('Rasm {0}/{1}', [index + 1, count]), if (more > 0) trf('yana {0} ta', [more])].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          Image.network(AppConfig.mediaUrl(url)!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(color: c.cream2, child: Icon(AppIcons.image, color: c.muted, size: 32))),
          if (more > 0)
            ColoredBox(
              color: const Color(0x8C000000),
              child: Center(child: Text('+$more', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
            ),
        ]),
      ),
    );
  }
}

/// To'liq ekranli ko'ruvchi: swipe bilan almashtirish, ikki barmoq/g'ildirak bilan zoom, ←/→ tugmalari va klaviatura.
Future<void> showPhotoViewer(BuildContext context, List<String> urls, {int initial = 0, String label = ''}) => showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _PhotoViewer(urls: urls, initial: initial, label: label),
    );

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.urls, required this.initial, required this.label});
  final List<String> urls;
  final int initial;
  final String label;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pc = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int d) {
    final t = (_i + d).clamp(0, widget.urls.length - 1);
    if (t != _i) _pc.animateToPage(t, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.urls.length;
    final top = MediaQuery.paddingOf(context).top;
    Widget arrow(IconData icon, String tip, int d, bool on) => IconButton(
          tooltip: tip,
          style: IconButton.styleFrom(backgroundColor: const Color(0x66000000), minimumSize: const Size(48, 48)),
          onPressed: on ? () => _go(d) : null,
          icon: Icon(icon, color: on ? Colors.white : Colors.white24),
        );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Stack(children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pc,
              itemCount: n,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Semantics(
                    image: true,
                    label: trf('Rasm {0}/{1}', [i + 1, n]),
                    child: Image.network(AppConfig.mediaUrl(widget.urls[i])!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(AppIcons.image, color: Colors.white54, size: 48)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 72,
            top: top + 14,
            child: Text([if (widget.label.isNotEmpty) widget.label, if (n > 1) '${_i + 1}/$n'].join(' · '),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Positioned(
            top: top + 4,
            right: 8,
            child: IconButton(
              tooltip: tr('Yopish'),
              style: IconButton.styleFrom(backgroundColor: const Color(0x66000000), minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          if (n > 1) ...[
            Positioned(left: 8, top: 0, bottom: 0, child: Center(child: arrow(Icons.chevron_left_rounded, tr('Oldingi rasm'), -1, _i > 0))),
            Positioned(right: 8, top: 0, bottom: 0, child: Center(child: arrow(Icons.chevron_right_rounded, tr('Keyingi rasm'), 1, _i < n - 1))),
          ],
        ]),
      ),
    );
  }
}
