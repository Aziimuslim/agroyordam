import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../chat/chat_widgets.dart';
import 'post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailState();
}

class _PostDetailState extends ConsumerState<PostDetailScreen> {
  final _ctrl = TextEditingController();

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    try {
      await ref.read(communityRepoProvider).addComment(widget.id, t);
      _ctrl.clear();
      ref.invalidate(commentsProvider(widget.id));
      ref.invalidate(postProvider(widget.id));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
                  const TopBar(title: 'Post'),
                  AsyncView(value: ref.watch(postProvider(widget.id)), data: (p) => PostCard(post: p, detail: true)),
                  AsyncView(
                    value: ref.watch(commentsProvider(widget.id)),
                    data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SectionTitle('Izohlar (${list.length})'),
                      if (list.isEmpty) const EmptyNote("Hali izoh yo'q"),
                      for (final cm in list)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                          radius: 14,
                          onTap: () => context.push('/users/${cm.author.id}'),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Avatar(name: cm.author.fullName, url: cm.author.avatarUrl, size: 28),
                              const SizedBox(width: 9),
                              Text(cm.author.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(timeAgo(cm.createdAt), style: TextStyle(color: c.muted, fontSize: 11.5))),
                              if (cm.author.id == me?.id || (me?.isAdmin ?? false))
                                InkWell(
                                  onTap: () async {
                                    await ref.read(communityRepoProvider).deleteComment(cm.id);
                                    ref.invalidate(commentsProvider(widget.id));
                                  },
                                  child: Icon(Icons.close_rounded, size: 18, color: c.muted),
                                ),
                            ]),
                            const SizedBox(height: 6),
                            Text(cm.content, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
              ChatInputBar(controller: _ctrl, onSend: _send, hint: 'Izoh yozing...'),
            ]),
          ),
        ),
      ),
    );
  }
}
