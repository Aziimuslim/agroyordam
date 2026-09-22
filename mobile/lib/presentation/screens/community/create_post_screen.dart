import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});
  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostState();
}

class _CreatePostState extends ConsumerState<CreatePostScreen> {
  final _title = TextEditingController(), _content = TextEditingController();
  String _category = 'experience';
  Uint8List? _image;
  String _imageName = 'post.jpg';
  bool _loading = false;

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _image = bytes;
      _imageName = f.name.contains('.') ? f.name : '${f.name}.jpg';
    });
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty) {
      showToast(context, 'Sarlavhani kiriting');
      return;
    }
    setState(() => _loading = true);
    try {
      String? url;
      if (_image != null) url = await ref.read(gardenRepoProvider).upload(_image!, _imageName);
      await ref.read(communityRepoProvider).createPost({
        'title': _title.text.trim(),
        'content': _content.text.trim(),
        'category': _category,
        'image_url': url,
      });
      ref.invalidate(feedProvider('all'));
      if (mounted) {
        showToast(context, 'Post joylandi');
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Yangi post'),
        const FieldLabel('Turkum'),
        ChipTabs(tabs: [for (final e in postCategoryLabels.entries) (e.key, e.value)], selected: _category, onSelect: (v) => setState(() => _category = v)),
        const FieldLabel('Sarlavha'),
        TextField(controller: _title, maxLength: 200, decoration: const InputDecoration(hintText: 'Masalan: Fitoftorozni qanday yengdim')),
        const FieldLabel('Matn'),
        TextField(controller: _content, maxLines: 6, decoration: const InputDecoration(hintText: 'Tajribangiz, savolingiz yoki maslahatingiz...')),
        const SizedBox(height: 14),
        if (_image != null)
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_image!, height: 200, width: double.infinity, fit: BoxFit.cover)),
            Positioned(top: 8, right: 8, child: CircleIconButton(icon: Icons.close_rounded, onTap: () => setState(() => _image = null))),
          ])
        else
          PillButton(label: "Rasm qo'shish", icon: AppIcons.image, style: PillStyle.outline, block: true, onPressed: _pick),
        const SizedBox(height: 24),
        PillButton(label: 'Joylash', block: true, loading: _loading, onPressed: _publish, icon: AppIcons.send),
        const SizedBox(height: 8),
        Text("Jamoat qoidalari: hurmat, foydali ma'lumot, reklama va spam taqiqlangan.", style: TextStyle(color: c.muted, fontSize: 12)),
      ]),
    );
  }
}
