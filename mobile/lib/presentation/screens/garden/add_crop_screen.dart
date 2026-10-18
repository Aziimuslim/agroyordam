import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'crop_photo.dart';

/// S06 → tahrirlash: ekin serverdan yuklanadi, so'ng forma mavjud qiymatlar bilan ochiladi.
class EditCropRoute extends ConsumerWidget {
  const EditCropRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crop = ref.watch(cropProvider(id));
    return crop.when(
      data: (x) => AddCropScreen(crop: x),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageShell(
        padBottom: false,
        child: Column(children: [
          TopBar(title: tr('Ekinni tahrirlash')),
          AsyncView(value: crop, data: (_) => const SizedBox.shrink(), onRetry: () => ref.invalidate(cropProvider(id))),
        ]),
      ),
    );
  }
}

/// S05 Ekin qo'shish / tahrirlash. Tekshiruv TZ bo'yicha (server ham tekshiradi):
/// nom 2–80, ekin turi majburiy, nav ≤ 80, maydon musbat (vergul/nuqta), sana kelajakda emas,
/// joylashuv ≤ 120, izoh ≤ 1000. Saqlanmagan o'zgarishda chiqishdan oldin so'raladi.
class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key, this.crop, this.plantId});
  final Crop? crop; // berilsa — tahrirlash
  final String? plantId; // katalogdan "Bog'imga qo'shish" (S20)
  @override
  ConsumerState<AddCropScreen> createState() => _AddCropState();
}

