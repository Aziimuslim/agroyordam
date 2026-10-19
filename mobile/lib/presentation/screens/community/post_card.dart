import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'report_sheet.dart';

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

  bool _liking = false;

  /// Optimistik like (TZ S11): darhol ko'rinadi, xatoda avvalgi holat tiklanadi.
  Future<void> _like() async {
    if (_liking) return;
    final before = _p;
    final liked = !_p.likedByMe;
    setState(() {
      _liking = true;
      _p = _p.copyWith(likedByMe: liked, likes: (_p.likes + (liked ? 1 : -1)).clamp(0, 1 << 30));
    });
    try {
      final updated = await ref.read(communityRepoProvider).like(before.id, liked);
      if (mounted) setState(() => _p = updated);
    } catch (e) {
      if (mounted) {
        setState(() => _p = before);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _menu() async {
    final me = ref.read(currentUserProvider);
    final mine = me?.id == _p.author.id;
    final action = await showSheet<String>(context, title: tr('Post'), builder: (ctx) => Column(children: [
          if (mine) ListRow(icon: AppIcons.edit, label: tr('Tahrirlash'), onTap: () => Navigator.pop(ctx, 'edit')),
          if (mine || (me?.isAdmin ?? false)) ListRow(icon: AppIcons.trash, label: tr("O'chirish"), danger: true, onTap: () => Navigator.pop(ctx, 'delete')),
          if (!mine) ListRow(icon: AppIcons.flag, label: tr('Shikoyat qilish'), onTap: () => Navigator.pop(ctx, 'report')),
          if (!mine) ListRow(icon: AppIcons.user, label: tr('Muallif profili'), onTap: () => Navigator.pop(ctx, 'profile')),
        ]));
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        context.push('/community/new?edit=${_p.id}');
      case 'profile':
        context.push('/users/${_p.author.id}');
      case 'report':
        await showReportSheet(context, ref, postId: _p.id);
      case 'delete':
        final ok = await confirm(context, tr("Postni o'chirasizmi?"), _p.title, ok: tr("O'chirish"), danger: true);
        if (!ok || !mounted) return;
        try {
          await ref.read(communityRepoProvider).deletePost(_p.id);
          ref.invalidate(feedProvider);
          ref.invalidate(userPostsProvider);
          if (mounted) {
            showToast(context, tr("Post o'chirildi"));
            if (widget.detail) context.pop();
          }
        } catch (e) {
          if (mounted) showError(context, e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = _p;
    final img = AppConfig.mediaUrl(p.imageUrl);
    void open({bool comment = false}) => widget.detail ? null : context.push('/community/${p.id}${comment ? '?comment=1' : ''}');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
          child: Row(children: [
            Expanded(
              child: Semantics(
                button: true,
                label: trf('{0} profili', [p.author.fullName]),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/users/${p.author.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      Avatar(name: p.author.fullName, url: p.author.avatarUrl, size: 40, color: c.olive, textColor: c.onOlive),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.author.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                          Text(timeAgo(p.createdAt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.muted)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            if (p.category != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: p.category == 'question' ? c.warningBg : c.oliveSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(postCategoryLabels[p.category] ?? p.category!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.category == 'question' ? c.warning : c.onOliveSoft)),
              ),
            IconButton(icon: Icon(Icons.more_vert_rounded, color: c.muted), onPressed: _menu, tooltip: tr('Amallar')),
          ]),
        ),
        if (img != null)
          Semantics(
            button: !widget.detail,
            label: p.title,
            child: GestureDetector(
              onTap: widget.detail ? null : open,
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: c.cream2, child: Icon(AppIcons.image, color: c.muted, size: 40))),
              ),
            ),
          ),
        InkWell(
          onTap: widget.detail ? null : open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text, height: 1.3)),
              if (p.content != null && p.content!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.content!, style: TextStyle(fontSize: 15, height: 1.5, color: c.text), maxLines: widget.detail ? null : 4, overflow: widget.detail ? null : TextOverflow.ellipsis),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 6),
          child: Row(children: [
            Semantics(
              button: true,
              toggled: p.likedByMe,
              label: trf('{0} layk', [p.likes]),
              excludeSemantics: true,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: _like,
                icon: Icon(p.likedByMe ? AppIcons.heartFill : AppIcons.heart, size: 20, color: p.likedByMe ? c.danger : c.muted),
                label: Text('${p.likes}', style: TextStyle(color: p.likedByMe ? c.danger : c.muted, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            Semantics(
              button: true,
              label: trf('{0} izoh', [p.comments]),
              excludeSemantics: true,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                onPressed: () => open(comment: true),
                icon: Icon(AppIcons.chat, size: 19, color: c.muted),
                label: Text('${p.comments}', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
