import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../catalog/catalog_common.dart';

const _maxImages = 5;
const _maxTotalBytes = 25 * 1024 * 1024;

/// Kundalik yozuvi kartasi: sana, matn, rasmlar; o'z yozuvi — tahrirlash/o'chirish.
class DiaryTile extends ConsumerWidget {
  const DiaryTile({super.key, required this.cropId, required this.log, this.editable = true});
  final String cropId;
  final CropLog log;
  final bool editable;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(context, tr("Yozuvni o'chirasizmi?"), log.content.isEmpty ? tr('Rasmli kuzatuv') : log.content, ok: tr("O'chirish"), danger: true)) return;
    try {
      await ref.read(gardenRepoProvider).deleteLog(cropId, log.id);
      ref.invalidate(cropLogsProvider(cropId));
      if (context.mounted) showToast(context, tr("Yozuv o'chirildi"));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_note_outlined, color: c.olive, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text([formatDate(log.date), if (log.edited) tr('tahrirlangan')].join(' · '),
                style: TextStyle(fontSize: 14, color: c.muted, fontWeight: FontWeight.w700)),
          ),
          if (editable)
            PopupMenuButton<String>(
              tooltip: tr('Amallar'),
              icon: Icon(Icons.more_vert_rounded, color: c.muted),
              onSelected: (v) => v == 'edit' ? context.push('/garden/$cropId/log', extra: log) : _delete(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(tr('Tahrirlash'))),
                PopupMenuItem(value: 'delete', child: Text(tr("O'chirish"))),
              ],
            ),
        ]),
        if (log.content.isNotEmpty)
          Padding(padding: const EdgeInsets.only(right: 10, top: 2), child: Text(log.content, style: TextStyle(fontSize: 15.5, height: 1.45, color: c.text))),
        if (log.images.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: log.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Semantics(
                button: true,
                label: trf('Rasm {0}', [i + 1]),
                child: GestureDetector(
                  onTap: () => showImageViewer(context, url: AppConfig.mediaUrl(log.images[i]), label: formatDate(log.date)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(AppConfig.mediaUrl(log.images[i])!, width: 84, height: 84, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 84, height: 84, color: c.cream2, child: Icon(Icons.broken_image_outlined, color: c.muted))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Pick {
  _Pick.remote(this.url) : bytes = null, name = '';
  _Pick.local(this.bytes, this.name) : url = null;
  final String? url;
  final Uint8List? bytes;
  final String name;
  int get size => bytes?.length ?? 0;
}

/// A04 Kuzatuv yozish/tahrirlash: sana (kelajak emas), matn 0–2000, 5 tagacha rasm (jami 25 MB). Matn yoki
/// kamida bitta rasm shart. Saqlash tashxisga aylanmaydi. Boshqa joyda o'zgargan bo'lsa (409) — ochiq xabar.
class LogEditorScreen extends ConsumerStatefulWidget {
  const LogEditorScreen({super.key, required this.cropId, this.log});
  final String cropId;
  final CropLog? log;
  @override
  ConsumerState<LogEditorScreen> createState() => _LogEditorState();
}

class _LogEditorState extends ConsumerState<LogEditorScreen> {
  late final _text = TextEditingController(text: widget.log?.content ?? '');
  late DateTime _date = widget.log?.date ?? DateTime.now();
  late final List<_Pick> _images = [for (final u in widget.log?.images ?? const <String>[]) _Pick.remote(u)];
  bool _dirty = false, _saving = false, _done = false, _submitted = false;
  String? _error;

  bool get _editing => widget.log != null;
  int get _total => _images.fold(0, (s, p) => s + p.size);

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (!_dirty) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final left = _maxImages - _images.length;
    if (left <= 0) return;
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85, limit: left);
    if (files.isEmpty) return;
    var total = _total;
    final added = <_Pick>[];
    for (final f in files.take(left)) {
      final bytes = await f.readAsBytes();
      if (total + bytes.length > _maxTotalBytes) {
        if (mounted) showToast(context, tr("Rasmlar jami 25 MB dan oshmasin"));
        break;
      }
      total += bytes.length;
      added.add(_Pick.local(bytes, f.name.contains('.') ? f.name : '${f.name}.jpg'));
    }
    setState(() {
      _images.addAll(added);
      _dirty = true;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (d != null) {
      setState(() {
        _date = d;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_text.text.trim().isEmpty && _images.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);
    final repo = ref.read(gardenRepoProvider);
    try {
      // Rasmlar avval yuklanadi; bittasi yuklanmasa yozuv saqlanmaydi va forma o'zgarmaydi
      final urls = <String>[];
      for (final p in _images) {
        urls.add(p.url ?? await repo.upload(p.bytes!, p.name, folder: 'crops'));
      }
      await repo.saveLog(widget.cropId,
          logId: widget.log?.id, version: widget.log?.version, content: _text.text.trim(), images: urls, observedAt: _date);
      ref.invalidate(cropLogsProvider(widget.cropId));
      if (!mounted) return;
      setState(() => _done = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      showToast(context, tr('Kuzatuv saqlandi'));
      context.pop();
    } catch (e) {
      final err = ApiException.from(e);
      if (mounted) setState(() => _error = err.statusCode == 409 ? tr("Bu yozuv boshqa joyda o'zgartirilgan. Orqaga qaytib, yangilangan holatini qayta tahrirlang.") : err.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final empty = _submitted && _text.text.trim().isEmpty && _images.isEmpty;
    return PopScope(
      canPop: !_dirty || _done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirm(context, tr("O'zgarishlar saqlanmagan"), tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi."), ok: tr('Chiqish'), danger: true) && context.mounted) {
          setState(() => _done = true);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) context.canPop() ? context.pop() : context.go('/garden/${widget.cropId}?tab=diary');
        }
      },
      child: PageShell(
        maxWidth: 640,
        padBottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(title: _editing ? tr('Kuzatuvni tahrirlash') : tr('Kuzatuv yozish')),
          FieldLabel(tr('Kuzatuv sanasi')),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), alignment: Alignment.centerLeft, foregroundColor: c.text, side: BorderSide(color: c.lineStrong)),
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(formatDate(_date), style: const TextStyle(fontSize: 16)),
          ),
          FieldLabel(tr('Nimani kuzatdingiz?')),
          TextField(
            controller: _text,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(hintText: tr("Barglar, sug'orish, o'g'itlash, hosil...")),
          ),
          FieldLabel(trf('Rasmlar ({0}/{1})', [_images.length, _maxImages])),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < _images.length; i++)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _images[i].bytes != null
                      ? Image.memory(_images[i].bytes!, width: 96, height: 96, fit: BoxFit.cover)
                      : Image.network(AppConfig.mediaUrl(_images[i].url)!, width: 96, height: 96, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 96, height: 96, color: c.cream2)),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    tooltip: tr('Rasmni olib tashlash'),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xE6FFFFFF), minimumSize: const Size(36, 36), padding: EdgeInsets.zero),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF20251B)),
                    onPressed: () => setState(() {
                      _images.removeAt(i);
                      _dirty = true;
                    }),
                  ),
                ),
              ]),
            if (_images.length < _maxImages)
              Semantics(
                button: true,
                label: tr("Rasm qo'shish"),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pick,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary, width: 1.5)),
                    child: Icon(Icons.add_a_photo_outlined, color: c.primaryDark),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(tr("5 tagacha rasm, jami 25 MB gacha. Kuzatuv tashxis emas — ekin holatini o'zgartirmaydi."), style: TextStyle(fontSize: 13.5, color: c.muted)),
          if (empty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('Matn yozing yoki kamida bitta rasm qo\'shing'), style: TextStyle(color: c.danger, fontSize: 14))),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 15)),
            ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary))
                  : Text(tr('Saqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
