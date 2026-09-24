import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String? t) => switch (t) {
        'like' => AppIcons.heart,
        'comment' => AppIcons.chat,
        'follow' => AppIcons.user,
        'reminder' => AppIcons.bell,
        'diagnosis_ready' => AppIcons.camera,
        'subscription' => AppIcons.star,
        'message' => AppIcons.send,
        _ => AppIcons.bell,
      };

  void _open(BuildContext context, AppNotification n) {
    final id = n.referenceId;
    if (id == null) return;
    switch (n.type) {
      case 'like' || 'comment':
        context.push('/community/$id');
      case 'follow':
        context.push('/users/$id');
      case 'diagnosis_ready':
        context.push('/diagnosis/$id');
      case 'message':
        context.push('/messages/$id');
      case 'reminder':
        context.push('/reminders');
      case 'subscription':
        context.push('/premium');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: 'Bildirishnomalar', actions: [
          CircleIconButton(
            icon: Icons.done_all_rounded,
            tooltip: "Hammasini o'qildi deb belgilash",
            onTap: () async {
              await ref.read(communityRepoProvider).readAll();
              ref.invalidate(notificationsProvider);
            },
          ),
        ]),
        AsyncView(
          value: ref.watch(notificationsProvider),
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (list) => list.isEmpty
              ? const EmptyNote("Bildirishnomalar yo'q", icon: AppIcons.bell)
              : Column(children: [
                  for (final n in list)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: n.isRead ? null : c.primaryLight,
                      onTap: () => _open(context, n),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ThumbIcon(icon: _icon(n.type), size: 40, radius: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (n.body != null) Text(n.body!, style: TextStyle(color: c.muted, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(timeAgo(n.createdAt), style: TextStyle(color: c.muted, fontSize: 11.5)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
