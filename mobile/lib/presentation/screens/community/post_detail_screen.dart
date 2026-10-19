import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../chat/chat_widgets.dart';
import 'post_card.dart';
import '../saved/bookmark_button.dart';
import 'report_sheet.dart';

/// S13 Post tafsiloti: post, izohlar (agronom javoblari tepada), izoh 1–1000 belgi — server tasdig'idan keyin
/// ro'yxatga qo'shiladi. "Javob berish" — reply konteksti composer ustida, bekor qilish uni tozalaydi; javoblar
/// ota izoh ostida bir daraja. O'z izohi — tahrir/o'chirish, boshqaniki — shikoyat. O'chirilgan ota izoh
/// "Izoh o'chirilgan" bo'lib qoladi, javoblari saqlanadi. Post yo'q bo'lsa yozish o'chiq.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.id, this.focusComment = false});
  final String id;
  final bool focusComment;
  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailState();
}

class _PostDetailState extends ConsumerState<PostDetailScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  Comment? _replyTo;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(commentsProvider(widget.id));
    ref.invalidate(postProvider(widget.id));
    ref.invalidate(feedProvider); // izohlar soni lentada ham yangilanadi
  }

  void _reply(Comment cm) {
    setState(() => _replyTo = cm);
    _focus.requestFocus();
  }

  Future<void> _edit(Comment cm) async {
    final ctrl = TextEditingController(text: cm.content);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Izohni tahrirlash')),
        content: SizedBox(
          width: 480,
          child: TextField(controller: ctrl, autofocus: true, minLines: 2, maxLines: 6, maxLength: 1000, style: const TextStyle(fontSize: 16)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(tr('Saqlash'))),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text == cm.content || !mounted) return;
    if (text.isEmpty) {
      showToast(context, tr("Izoh bo'sh bo'lmasin"));
      return;
    }
    try {
      await ref.read(communityRepoProvider).editComment(cm.id, text);
      ref.invalidate(commentsProvider(widget.id));
      if (mounted) showToast(context, tr('Saqlandi'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepoProvider).addComment(widget.id, t, replyTo: _replyTo?.id);
      _ctrl.clear();
      if (mounted) setState(() => _replyTo = null);
      _refresh();
      ref.invalidate(unansweredPostsProvider);
    } catch (e) {
      if (mounted) showError(context, e); // matn yozish maydonida qoladi
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment cm) async {
    final ok = await confirm(context, tr("Izohni o'chirasizmi?"), cm.content, ok: tr("O'chirish"), danger: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(communityRepoProvider).deleteComment(cm.id);
      if (_replyTo?.id == cm.id && mounted) setState(() => _replyTo = null);
      _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final post = ref.watch(postProvider(widget.id));
    final comments = ref.watch(commentsProvider(widget.id));
    final missing = post.hasError && ApiException.from(post.error!).statusCode == 404;

    Widget commentsBlock;
    final list = comments.value;
    if (list == null && comments.hasError) {
      commentsBlock = BlockError(error: comments.error!, what: tr('Izohlar'), onRetry: () => ref.invalidate(commentsProvider(widget.id)));
    } else if (list == null) {
      commentsBlock = const Skeleton(height: 80);
    } else {
      // Ildiz izohlar (agronom javoblari tepada), har birining ostida javoblari vaqt bo'yicha
      final ids = {for (final x in list) x.id};
      final roots = list.where((x) => x.parentId == null || !ids.contains(x.parentId)).toList();
      bool expert(Comment x) => x.author?.isExpert ?? false;
      final sorted = [...roots.where(expert), ...roots.where((x) => !expert(x))];
      final count = list.where((x) => !x.deleted).length;
      Widget tile(Comment cm, {bool reply = false}) => _CommentTile(
            cm: cm,
            reply: reply,
            mine: cm.author?.id == me?.id,
            admin: me?.isAdmin ?? false,
            canReply: post.value != null && !missing,
            onReply: () => _reply(cm),
            onEdit: () => _edit(cm),
            onDelete: () => _deleteComment(cm),
          );
      commentsBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BlockTitle(trf('Izohlar ({0})', [count])),
        if (list.isEmpty) Text(tr("Hali izoh yo'q. Birinchi bo'lib fikr bildiring."), style: TextStyle(color: c.muted, fontSize: 15)),
        for (final root in sorted) ...[
          tile(root),
          for (final r in list.where((x) => x.parentId == root.id)) tile(r, reply: true),
        ],
      ]);
    }

    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: [
                  TopBar(title: tr('Post'), actions: [if (!missing) BookmarkButton(kind: 'post', targetId: widget.id)]),
                  if (missing)
                    Column(children: [
                      EmptyNote(tr("Post topilmadi yoki o'chirilgan"), icon: Icons.search_off_rounded),
                      TextButton(onPressed: () => context.go('/help?tab=comm'), child: Text(tr('Jamoatga qaytish'))),
                    ])
                  else ...[
                    if (post.value != null)
                      PostCard(post: post.value!, detail: true)
                    else if (post.hasError)
                      BlockError(error: post.error!, what: tr('Post'), onRetry: () => ref.invalidate(postProvider(widget.id)))
                    else
                      const Skeleton(height: 220),
                    commentsBlock,
                  ],
                ]),
              ),
              ChatInputBar(
                controller: _ctrl,
                onSend: _send,
                maxLength: 1000,
                busy: _sending,
                enabled: !missing && post.value != null,
                disabledText: missing ? tr("Post o'chirilgan — izoh yozib bo'lmaydi") : null,
                autofocus: widget.focusComment,
                focusNode: _focus,
                hint: _replyTo == null ? tr('Izoh yozing...') : tr('Javob yozing...'),
                top: _replyTo == null
                    ? null
                    : Container(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                        decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Icon(Icons.reply_rounded, size: 18, color: c.onOliveSoft),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(trf('{0} ga javob', [_replyTo!.author?.fullName ?? '']),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onOliveSoft, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          IconButton(
                            tooltip: tr('Javobni bekor qilish'),
                            onPressed: () => setState(() => _replyTo = null),
                            icon: Icon(Icons.close_rounded, color: c.onOliveSoft),
                          ),
                        ]),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.cm,
    required this.mine,
    required this.admin,
    required this.canReply,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.reply = false,
  });
  final Comment cm;
  final bool mine, admin, canReply, reply;
  final VoidCallback onReply, onEdit, onDelete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final margin = EdgeInsets.only(bottom: 10, left: reply ? 28 : 0);
    final author = cm.author;
    if (cm.deleted || author == null) {
      return Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Row(children: [
          Icon(Icons.block_outlined, size: 18, color: c.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(tr("Izoh o'chirilgan"), style: TextStyle(fontSize: 15, color: c.muted, fontStyle: FontStyle.italic))),
        ]),
      );
    }
    final expert = author.isExpert;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
      decoration: BoxDecoration(
        color: expert ? c.oliveSoft : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Semantics(
              button: true,
              label: trf('{0} profili', [author.fullName]),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/users/${author.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Avatar(name: author.fullName, url: author.avatarUrl, size: reply ? 28 : 32, color: c.olive, textColor: c.onOlive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(author.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                        Text([if (expert) tr('Agronom javobi'), timeAgo(cm.createdAt), if (cm.edited) tr('tahrirlangan')].join(' · '),
                            style: TextStyle(fontSize: 13, color: expert ? c.onOliveSoft : c.muted, fontWeight: expert ? FontWeight.w700 : FontWeight.w400)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: tr('Amallar'),
            icon: Icon(Icons.more_vert_rounded, color: c.muted),
            onSelected: (v) => switch (v) {
              'edit' => onEdit(),
              'delete' => onDelete(),
              _ => showReportSheet(context, ref, commentId: cm.id),
            },
            itemBuilder: (_) => [
              if (mine) PopupMenuItem(value: 'edit', child: Text(tr('Tahrirlash'))),
              if (mine || admin) PopupMenuItem(value: 'delete', child: Text(tr("O'chirish"))),
              if (!mine) PopupMenuItem(value: 'report', child: Text(tr('Shikoyat qilish'))),
            ],
          ),
        ]),
        if (reply && cm.replyToName != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Row(children: [
              Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: c.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(trf('{0} ga javob', [cm.replyToName!]),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.only(right: 10), child: Text(cm.content, style: TextStyle(fontSize: 16, height: 1.45, color: c.text))),
        if (canReply)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: c.primaryDark),
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: Text(tr('Javob berish'), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        else
          const SizedBox(height: 8),
      ]),
    );
  }
}
