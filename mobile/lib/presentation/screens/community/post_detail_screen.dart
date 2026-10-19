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
import 'report_sheet.dart';

/// S13 Post tafsiloti: post, izohlar (agronom javoblari tepada), izoh 1–1000 belgi — server tasdig'idan keyin
/// ro'yxatga qo'shiladi. O'z izohi — o'chirish (tasdiq bilan), boshqaniki — shikoyat. Post yo'q bo'lsa yozish o'chiq.
/// Izohga javob (reply) — backend'da yo'q.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.id, this.focusComment = false});
  final String id;
  final bool focusComment;
  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailState();
}

class _PostDetailState extends ConsumerState<PostDetailScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepoProvider).addComment(widget.id, t);
      _ctrl.clear();
      ref.invalidate(commentsProvider(widget.id));
      ref.invalidate(postProvider(widget.id));
      ref.invalidate(feedProvider); // izohlar soni lentada ham yangilanadi
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
      ref.invalidate(commentsProvider(widget.id));
      ref.invalidate(postProvider(widget.id));
      ref.invalidate(feedProvider);
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
      final sorted = [...list.where((x) => x.author.isExpert), ...list.where((x) => !x.author.isExpert)];
      commentsBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BlockTitle(trf('Izohlar ({0})', [list.length])),
        if (list.isEmpty) Text(tr("Hali izoh yo'q. Birinchi bo'lib fikr bildiring."), style: TextStyle(color: c.muted, fontSize: 15)),
        for (final cm in sorted) _CommentTile(cm: cm, mine: cm.author.id == me?.id || (me?.isAdmin ?? false), onDelete: () => _deleteComment(cm)),
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
                  TopBar(title: tr('Post')),
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
                hint: tr('Izoh yozing...'),
                maxLength: 1000,
                busy: _sending,
                enabled: !missing && post.value != null,
                disabledText: missing ? tr("Post o'chirilgan — izoh yozib bo'lmaydi") : null,
                autofocus: widget.focusComment,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.cm, required this.mine, required this.onDelete});
  final Comment cm;
  final bool mine;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final expert = cm.author.isExpert;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
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
              label: trf('{0} profili', [cm.author.fullName]),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push('/users/${cm.author.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Avatar(name: cm.author.fullName, url: cm.author.avatarUrl, size: 32, color: c.olive, textColor: c.onOlive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cm.author.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                        Text([if (expert) tr('Agronom javobi'), timeAgo(cm.createdAt)].join(' · '),
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
            onSelected: (v) => v == 'delete' ? onDelete() : showReportSheet(context, ref, commentId: cm.id),
            itemBuilder: (_) => [
              if (mine) PopupMenuItem(value: 'delete', child: Text(tr("O'chirish"))) else PopupMenuItem(value: 'report', child: Text(tr('Shikoyat qilish'))),
            ],
          ),
        ]),
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.only(right: 10), child: Text(cm.content, style: TextStyle(fontSize: 16, height: 1.45, color: c.text))),
      ]),
    );
  }
}
