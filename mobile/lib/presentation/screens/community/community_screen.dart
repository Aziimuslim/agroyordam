import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/widgets.dart';
import 'post_card.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityState();
}

class _CommunityState extends ConsumerState<CommunityScreen> {
  String _feed = 'all';

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    final unread = convs.value?.any((c) => c.unread > 0) ?? false;
    return Scaffold(
      backgroundColor: context.c.cream,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.c.primary,
        foregroundColor: context.c.card,
        onPressed: () => context.push('/community/new'),
        icon: const Icon(AppIcons.edit),
        label: const Text('Post yozish', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: const AppBottomNav(current: '/community'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(feedProvider(_feed)),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 90), children: [
                TopBar(title: 'Jamoat', showBack: false, actions: [
                  CircleIconButton(icon: AppIcons.chat, badge: unread, tooltip: 'Xabarlar', onTap: () => context.push('/messages')),
                ]),
                ChipTabs(tabs: const [('all', 'Barchasi'), ('following', 'Obunalarim')], selected: _feed, onSelect: (v) => setState(() => _feed = v)),
                AsyncView(
                  value: ref.watch(feedProvider(_feed)),
                  onRetry: () => ref.invalidate(feedProvider(_feed)),
                  data: (posts) => posts.isEmpty
                      ? EmptyNote(_feed == 'following' ? "Obuna bo'lgan fermerlaringiz hali post yozmagan" : "Hali post yo'q. Birinchi bo'ling!", icon: AppIcons.chat)
                      : Column(children: [for (final p in posts) PostCard(post: p, feed: _feed)]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
