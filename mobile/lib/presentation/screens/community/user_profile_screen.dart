import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import 'post_card.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    return PageShell(
      padBottom: false,
      child: AsyncView(
        value: ref.watch(profileProvider(id)),
        onRetry: () => ref.invalidate(profileProvider(id)),
        data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TopBar(title: 'Fermer profili'),
          Center(
            child: Column(children: [
              Avatar(name: p.user.fullName, url: p.user.avatarUrl, size: 84),
              const SizedBox(height: 12),
              Text(p.user.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text('@${p.user.username}${p.user.region != null ? ' · ${p.user.region}' : ''}', style: TextStyle(color: c.muted)),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            _Stat(value: p.posts, label: 'Post'),
            const SizedBox(width: 10),
            _Stat(value: p.followers, label: 'Obunachi'),
            const SizedBox(width: 10),
            _Stat(value: p.following, label: 'Obuna'),
          ]),
          const SizedBox(height: 18),
          if (me?.id != p.user.id)
            Row(children: [
              Expanded(
                child: PillButton(
                  label: p.isFollowing ? 'Obunani bekor qilish' : "Obuna bo'lish",
                  style: p.isFollowing ? PillStyle.outline : PillStyle.primary,
                  block: true,
                  onPressed: () async {
                    try {
                      await ref.read(communityRepoProvider).follow(p.user.id, !p.isFollowing);
                      ref.invalidate(profileProvider(id));
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton(
                  label: 'Xabar',
                  icon: AppIcons.chat,
                  block: true,
                  onPressed: () async {
                    try {
                      final conv = await ref.read(communityRepoProvider).startConversation(p.user.id);
                      if (context.mounted) context.push('/messages/${conv.id}');
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ),
            ]),
          const SizedBox(height: 18),
          const SectionTitle('Postlari'),
          AsyncView(
            value: ref.watch(userPostsProvider(id)),
            data: (posts) => posts.isEmpty ? const EmptyNote("Hali post yo'q") : Column(children: [for (final post in posts) PostCard(post: post)]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AppCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(children: [
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.c.primary)),
            Text(label, style: TextStyle(fontSize: 11.5, color: context.c.muted, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
