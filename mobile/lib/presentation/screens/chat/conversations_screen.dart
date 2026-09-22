import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    return PageShell(
      padBottom: false,
      onRefresh: () async => ref.invalidate(conversationsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Xabarlar'),
        AsyncView(
          value: ref.watch(conversationsProvider),
          onRetry: () => ref.invalidate(conversationsProvider),
          data: (list) => list.isEmpty
              ? const EmptyNote("Xabarlar yo'q. Jamoatdagi fermer profiliga kirib suhbat boshlang.", icon: AppIcons.chat)
              : Column(children: [
                  for (final conv in list)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      radius: 14,
                      onTap: () => context.push('/messages/${conv.id}'),
                      child: Row(children: [
                        Avatar(name: conv.other?.fullName ?? '?', url: conv.other?.avatarUrl, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(conv.other?.fullName ?? 'Suhbat', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                            Text(
                              '${conv.lastMessage?.senderId == me?.id ? 'Siz: ' : ''}${conv.lastMessage?.content ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        if (conv.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(999)),
                            child: Text('${conv.unread}', style: TextStyle(color: c.card, fontWeight: FontWeight.w800, fontSize: 12)),
                          )
                        else
                          Text(timeAgo(conv.lastMessage?.createdAt), style: TextStyle(color: c.muted, fontSize: 11.5)),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
