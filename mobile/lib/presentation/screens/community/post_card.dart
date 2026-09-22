import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.feed, this.detail = false});
  final Post post;
  final String? feed;
  final bool detail;
  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late Post _p = widget.post;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) _p = widget.post;
  }

  Future<void> _like() async {
    final liked = !_p.likedByMe;
    try {
      final updated = await ref.read(communityRepoProvider).like(_p.id, liked);
      setState(() => _p = updated);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _menu() async {
    final me = ref.read(currentUserProvider);
    final mine = me?.id == _p.author.id;
    final action = await showSheet<String>(context, title: 'Post', builder: (ctx) => Column(children: [
          if (mine || (me?.isAdmin ?? false)) ListRow(icon: AppIcons.trash, label: "O'chirish", danger: true, onTap: () => Navigator.pop(ctx, 'delete')),
          if (!mine) ListRow(icon: AppIcons.flag, label: 'Shikoyat qilish', onTap: () => Navigator.pop(ctx, 'report')),
          if (!mine) ListRow(icon: AppIcons.user, label: 'Muallif profili', onTap: () => Navigator.pop(ctx, 'profile')),
        ]));
    if (!mounted || action == null) return;
    final repo = ref.read(communityRepoProvider);
    try {
      if (action == 'delete') {
        await repo.deletePost(_p.id);
        ref.invalidate(feedProvider('all'));
        ref.invalidate(feedProvider('following'));
        if (mounted) {
          showToast(context, "Post o'chirildi");
          if (widget.detail) context.pop();
        }
      } else if (action == 'report') {
        await repo.report(postId: _p.id, reason: "Nomaqbul kontent");
        if (mounted) showToast(context, 'Shikoyat yuborildi. Moderator ko\'rib chiqadi.');
      } else if (action == 'profile') {
        context.push('/users/${_p.author.id}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = _p;
    final img = AppConfig.mediaUrl(p.imageUrl);
    final healthy = p.category != 'disease' && p.category != 'question';
    void open() => widget.detail ? null : context.push('/community/${p.id}');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: softShadow(context)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(children: [
            InkWell(onTap: () => context.push('/users/${p.author.id}'), child: Avatar(name: p.author.fullName, url: p.author.avatarUrl, size: 34)),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/users/${p.author.id}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.author.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(timeAgo(p.createdAt), style: TextStyle(fontSize: 11.5, color: c.muted)),
                ]),
              ),
            ),
            if (p.category != null) Tag(postCategoryLabels[p.category] ?? p.category!, bg: healthy ? c.tagCare : c.primaryLight, fg: healthy ? c.onTagCare : c.primaryDark),
            IconButton(icon: Icon(Icons.more_vert_rounded, color: c.muted), onPressed: _menu, tooltip: 'Amallar'),
          ]),
        ),
        if (img != null)
          InkWell(
            onTap: open,
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: c.tan, child: Icon(AppIcons.leaf, color: c.primaryDark, size: 40))),
            ),
          ),
        InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if (p.content != null && p.content!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.content!, style: const TextStyle(fontSize: 13.5, height: 1.5), maxLines: widget.detail ? null : 4, overflow: widget.detail ? null : TextOverflow.ellipsis),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 10),
          child: Row(children: [
            TextButton.icon(
              onPressed: _like,
              icon: Icon(p.likedByMe ? AppIcons.heartFill : AppIcons.heart, size: 18, color: p.likedByMe ? c.danger : c.muted),
              label: Text('${p.likes} layk', style: TextStyle(color: p.likedByMe ? c.danger : c.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
            TextButton.icon(
              onPressed: open,
              icon: Icon(AppIcons.chat, size: 17, color: c.muted),
              label: Text('${p.comments} izoh', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ]),
        ),
      ]),
    );
  }
}
