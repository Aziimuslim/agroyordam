import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// S03 jarayoni: tanlash → preview → A01 (yuklanmoqda → tahlil qilinmoqda) → S08 yoki xato.
enum _Step { pick, preview, uploading, analyzing, error }

/// S03 AI tashxis: rasm (kamera yoki galereya) → preview → "Tahlil qilish" → A01 → S08 natija.
/// Ekin turi ixtiyoriy, "Bog'imga bog'lash" — o'z ekinlari ro'yxati. Tanlangan rasm bilan chiqishda tasdiq.
/// `source` = camera | gallery berilsa, ekran ochilishi bilan tanlash oynasi chiqadi.
class DiagnoseScreen extends ConsumerStatefulWidget {
  const DiagnoseScreen({super.key, this.cropId, this.source});
  final String? cropId;
  final String? source;
  @override
  ConsumerState<DiagnoseScreen> createState() => _DiagnoseState();
}

class _DiagnoseState extends ConsumerState<DiagnoseScreen> {
  _Step _step = _Step.pick;
  late String? _cropId = widget.cropId;
  String? _plantId;
  Uint8List? _image;
  String _name = 'leaf.jpg';
  ApiException? _error;
  CancelToken? _cancel;
  Timer? _slow;
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
    final src = switch (widget.source) { 'camera' => ImageSource.camera, 'gallery' => ImageSource.gallery, _ => null };
    if (src != null) WidgetsBinding.instance.addPostFrameCallback((_) => _pick(src));
  }

  @override
  void dispose() {
    _slow?.cancel();
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    } catch (_) {
      // Kamera ruxsati rad etilsa — bu tizim xatosi emas; galereya ishlayveradi (TZ 4, S03)
      if (mounted) showToast(context, tr("Kameraga ruxsat berilmadi. Galereyadan tanlashingiz mumkin"));
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) showToast(context, tr("Rasm 10 MB dan katta bo'lmasin"));
      return;
    }
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      if (mounted) showToast(context, tr('Faqat JPG, PNG yoki WEBP rasm yuklash mumkin'));
      return;
    }
    setState(() {
      _image = bytes;
      _name = file!.name.contains('.') ? file.name : '${file.name}.jpg';
      _step = _Step.preview;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_image == null || _step == _Step.uploading || _step == _Step.analyzing) return; // bitta so'rov
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _step = _Step.uploading;
      _error = null;
      _isSlow = false;
    });
    _slow?.cancel();
    _slow = Timer(const Duration(seconds: 60), () => mounted ? setState(() => _isSlow = true) : null);
    try {
      final d = await ref.read(gardenRepoProvider).diagnose(
            _image!,
            _name,
            cropId: _cropId,
            plantId: _plantId,
            cancel: cancel,
            onUploaded: () {
              if (mounted && _step == _Step.uploading) setState(() => _step = _Step.analyzing);
            },
          );
      _slow?.cancel();
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(cropsProvider);
      ref.invalidate(diagnosesProvider);
      if (_cropId != null) {
        ref.invalidate(cropProvider(_cropId!));
        ref.invalidate(cropDiagnosesProvider(_cropId!));
      }
      // Natija ekrani o'rniga qo'yiladi: Back tahlilni qayta ishga tushirmaydi (TZ S08)
      if (mounted) context.pushReplacement('/diagnosis/${d.id}');
    } catch (e) {
      _slow?.cancel();
      if (!mounted) return;
      if (cancel.isCancelled) {
        setState(() => _step = _Step.preview);
        showToast(context, tr('Yuborish bekor qilindi'));
        return;
      }
      setState(() {
        _error = ApiException.from(e);
        _step = _Step.error;
      });
    }
  }

  void _cancelUpload() => _cancel?.cancel();

  bool get _busy => _step == _Step.uploading || _step == _Step.analyzing;
  bool get _hasImage => _image != null && _step != _Step.pick;

  Future<bool> _confirmLeave() => confirm(context, tr('Rasm tanlangan'), tr("Chiqsangiz, tanlangan rasm tahlil qilinmaydi."), ok: tr('Chiqish'), danger: true);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final quota = ref.watch(mySubscriptionProvider).value;
    final overLimit = quota != null && quota.aiDailyLimit != null && quota.aiUsedToday >= quota.aiDailyLimit!;

    final List<Widget> body = switch (_step) {
      _Step.pick => [
          Semantics(header: true, child: Text(tr('Bargni suratga oling'), style: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w800, color: c.text))),
          const SizedBox(height: 8),
          Text(tr("AI bargdagi o'zgarishlarni tahlil qilib, mumkin bo'lgan sabablarni aniqlashga yordam beradi."),
              style: TextStyle(fontSize: 16, height: 1.45, color: c.muted)),
          const SizedBox(height: 16),
          const _ScanFrame(),
          const SizedBox(height: 16),
          if (overLimit)
            _LimitCard(onUpgrade: () => context.push('/premium'))
          else ...[
            _PrimaryButton(label: tr('Kamerani ochish'), icon: AppIcons.camera, onPressed: () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            _OutlineButton(label: tr('Galereyadan tanlash'), icon: AppIcons.gallery, onPressed: () => _pick(ImageSource.gallery)),
          ],
          const SizedBox(height: 20),
          _TargetPicker(cropId: _cropId, plantId: _plantId, onCrop: (v) => setState(() => _cropId = v), onPlant: (v) => setState(() => _plantId = v)),
          const SizedBox(height: 24),
          const _Tips(),
        ],
      _Step.preview => [
          _Preview(image: _image!),
          const SizedBox(height: 16),
          _TargetPicker(cropId: _cropId, plantId: _plantId, onCrop: (v) => setState(() => _cropId = v), onPlant: (v) => setState(() => _plantId = v)),
          const SizedBox(height: 20),
          if (overLimit)
            _LimitCard(onUpgrade: () => context.push('/premium'))
          else
            _PrimaryButton(label: tr('Tahlil qilish'), icon: Icons.auto_awesome_outlined, onPressed: _analyze),
          const SizedBox(height: 10),
          _OutlineButton(label: tr('Boshqa rasm tanlash'), icon: Icons.refresh_rounded, onPressed: () => setState(() => _step = _Step.pick)),
          const SizedBox(height: 12),
          Text(tr("Yuklangan rasmlar mutaxassis tekshiruvidan so'ng AI'ni yaxshilash uchun anonim ishlatilishi mumkin."),
              textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14)),
        ],
      _Step.uploading || _Step.analyzing => [
          _Preview(image: _image!, scanning: true),
          const SizedBox(height: 16),
          _Progress(uploading: _step == _Step.uploading, slow: _isSlow, onCancel: _step == _Step.uploading ? _cancelUpload : null),
        ],
      _Step.error => [
          if (_image != null) _Preview(image: _image!),
          const SizedBox(height: 16),
          if (_error!.isPaymentRequired)
            _LimitCard(onUpgrade: () => context.push('/premium'), message: _error!.message)
          else
            _ErrorCard(message: _error!.message, onRetry: _analyze, onRepick: () => setState(() => _step = _Step.pick)),
        ],
    };

    return PopScope(
      canPop: !_hasImage || _step == _Step.error,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_busy) {
          showToast(context, _step == _Step.uploading ? tr('Avval yuborishni bekor qiling') : tr("Tahlil yakunlanmoqda, biroz kuting"));
          return;
        }
        if (await _confirmLeave() && context.mounted) {
          setState(() {
            _image = null;
            _step = _Step.pick;
          });
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: PageShell(
        padBottom: false,
        maxWidth: 640,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(
            title: tr('AI tashxis'),
            subtitle: quota == null
                ? null
                : quota.aiDailyLimit != null
                    ? trf('Bugun: {0}/{1} bepul tashxis', [quota.aiUsedToday, quota.aiDailyLimit])
                    : tr('Cheksiz · Premium'),
          ),
          ...body,
        ]),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primaryDark,
          side: BorderSide(color: c.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Kamera ramkasi illyustratsiyasi: mavzu ranglarida barg va skaner burchaklari.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Container(
          decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(16)),
          child: CustomPaint(painter: _FramePainter(c.olive, c.onOliveSoft)),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.corner, this.leaf);
  final Color corner, leaf;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = corner
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.62, height: s.height * 0.72);
    final l = s.height * 0.14;
    for (final (o, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawPath(Path()..moveTo(o.dx, o.dy + l * dy)..lineTo(o.dx, o.dy)..lineTo(o.dx + l * dx, o.dy), p);
    }
    // Barg: ikki yoy + tomir
    final c = s.center(Offset.zero);
    final h = s.height * 0.42, w = h * 0.62;
    final leafPath = Path()
      ..moveTo(c.dx, c.dy - h / 2)
      ..quadraticBezierTo(c.dx + w, c.dy - h * 0.1, c.dx, c.dy + h / 2)
      ..quadraticBezierTo(c.dx - w, c.dy - h * 0.1, c.dx, c.dy - h / 2);
    canvas.drawPath(leafPath, Paint()..color = leaf.withValues(alpha: 0.85));
    canvas.drawLine(Offset(c.dx, c.dy - h * 0.4), Offset(c.dx, c.dy + h * 0.62), Paint()..color = corner..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _FramePainter o) => o.corner != corner || o.leaf != leaf;
}

