import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// A08: bloklangan foydalanuvchilar va blokdan chiqarish (sozlamalar ichida).
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key});
  @override
  ConsumerState<BlockedScreen> createState() => _BlockedState();
}

class _BlockedState extends ConsumerState<BlockedScreen> {
  String? _busy;

  Future<void> _unblock(AppUser u) async {
    if (!await confirm(context, tr('Blokdan chiqarasizmi?'), trf("{0} postlari va izohlari yana ko'rinadi, u sizga yoza oladi.", [u.fullName]), ok: tr('Blokdan chiqarish'))) return;
    setState(() => _busy = u.id);
    try {
      await ref.read(communityRepoProvider).block(u.id, false);
      ref.invalidate(blocksProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(profileProvider(u.id));
      if (mounted) showToast(context, trf('{0} blokdan chiqarildi', [u.fullName]));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(blocksProvider);
    final list = v.value;
    return PageShell(
      maxWidth: 640,
      padBottom: false,
      onRefresh: () async => ref.invalidate(blocksProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Bloklanganlar')),
        if (list == null && v.hasError)
          BlockError(error: v.error!, what: tr('Bloklanganlar'), onRetry: () => ref.invalidate(blocksProvider))
        else if (list == null)
          const Skeleton(height: 68)
        else if (list.isEmpty)
          EmptyNote(tr("Hech kim bloklanmagan. Foydalanuvchini uning profilidagi menyu orqali bloklash mumkin."), icon: Icons.block_outlined)
        else
          for (final u in list)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
              child: Row(children: [
                Avatar(name: u.fullName, url: u.avatarUrl, size: 44, color: c.olive, textColor: c.onOlive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                    Text('@${u.username}', style: TextStyle(fontSize: 14, color: c.muted)),
                  ]),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _busy == null ? () => _unblock(u) : null,
                  child: Text(tr('Blokdan chiqarish')),
                ),
              ]),
            ),
      ]),
    );
  }
}
