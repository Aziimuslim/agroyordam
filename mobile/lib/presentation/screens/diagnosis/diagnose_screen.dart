import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

enum _Step { intro, analyzing, error }

/// AI tashxis: ekin/turini tanlash → rasm (kamera yoki galereya) → tahlil → natija ekrani (/diagnosis/:id).
/// `source` = camera | gallery berilsa, ekran ochilishi bilan tanlash oynasi chiqadi (bosh sahifadagi tugmalar).
class DiagnoseScreen extends ConsumerStatefulWidget {
  const DiagnoseScreen({super.key, this.cropId, this.source});
  final String? cropId;
  final String? source;
  @override
  ConsumerState<DiagnoseScreen> createState() => _DiagnoseState();
}

class _DiagnoseState extends ConsumerState<DiagnoseScreen> {
  _Step _step = _Step.intro;
  late String? _cropId = widget.cropId;
  String? _plantId;
  Uint8List? _image;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    final src = switch (widget.source) { 'camera' => ImageSource.camera, 'gallery' => ImageSource.gallery, _ => null };
    if (src != null) WidgetsBinding.instance.addPostFrameCallback((_) => _pick(src));
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _step = _Step.analyzing;
      _error = null;
    });
    try {
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      final d = await ref.read(gardenRepoProvider).diagnose(bytes, name, cropId: _cropId, plantId: _plantId);
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(cropsProvider);
      ref.invalidate(diagnosesProvider);
      if (_cropId != null) {
        ref.invalidate(cropProvider(_cropId!));
        ref.invalidate(cropDiagnosesProvider(_cropId!));
        ref.invalidate(cropHealthProvider(_cropId!));
      }
      if (mounted) context.pushReplacement('/diagnosis/${d.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e);
        _step = _Step.error;
      });
    }
  }

  void _restart() => setState(() {
        _step = _Step.intro;
        _image = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final quota = ref.watch(mySubscriptionProvider).value;
    final overLimit = quota != null && quota.aiDailyLimit != null && quota.aiUsedToday >= quota.aiDailyLimit!;

    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(
          title: 'AI tashxis',
          subtitle: quota != null && quota.aiDailyLimit != null ? 'Bugun: ${quota.aiUsedToday}/${quota.aiDailyLimit} bepul tashxis' : 'Cheksiz · Premium',
        ),
        if (_step == _Step.analyzing && _image != null) _Analyzing(image: _image!),
        if (_step == _Step.error && _error != null) ...[
          if (_image != null) _PhotoPreview(image: _image!),
          _error!.isPaymentRequired
              ? _LimitCard(onUpgrade: () => context.push('/premium'), message: _error!.message)
              : _ErrorCard(message: _error!.message, onRetry: _restart),
        ],
        if (_step == _Step.intro) ...[
          const _ScanHero(),
          const SizedBox(height: 18),
          _TargetPicker(
            cropId: _cropId,
            plantId: _plantId,
            onCrop: (v) => setState(() => _cropId = v),
            onPlant: (v) => setState(() => _plantId = v),
          ),
          const SizedBox(height: 18),
          if (overLimit)
            _LimitCard(onUpgrade: () => context.push('/premium'))
          else ...[
            PillButton(label: 'Rasmga olish', icon: AppIcons.camera, style: PillStyle.primary, block: true, onPressed: () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            PillButton(label: 'Galereyadan tanlash', icon: AppIcons.gallery, style: PillStyle.outline, block: true, onPressed: () => _pick(ImageSource.gallery)),
          ],
          const SizedBox(height: 18),
          const _Tips(),
          const SizedBox(height: 8),
          Text("Yuklangan rasmlar mutaxassis tekshiruvidan so'ng AI'ni yaxshilash uchun anonim ishlatilishi mumkin.",
              textAlign: TextAlign.center, style: TextStyle(color: c.subtle, fontSize: 11.5)),
        ],
      ]),
    );
  }
}