class _TargetPicker extends ConsumerWidget {
  const _TargetPicker({required this.cropId, required this.plantId, required this.onCrop, required this.onPlant});
  final String? cropId, plantId;
  final ValueChanged<String?> onCrop, onPlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final plants = ref.watch(plantsProvider).value ?? const <Plant>[];
    Widget label(String t, [String? hint]) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: t, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
            if (hint != null) TextSpan(text: ' $hint', style: TextStyle(color: c.muted)),
          ]), style: const TextStyle(fontSize: 15)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (crops.isNotEmpty) ...[
        label(tr("Bog'imga bog'lash"), tr('(ixtiyoriy)')),
        DropdownButtonFormField<String?>(
          initialValue: crops.any((e) => e.id == cropId) ? cropId : null,
          isExpanded: true,
          dropdownColor: c.card,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(tr("— Bog'imga bog'lamasdan —"))),
            for (final cr in crops) DropdownMenuItem<String?>(value: cr.id, child: Text('${cr.name}${cr.plantName != null ? ' · ${cr.plantName}' : ''}')),
          ],
          onChanged: onCrop,
        ),
      ],
      if (cropId == null) ...[
        label(tr('Ekin turi'), tr('(ixtiyoriy)')),
        DropdownButtonFormField<String?>(
          initialValue: plantId,
          isExpanded: true,
          dropdownColor: c.card,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(tr('Avtomatik aniqlash'))),
            for (final p in plants) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
          ],
          onChanged: onPlant,
        ),
      ],
    ]);
  }
}

