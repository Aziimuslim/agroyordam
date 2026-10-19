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
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
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

/// S12 Yangi post / tahrirlash. Tur majburiy, sarlavha 3–100, matn 10–3000, 1 ta rasm (backend bitta rasm saqlaydi).
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
  Uint8List? _image;
  String _imageName = 'post.jpg';
  late String? _existingUrl = widget.post?.imageUrl;
  bool _loading = false, _dirty = false, _submitted = false;
  String? _error;

  bool get _editing => widget.post != null;

  @override
  void initState() {
    super.initState();
    for (final t in [_title, _content]) {
      t.addListener(() => _dirty ? null : setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) showToast(context, tr("Rasm 10 MB dan katta bo'lmasin"));
      return;
    }
    setState(() {
      _image = bytes;
      _imageName = f.name.contains('.') ? f.name : '${f.name}.jpg';
      _existingUrl = null;
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
      String? url = _existingUrl;
      // Rasm to'liq yuklanmasa post e'lon qilinmaydi (TZ S12)
      if (_image != null) url = await ref.read(gardenRepoProvider).upload(_image!, _imageName);
      final data = {'title': _title.text.trim(), 'content': _content.text.trim(), 'category': _category, 'image_url': url};
      final repo = ref.read(communityRepoProvider);
      final post = _editing ? await repo.updatePost(widget.post!.id, data) : await repo.createPost(data);
      ref.invalidate(feedProvider);
      ref.invalidate(userPostsProvider);
      ref.invalidate(postProvider(post.id));
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
    final hasImage = _image != null || _existingUrl != null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, tr("O'zgarishlar saqlanmagan"), tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi."), ok: tr('Chiqish'), danger: true);
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
              onSelect: (v) => setState(() {
                _category = v;
                _dirty = true;
              }),
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
            label(tr('Rasm (ixtiyoriy)')),
            if (hasImage)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _image != null
                      ? Image.memory(_image!, height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Image.network(AppConfig.mediaUrl(_existingUrl)!, height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: tr('Rasmni olib tashlash'),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xE6FFFFFF), minimumSize: const Size(44, 44)),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF20251B)),
                    onPressed: () => setState(() {
                      _image = null;
                      _existingUrl = null;
                      _dirty = true;
                    }),
                  ),
                ),
              ])
            else
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _pick,
                  icon: const Icon(AppIcons.image),
                  label: Text(tr("Rasm qo'shish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 15)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
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