class _AddCropState extends ConsumerState<AddCropScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.crop?.name);
  late final _variety = TextEditingController(text: widget.crop?.variety);
  late final _area = TextEditingController(text: _fmtArea(widget.crop?.area));
  late final _location = TextEditingController(text: widget.crop?.location);
  late final _notes = TextEditingController(text: widget.crop?.notes);
  late String? _plantId = widget.crop?.plantId ?? widget.plantId;
  late DateTime? _date = widget.crop?.plantingDate;
  Uint8List? _photo;
  String _photoName = 'crop.jpg';
  bool _removePhoto = false;
  bool _loading = false, _dirty = false, _submitted = false;
  String? _serverError;

  static String? _fmtArea(double? a) => a == null ? null : (a == a.roundToDouble() ? a.toInt().toString() : a.toString());
  bool get _editing => widget.crop != null;

  @override
  void initState() {
    super.initState();
    for (final t in [_name, _variety, _area, _location, _notes]) {
      t.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final t in [_name, _variety, _area, _location, _notes]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) showToast(context, tr('Rasm 10 MB dan katta bo\'lmasin'));
        return;
      }
      setState(() {
        _photo = bytes;
        _photoName = f.name.isEmpty ? 'crop.jpg' : f.name;
        _removePhoto = false;
        _dirty = true;
      });
    } catch (_) {
      // Kamera ruxsati rad etilsa — tizim xatosi emas, galereya muqobil (TZ 4)
      if (mounted) showToast(context, tr("Kameraga ruxsat berilmadi. Galereyadan tanlashingiz mumkin"));
    }
  }

  Future<void> _photoSheet() async {
    final c = context.c;
    final hasPhoto = _photo != null || (!_removePhoto && widget.crop?.photoUrl != null);
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(minTileHeight: 52, leading: const Icon(AppIcons.camera), title: Text(tr('Kamerani ochish')), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(minTileHeight: 52, leading: const Icon(AppIcons.gallery), title: Text(tr('Galereyadan tanlash')), onTap: () => Navigator.pop(ctx, 'gallery')),
          if (hasPhoto)
            ListTile(
              minTileHeight: 52,
              leading: Icon(AppIcons.trash, color: c.danger),
              title: Text(tr('Rasmni olib tashlash'), style: TextStyle(color: c.danger)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    switch (r) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'remove':
        setState(() {
          _photo = null;
          _removePhoto = true;
          _dirty = true;
        });
    }
  }

  String? _areaValue() {
    final t = _area.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (!(_form.currentState?.validate() ?? false) || _plantId == null) return;
    if (_loading) return; // ikki marta bosish bitta ekin yaratadi
    setState(() => _loading = true);
    String? opt(TextEditingController t) => t.text.trim().isEmpty ? null : t.text.trim();
    final data = {
      'name': _name.text.trim(),
      'plant_id': _plantId,
      'variety': opt(_variety),
      'area': _areaValue(),
      'location': opt(_location),
      'notes': opt(_notes),
      'planting_date': _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
    };
    final repo = ref.read(gardenRepoProvider);
    Crop saved;
    try {
      saved = _editing ? await repo.updateCrop(widget.crop!.id, data) : await repo.createCrop(data);
    } catch (e) {
      // Server xatosi formani tozalamaydi (TZ S05)
      if (mounted) {
        final err = ApiException.from(e);
        setState(() {
          _loading = false;
          _serverError = err.message;
        });
        if (err.isPaymentRequired) context.push('/premium');
      }
      return;
    }
    var photoOk = true;
    try {
      if (_photo != null) {
        saved = await repo.uploadCropPhoto(saved.id, _photo!, _photoName);
      } else if (_removePhoto && widget.crop?.photoUrl != null) {
        saved = await repo.deleteCropPhoto(saved.id);
      }
    } catch (_) {
      photoOk = false;
    }
    ref.invalidate(cropsProvider);
    ref.invalidate(cropProvider(saved.id));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _dirty = false;
    });
    if (!photoOk) {
      // Rasm jim yo'qolmaydi: ma'lumot saqlangan, rasmni qayta yuborish taklif qilinadi
      final retry = await confirm(context, tr('Rasm yuklanmadi'),
          tr("Ekin ma'lumotlari saqlandi, lekin rasm yuklanmadi. Rasmni qayta yuborasizmi?"), ok: tr('Qayta urinish'));
      if (retry && mounted) {
        setState(() => _loading = true);
        try {
          await repo.uploadCropPhoto(saved.id, _photo!, _photoName);
          ref.invalidate(cropsProvider);
          ref.invalidate(cropProvider(saved.id));
        } catch (e) {
          if (mounted) showError(context, e);
        }
        if (mounted) setState(() => _loading = false);
      }
      if (!mounted) return;
    }
    showToast(context, _editing ? tr('Saqlandi') : tr("Ekin qo'shildi"));
    if (_editing) {
      context.pop();
    } else {
      context.pushReplacement('/garden/${saved.id}');
    }
  }

  Future<bool> _confirmLeave() => confirm(context, tr("O'zgarishlar saqlanmagan"), tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi."), ok: tr('Chiqish'), danger: true);

  @override
  Widget build(BuildContext context) {
    final plants = ref.watch(plantsProvider);
    final c = context.c;
    final existingUrl = _removePhoto ? null : widget.crop?.photoUrl;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _dirty = false);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(_editing ? '/garden/${widget.crop!.id}' : '/garden');
          }
        }
      },
      child: PageShell(
        padBottom: false,
        maxWidth: 640,
        child: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: _editing ? tr('Ekinni tahrirlash') : tr("Ekin qo'shish")),
            _Label(tr('Ekin rasmi')),
            Row(children: [
              Semantics(
                button: true,
                label: tr("Ekin rasmini qo'shish yoki o'zgartirish"),
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _photoSheet,
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(children: [
                      ClipOval(
                        child: SizedBox(
                          width: 104,
                          height: 104,
                          child: _photo != null
                              ? Image.memory(_photo!, fit: BoxFit.cover)
                              : (existingUrl != null && widget.crop != null
                                  ? CropPhoto(crop: widget.crop!)
                                  : ColoredBox(color: c.oliveSoft, child: Icon(Icons.eco_outlined, color: c.onOliveSoft, size: 40))),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.cream, width: 2)),
                          child: Icon(_photo != null || existingUrl != null ? AppIcons.edit : AppIcons.plus, size: 18, color: c.onPrimary),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_photo != null || existingUrl != null ? tr("Rasmni o'zgartirish") : tr("Rasm qo'shish"),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                  Text(tr('Ekiningizning suratini yuklang (ixtiyoriy). JPG, PNG yoki WEBP, 10 MB gacha'),
                      style: TextStyle(fontSize: 14, color: c.muted, height: 1.35)),
                ]),
              ),
            ]),
            _Label(tr('Ekin nomi')),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Masalan: Issiqxonadagi pomidor'), counterText: ''),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return tr('Ekin nomini kiriting');
                if (t.length < 2) return tr("Nom kamida 2 ta belgidan iborat bo'lsin");
                return null;
              },
            ),
            _Label(tr('Ekin turi')),
            plants.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: list.any((p) => p.id == _plantId) ? _plantId : null,
                isExpanded: true,
                dropdownColor: c.card,
                hint: Text(tr('Katalogdan tanlang')),
                items: [for (final p in list) DropdownMenuItem(value: p.id, child: Text(p.name))],
                validator: (v) => v == null ? tr('Ekin turini tanlang') : null,
                onChanged: (v) {
                  setState(() {
                    _plantId = v;
                    _dirty = true;
                  });
                  if (_name.text.trim().isEmpty && v != null) _name.text = list.firstWhere((p) => p.id == v).name;
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Row(children: [
                Expanded(child: Text(tr("Turlarni yuklab bo'lmadi"), style: TextStyle(color: c.danger))),
                TextButton(onPressed: () => ref.invalidate(plantsProvider), child: Text(tr('Qayta urinish'))),
              ]),
            ),
            _Label(tr('Navi')),
            TextFormField(
              controller: _variety,
              maxLength: 80,
              decoration: InputDecoration(hintText: tr('Masalan: Pushti gigant'), counterText: ''),
            ),
            LayoutBuilder(builder: (context, box) {
              final area = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Label(tr('Maydon (sotix)')),
                TextFormField(
                  controller: _area,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '5'),
                  validator: (_) {
                    final v = _areaValue();
                    if (v == null) return null;
                    final n = double.tryParse(v);
                    return n == null || n <= 0 ? tr('Musbat son kiriting') : null;
                  },
                ),
              ]);
              final date = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Label(tr('Ekilgan sana')),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: now, initialDate: _date ?? now);
                    if (d != null) {
                      setState(() {
                        _date = d;
                        _dirty = true;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(AppIcons.calendar),
                      suffixIcon: _date == null
                          ? null
                          : IconButton(
                              tooltip: tr('Tozalash'),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _date = null;
                                _dirty = true;
                              }),
                            ),
                    ),
                    child: Text(_date == null ? tr('Tanlang') : DateFormat('dd.MM.yyyy').format(_date!),
                        style: TextStyle(fontSize: 16, color: _date == null ? c.muted : c.text)),
                  ),
                ),
              ]);
              if (box.maxWidth < 280) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [area, date]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: area), const SizedBox(width: 12), Expanded(child: date)]);
            }),
            _Label(tr('Joylashuv')),
            TextFormField(
              controller: _location,
              maxLength: 120,
              decoration: InputDecoration(hintText: tr('Masalan: Issiqxona, 2-qator'), counterText: ''),
            ),
            _Label(tr('Izoh (ixtiyoriy)')),
            TextFormField(
              controller: _notes,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(hintText: tr("Masalan: tuproq turi, sug'orish usuli, qo'shimcha ma'lumot...")),
            ),
            if (_serverError != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: c.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_serverError!, style: TextStyle(color: c.danger, fontSize: 15))),
                ]),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                    : const Icon(Icons.eco_outlined),
                label: Text(_editing ? tr("O'zgarishlarni saqlash") : tr('Ekinni saqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.c.text)),
      );
}