/// Kamera ramkasi illyustratsiyasi (Figma: tashxis natijasidagi "scan" ramkasi).
class _ScanHero extends StatelessWidget {
  const _ScanHero();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F3D27), Color(0xFF2E8B57)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(AppIcons.leaf, size: 92, color: Colors.white.withValues(alpha: 0.22)),
        Icon(AppIcons.scan, size: 150, color: Colors.white.withValues(alpha: 0.9)),
        const Positioned(
          bottom: 14,
          child: Text("Bargni ramka markaziga oling", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
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
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Qaysi ekin?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text("Ekin turini tanlasangiz, AI aniqroq natija beradi", style: TextStyle(color: c.muted, fontSize: 12.5)),
        if (crops.isNotEmpty) ...[
          const FieldLabel("Bog'imdagi ekin"),
          DropdownButtonFormField<String?>(
            initialValue: crops.any((e) => e.id == cropId) ? cropId : null,
            isExpanded: true,
            dropdownColor: c.card,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text("— Bog'imga bog'lamasdan —")),
              for (final cr in crops) DropdownMenuItem<String?>(value: cr.id, child: Text('${cr.name}${cr.plantName != null ? ' · ${cr.plantName}' : ''}')),
            ],
            onChanged: onCrop,
          ),
        ],
        if (cropId == null) ...[
          const FieldLabel('Ekin turi'),
          DropdownButtonFormField<String?>(
            initialValue: plantId,
            isExpanded: true,
            dropdownColor: c.card,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text("Bilmayman — AI o'zi aniqlasin")),
              for (final p in plants) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
            ],
            onChanged: onPlant,
          ),
        ],
      ]),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.image, this.child});
  final Uint8List image;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          child: AspectRatio(
            aspectRatio: 4 / 4.2,
            child: Stack(fit: StackFit.expand, children: [Image.memory(image, fit: BoxFit.cover), if (child != null) child!]),
          ),
        ),
      );
}

/// Tahlil: rasm ustida yurib turuvchi skaner chizig'i.
class _Analyzing extends StatefulWidget {
  const _Analyzing({required this.image});
  final Uint8List image;
  @override
  State<_Analyzing> createState() => _AnalyzingState();
}

class _AnalyzingState extends State<_Analyzing> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(children: [
      _PhotoPreview(
        image: widget.image,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Center(child: Icon(AppIcons.scan, size: 220, color: Colors.white.withValues(alpha: 0.9))),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Align(
              alignment: Alignment(0, -0.8 + 1.6 * _ctrl.value),
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(color: c.gold, boxShadow: [BoxShadow(color: c.gold.withValues(alpha: 0.7), blurRadius: 16)]),
              ),
            ),
          ),
        ]),
      ),
      AppCard(
        child: Row(children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: c.primary)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI tahlil qilmoqda…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text("Barg tekshirilmoqda va bilimlar bazasi bilan solishtirilmoqda", style: TextStyle(color: c.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(AppIcons.alert, color: c.danger, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text("Tahlil qilib bo'lmadi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        Text(message, style: TextStyle(color: c.muted, height: 1.45)),
        const SizedBox(height: 14),
        PillButton(label: 'Qayta urinish', icon: AppIcons.camera, style: PillStyle.primary, block: true, onPressed: onRetry),
      ]),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.onUpgrade, this.message});
  final VoidCallback onUpgrade;
  final String? message;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: context.c.accentSoft, shape: BoxShape.circle),
            child: Icon(AppIcons.star, color: context.c.warning),
          ),
          const SizedBox(height: 10),
          const Text('Bepul limit tugadi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(message ?? "Bugungi bepul AI tashxislardan foydalandingiz. Ertaga qayta urinib ko'ring yoki Premium'ga o'ting.",
              textAlign: TextAlign.center, style: TextStyle(color: context.c.muted)),
          const SizedBox(height: 14),
          PillButton(label: "Premium'ga o'tish", icon: AppIcons.star, style: PillStyle.primary, block: true, onPressed: onUpgrade),
        ]),
      );
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget tip(IconData i, String t, Color bg, Color fg) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(i, size: 18, color: fg)),
            const SizedBox(width: 12),
            Expanded(child: Text(t, style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w600))),
          ]),
        );
    return AppCard(
      color: c.cream2,
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Yaxshi natija uchun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 12),
        tip(AppIcons.sun, "Kunduzgi yorug'likda suratga oling", c.accentSoft, c.warning),
        tip(AppIcons.scan, 'Bitta zararlangan bargni kadr markaziga oling', c.successBg, c.success),
        tip(Icons.back_hand_outlined, 'Kamerani qimirlatmang — rasm xira bo\'lmasin', c.infoBg, c.info),
      ]),
    );
  }
}
