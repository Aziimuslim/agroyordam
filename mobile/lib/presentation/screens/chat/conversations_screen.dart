import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// S15 Xabarlar: ism bo'yicha qidiruv (mahalliy), o'qilmaganlar soni, oxirgi xabar ("Siz:" / "Rasm").
/// Menyu (⋮ yoki uzoq bosish): o'qilgan deb belgilash, ovozsiz qilish, o'z ro'yxatidan yashirish (tasdiq bilan;
/// boshqa odam xabarlari o'chmaydi, yangi xabar kelsa suhbat qaytadi).
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});
  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsState();
}

class _ConversationsState extends ConsumerState<ConversationsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = ref.watch(conversationsProvider);
    final list = v.value;
    Widget body;
    if (list == null && v.hasError) {
      body = BlockError(error: v.error!, what: tr('Xabarlar'), onRetry: () => ref.invalidate(conversationsProvider));
    } else if (list == null) {
      body = Column(children: [for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 72))]);
    } else if (list.isEmpty) {
      body = Column(children: [
        EmptyNote(tr("Hali xabar yo'q. Jamoatdagi fermer profiliga kirib suhbat boshlang."), icon: AppIcons.chat),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5)),
            onPressed: () => context.push('/users/search'),
            icon: const Icon(Icons.person_search_outlined),
            label: Text(tr('Foydalanuvchi qidirish')),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5)),
            onPressed: () => context.go('/help?tab=comm'),
            icon: const Icon(Icons.groups_outlined),
            label: Text(tr("Jamoatga o'tish")),
          ),
        ]),
      ]);
    } else {
      final q = _q.trim().toLowerCase();
      final shown = q.isEmpty
          ? list
          : list.where((x) => '${x.other?.fullName ?? ''} ${x.other?.username ?? ''}'.toLowerCase().contains(q)).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (shown.isEmpty) EmptyNote(tr('Hech narsa topilmadi'), icon: Icons.search_off_rounded),
        for (final conv in shown) _ConvTile(conv: conv),
      ]);
    }

    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async => ref.invalidate(conversationsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Xabarlar'), actions: [
          IconButton(tooltip: tr('Yangi suhbat'), onPressed: () => context.push('/users/search'), icon: Icon(Icons.edit_square, color: c.text)),
        ]),
        if ((list?.length ?? 0) > 0) ...[
          TextField(
            onChanged: (s) => setState(() => _q = s),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: tr('Ism bo\'yicha qidirish'),
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        body,
      ]),
    );
  }
}

class _ConvTile extends ConsumerWidget {
  const _ConvTile({required this.conv});
  final Conversation conv;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final name = conv.other?.fullName ?? tr('Suhbat');
    final action = await showSheet<String>(context, title: name, builder: (ctx) => Column(children: [
          if (conv.unread > 0) ListRow(icon: Icons.mark_chat_read_outlined, label: tr("O'qilgan deb belgilash"), onTap: () => Navigator.pop(ctx, 'read')),
          ListRow(
            icon: conv.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            label: conv.muted ? tr('Ovozni yoqish') : tr('Ovozsiz qilish'),
            onTap: () => Navigator.pop(ctx, 'mute'),
          ),
          ListRow(icon: AppIcons.trash, label: tr("Ro'yxatdan yashirish"), danger: true, onTap: () => Navigator.pop(ctx, 'hide')),
        ]));
    if (action == null || !context.mounted) return;
    final repo = ref.read(communityRepoProvider);
    try {
      switch (action) {
        case 'read':
          await repo.readConversation(conv.id);
        case 'mute':
          await repo.muteConversation(conv.id, !conv.muted);
          if (context.mounted) showToast(context, conv.muted ? tr('Bildirishnomalar yoqildi') : tr("Suhbat ovozsiz — bildirishnoma kelmaydi"));
        case 'hide':
          final ok = await confirm(context, tr('Suhbatni yashirasizmi?'),
              trf("Suhbat faqat sizning ro'yxatingizdan olib tashlanadi. {0} xabarlari o'chmaydi; yangi xabar kelsa suhbat qaytadi.", [name]),
              ok: tr('Yashirish'), danger: true);
          if (!ok) return;
          await repo.hideConversation(conv.id);
      }
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final last = conv.lastMessage;
    final mine = last != null && last.senderId == me?.id;
    final text = last == null
        ? tr('Hali xabar yo\'q')
        : (last.content ?? '').trim().isNotEmpty
            ? last.content!.trim()
            : (last.imageUrls.length > 1 ? trf('{0} ta rasm', [last.imageUrls.length]) : last.imageUrls.isNotEmpty ? tr('Rasm') : '');
    final name = conv.other?.fullName ?? tr('Suhbat');
    final unread = conv.unread > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: [name, if (unread) trf("{0} ta o'qilmagan", [conv.unread]), if (conv.muted) tr('Ovozsiz')].join(', '),
        child: Material(
          color: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: unread ? c.primary : c.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/messages/${conv.id}'),
            onLongPress: () => _menu(context, ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 2, 12),
              child: Row(children: [
                Avatar(name: name, url: conv.other?.avatarUrl, size: 48, color: c.olive, textColor: c.onOlive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text))),
                      if (conv.muted) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.notifications_off_outlined, size: 16, color: c.muted)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (last?.imageUrls.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(AppIcons.image, size: 16, color: c.muted)),
                      Expanded(
                        child: Text(
                          '${mine ? tr('Siz: ') : ''}$text',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: unread ? c.text : c.muted, fontSize: 14.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w400),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                // katta matnda vaqt ustuni cheklanadi va keyingi qatorga o'tadi
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width.clamp(0, 760) * 0.28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (last?.createdAt != null) Text(timeAgo(last!.createdAt), textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 12.5)),
                  if (unread) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      // ovozsiz suhbat soni sokinroq rangda
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: conv.muted ? c.muted : c.primary, borderRadius: BorderRadius.circular(999)),
                      child: Text(conv.unread > 99 ? '99+' : '${conv.unread}',
                          textAlign: TextAlign.center, style: TextStyle(color: conv.muted ? c.card : c.onPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ],
                  ]),
                ),
                IconButton(tooltip: tr('Amallar'), onPressed: () => _menu(context, ref), icon: Icon(Icons.more_vert_rounded, color: c.muted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
