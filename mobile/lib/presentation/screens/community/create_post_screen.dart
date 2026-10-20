import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/photos.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// S13 → "Tahrirlash": post yuklanadi, so'ng forma mavjud qiymatlar bilan ochiladi.
class EditPostRoute extends ConsumerWidget {
  const EditPostRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(postProvider(id));
    return v.when(
      data: (p) => CreatePostScreen(post: p),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageShell(
        padBottom: false,
        child: Column(children: [TopBar(title: tr('Postni tahrirlash')), AsyncView(value: v, data: (_) => const SizedBox.shrink(), onRetry: () => ref.invalidate(postProvider(id)))]),
      ),
    );
  }
}

/// S12 Yangi post / tahrirlash. Tur majburiy, sarlavha 3–100, matn 10–3000, 0–5 rasm (jami ≤ 25 MB).
/// Rasm qisman yuklansa post e'lon qilinmaydi — yuklanmagan rasm belgilanadi, uni olib tashlash yoki qayta urinish mumkin.
/// Ikki marta bosish bitta post; API xatosida matn, tur va rasm yo'qolmaydi; saqlanmagan o'zgarishda dialog.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.post});
  final Post? post;
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostState();
}

class _CreatePostState extends ConsumerState<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.post?.title);
  late final _content = TextEditingController(text: widget.post?.content);
  late String? _category = widget.post?.category;
  late final List<PickedPhoto> _photos = [for (final u in widget.post?.imageUrls ?? const <String>[]) PickedPhoto.url(u)];
  bool _loading = false, _dirty = false, _submitted = false;
  String? _error;

  bool get _editing => widget.post != null;

  /// TZ S12: yangi post qoralamasi — hisob va qurilma bo'yicha lokal (tur, sarlavha, matn; rasmlar saqlanmaydi).
  String get _draftKey => 'post_draft_${ref.read(currentUserProvider)?.id ?? ''}';

  @override
  void initState() {
    super.initState();
    for (final t in [_title, _content]) {
      t.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
        _saveDraft();
      });
    }
    if (!_editing) _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_draftKey);
      if (raw == null || !mounted) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      if ('${d['title'] ?? ''}${d['content'] ?? ''}'.trim().isEmpty) return;
      setState(() {
        _title.text = d['title'] ?? '';
        _content.text = d['content'] ?? '';
        _category = d['category'] as String?;
        _dirty = false;
      });
      showToast(context, tr('Qoralama tiklandi'));
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    if (_editing) return;
    try {
      final p = await SharedPreferences.getInstance();
      if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
        await p.remove(_draftKey);
      } else {
        await p.setString(_draftKey, jsonEncode({'title': _title.text, 'content': _content.text, 'category': _category}));
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_draftKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickPhotos(context, current: _photos);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(picked);
      _dirty = true;
    });
  }

  Future<void> _publish() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_form.currentState?.validate() ?? false) || _category == null) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      // Rasmlar to'liq yuklanmasa post e'lon qilinmaydi (TZ S12); yuklanganlari qayta yuklanmaydi
      final repo0 = ref.read(gardenRepoProvider);
      final ok = await uploadPhotos(_photos, (b, n) => repo0.upload(b, n), () => mounted ? setState(() {}) : null);
      if (!ok) {
        if (mounted) setState(() => _error = tr("Ba'zi rasmlar yuklanmadi. Ularni olib tashlang yoki qayta «Joylash»ni bosing."));
        return;
      }
      final data = {
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'category': _category,
        'image_urls': [for (final p in _photos) p.url!],
      };
      final repo = ref.read(communityRepoProvider);
      final post = _editing ? await repo.updatePost(widget.post!.id, data) : await repo.createPost(data);
      ref.invalidate(feedProvider);
      ref.invalidate(userPostsProvider);
      ref.invalidate(postProvider(post.id));
      if (!_editing) await _clearDraft();
      if (!mounted) return;
      setState(() => _dirty = false);
      showToast(context, _editing ? tr('Saqlandi') : tr('Post joylandi'));
      if (_editing) {
        context.pop();
      } else {
        context.pushReplacement('/community/${post.id}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(t, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
        );
    return PopScope(
      // yangi postda matn qoralamada qoladi — faqat tanlangan rasmlar yo'qolsa yoki tahrirda so'raladi
      canPop: !_dirty || (!_editing && !_photos.any((p) => p.bytes != null)),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, tr("O'zgarishlar saqlanmagan"),
            _editing ? tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi.") : tr("Matn qoralamada qoladi, lekin tanlangan rasmlar saqlanmaydi."),
            ok: tr('Chiqish'), danger: true);
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/help?tab=comm');
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
            TopBar(title: _editing ? tr('Postni tahrirlash') : tr('Yangi post')),
            label(tr('Turi')),
            ChipTabs(
              tabs: [for (final e in postCategoryLabels.entries) (e.key, e.value)],
              selected: _category ?? '',
              onSelect: (v) {
                setState(() {
                  _category = v;
                  _dirty = true;
                });
                _saveDraft();
              },
            ),
            if (_submitted && _category == null) Text(tr('Post turini tanlang'), style: TextStyle(color: c.danger, fontSize: 14)),
            label(tr('Sarlavha')),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr('Masalan: Fitoftorozni qanday yengdim'), errorMaxLines: 2),
              validator: (v) => (v ?? '').trim().length < 3 ? tr("Sarlavha kamida 3 ta belgidan iborat bo'lsin") : null,
            ),
            label(tr('Matn')),
            TextFormField(
              controller: _content,
              maxLines: 7,
              maxLength: 3000,
              decoration: InputDecoration(hintText: tr('Tajribangiz, savolingiz yoki maslahatingiz...'), errorMaxLines: 2),
              validator: (v) => (v ?? '').trim().length < 10 ? tr("Matn kamida 10 ta belgidan iborat bo'lsin") : null,
            ),
            label(trf("Rasmlar (ixtiyoriy, {0} tagacha)", [kMaxPhotos])),
            PhotoPickerGrid(
              photos: _photos,
              onAdd: _loading ? null : _pick,
              onRemove: (i) => setState(() {
                _photos.removeAt(i);
                _dirty = true;
              }),
            ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 15)),
              ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _loading ? null : _publish,
                icon: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary)) : const Icon(AppIcons.send),
                label: Text(_editing ? tr("O'zgarishlarni saqlash") : tr('Joylash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Text(tr("Jamoat qoidalari: hurmat, foydali ma'lumot, reklama va spam taqiqlangan."), style: TextStyle(color: c.muted, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