class _Preview extends StatefulWidget {
  const _Preview({required this.image, this.scanning = false});
  final Uint8List image;
  final bool scanning;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _Preview old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.scanning && !reduce) {
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3.4,
        child: Stack(fit: StackFit.expand, children: [
          Image.memory(widget.image, fit: BoxFit.cover, semanticLabel: tr('Tanlangan barg rasmi')),
          if (widget.scanning) ...[
            const ColoredBox(color: Color(0x40000000)),
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Align(
                alignment: Alignment(0, -0.8 + 1.6 * _ctrl.value),
                child: Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 32), color: c.primaryLight),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// A01 Tahlil jarayoni: foiz o'rniga bosqich nomi (server foiz bermaydi).
class _Progress extends StatelessWidget {
  const _Progress({required this.uploading, required this.slow, this.onCancel});
  final bool uploading, slow;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget stage(String label, bool done, bool active) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 24,
              height: 24,
              child: done
                  ? Icon(Icons.check_circle_rounded, color: c.success)
                  : active
                      ? CircularProgressIndicator(strokeWidth: 2.6, color: c.primary)
                      : Icon(Icons.radio_button_unchecked_rounded, color: c.lineStrong),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: done || active ? c.text : c.muted))),
          ]),
        );
    return Semantics(
      liveRegion: true,
      label: uploading ? tr('Rasm yuklanmoqda') : tr('AI tahlil qilmoqda'),
      child: AppCard(
        margin: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          stage(tr('Rasm yuklanmoqda'), !uploading, uploading),
          stage(tr('AI tahlil qilmoqda'), false, !uploading),
          stage(tr('Natija tayyorlanmoqda'), false, false),
          if (slow) ...[
            const SizedBox(height: 8),
            Text(tr("Jarayon davom etmoqda. Natija tayyor bo'lgach tashxislar tarixida ko'rinadi."),
                style: TextStyle(color: c.warning, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onCancel, child: Text(tr('Bekor qilish')))),
          ],
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry, required this.onRepick});
  final String message;
  final VoidCallback onRetry, onRepick;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(AppIcons.alert, color: c.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(tr("Tahlil qilib bo'lmadi"), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text))),
        ]),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(color: c.muted, height: 1.45, fontSize: 15)),
        const SizedBox(height: 16),
        _PrimaryButton(label: tr('Qayta urinish'), icon: Icons.refresh_rounded, onPressed: onRetry),
        const SizedBox(height: 10),
        _OutlineButton(label: tr('Boshqa rasm tanlash'), icon: AppIcons.camera, onPressed: onRepick),
      ]),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.onUpgrade, this.message});
  final VoidCallback onUpgrade;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(AppIcons.star, color: c.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('Bepul limit tugadi'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: c.text))),
        ]),
        const SizedBox(height: 6),
        Text(message ?? tr("Bugungi bepul AI tashxislardan foydalandingiz. Ertaga qayta urinib ko'ring yoki Premium'ga o'ting."),
            style: TextStyle(color: c.muted, fontSize: 15)),
        const SizedBox(height: 14),
        _PrimaryButton(label: tr("Premium'ga o'tish"), icon: AppIcons.star, onPressed: onUpgrade),
      ]),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tips = [
      (Icons.wb_sunny_outlined, tr("Yorug' joy"), tr("Tabiiy yorug'likda suratga oling")),
      (Icons.center_focus_strong_outlined, tr('Yaqindan'), tr('Bargni yaqinroq olib suratga oling')),
      (Icons.eco_outlined, tr('Bitta barg'), tr("Rasmda bitta barg bo'lsin")),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(tr('Yaxshi natija uchun'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: c.text))),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, (icon, title, text)) in tips.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.oliveSoft, shape: BoxShape.circle),
                child: Icon(icon, color: c.onOliveSoft),
              ),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
              Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.3, color: c.muted)),
            ]),
          ),
        ],
      ]),
    ]);
  }
}
