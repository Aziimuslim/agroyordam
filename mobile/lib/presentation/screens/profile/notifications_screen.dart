import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../reminders/task_sheet.dart';

/// S27 Bildirishnomalar: Barchasi / O'qilmagan, "Barchasini o'qish" (server), karta → turga mos ekran
/// (vazifa A03, tashxis S08, izoh/layk S13, xabar S16, savol, to'lov S30). O'qildi belgisi ochilgandan keyin.
/// Manzil (obyekt) yo'q yoki o'chirilgan bo'lsa — tushuntirish va ota bo'lim, crash emas.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  String _tab = 'all';
  bool _readingAll = false;

  static IconData _icon(String? t) => switch (t) {
        'like' => AppIcons.heart,
        'comment' => AppIcons.chat,
        'follow' => AppIcons.user,
        'reminder' => Icons.task_alt_rounded,
        'diagnosis_ready' || 'diagnosis_reviewed' => AppIcons.scan,
        'subscription' => AppIcons.star,
        'message' => AppIcons.send,
        'question_message' || 'question_closed' => Icons.forum_outlined,
        'password_reset' => AppIcons.lock,
        'expert_approved' || 'expert_rejected' => Icons.verified_user_outlined,
        'moderation' => AppIcons.flag,
        _ => AppIcons.bell,
      };

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await ref.read(communityRepoProvider).readOne(n.id);
      ref.invalidate(notificationsProvider);
    } catch (_) {
      // O'qildi belgisi qo'yilmasa ham ochilgan ekran ishlayveradi; keyingi yangilanishda qayta urinamiz
    }
  }

  Future<void> _open(AppNotification n) async {
    final id = n.referenceId;
    String? route;
    switch (n.type) {
      case 'reminder':
        if (id == null) break;
        try {
          final r = await ref.read(gardenRepoProvider).reminder(id);
          if (!mounted) return;
          await _markRead(n);
          if (mounted) await showTaskSheet(context, r);
        } catch (e) {
          if (!mounted) return;
          final err = ApiException.from(e);
          if (err.statusCode == 404) {
            await _markRead(n);
            if (!mounted) return;
            showToast(context, tr("Vazifa topilmadi — o'chirilgan bo'lishi mumkin"));
            context.push('/reminders');
          } else {
            showError(context, e);
          }
        }
        return;
      case 'diagnosis_ready' || 'diagnosis_reviewed':
        route = id == null ? '/diagnoses' : '/diagnosis/$id';
      case 'like' || 'comment':
        route = id == null ? '/help?tab=comm' : '/community/$id';
      case 'follow':
        route = id == null ? null : '/users/$id';
      case 'message':
        route = id == null ? '/messages' : '/messages/$id';
      case 'question_message' || 'question_closed':
        route = id == null ? '/help' : '/help/q/$id';
      case 'subscription':
        route = id == null ? '/premium' : '/premium/payments';
      case 'password_reset':
        route = '/profile/password';
      case 'expert_rejected':
        route = '/profile/expert';
      case 'expert_approved':
        route = '/profile';
    }
    if (route == null) {
      // Manzilsiz xabar (e'lon, moderatsiya): to'liq matn pastki oynada
      await _markRead(n);
      if (mounted) await _showText(n);
      return;
    }
    if (!mounted) return;
    context.push(route);
    await _markRead(n);
  }

  Future<void> _showText(AppNotification n) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: context.c.card,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title ?? tr('Bildirishnoma'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ctx.c.text)),
              const SizedBox(height: 8),
              if (n.body != null) Text(n.body!, style: TextStyle(fontSize: 16, height: 1.45, color: ctx.c.text)),
              const SizedBox(height: 8),
              Text(timeAgo(n.createdAt), style: TextStyle(color: ctx.c.muted, fontSize: 14)),
            ]),
          ),
        ),
      );

  Future<void> _readAll() async {
    setState(() => _readingAll = true);
    try {
      await ref.read(communityRepoProvider).readAll();
      ref.invalidate(notificationsProvider);
      if (mounted) showToast(context, tr("Barchasi o'qildi deb belgilandi"));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _readingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final value = ref.watch(notificationsProvider);
    final list = value.value;
    final unread = list?.where((n) => !n.isRead).length ?? 0;

    Widget body;
    if (list == null && value.hasError) {
      body = BlockError(error: value.error!, what: tr('Bildirishnomalar'), onRetry: () => ref.invalidate(notificationsProvider));
    } else if (list == null) {
      body = const Column(children: [Skeleton(height: 80), SizedBox(height: 8), Skeleton(height: 80), SizedBox(height: 8), Skeleton(height: 80)]);
    } else {
      final shown = _tab == 'unread' ? list.where((n) => !n.isRead).toList() : list;
      if (shown.isEmpty) {
        body = EmptyNote(_tab == 'unread' ? tr("O'qilmagan bildirishnoma yo'q") : tr("Bildirishnomalar yo'q"), icon: AppIcons.bell);
      } else {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        String groupOf(AppNotification n) {
          final t = n.createdAt?.toLocal();
          if (t == null || t.isBefore(yesterday)) return tr('Avvalroq');
          return t.isBefore(today) ? tr('Kecha') : tr('Bugun');
        }

        final rows = <Widget>[];
        String? last;
        for (final n in shown) {
          final g = groupOf(n);
          if (g != last) {
            last = g;
            rows.add(Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Semantics(header: true, child: Text(g, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text))),
            ));
          }
          rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: _NoteTile(n: n, icon: _icon(n.type), onTap: () => _open(n))));
        }
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      }
    }

    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Bildirishnomalar'), subtitle: unread > 0 ? trf('{0} ta yangi', [unread]) : null),
        Row(children: [
          Expanded(
            child: ChipTabs(
              tabs: [('all', tr('Barchasi')), ('unread', unread > 0 ? trf("O'qilmagan ({0})", [unread]) : tr("O'qilmagan"))],
              selected: _tab,
              onSelect: (v) => setState(() => _tab = v),
            ),
          ),
        ]),
        if (unread > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: _readingAll ? null : _readAll,
                icon: _readingAll ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all_rounded),
                label: Text(tr("Barchasini o'qilgan deb belgilash")),
              ),
            ),
          ),
        AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_tab), child: body)),
      ]),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.n, required this.icon, required this.onTap});
  final AppNotification n;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unread = !n.isRead;
    return Semantics(
      button: true,
      label: [if (unread) tr("O'qilmagan"), n.title ?? '', n.body ?? '', timeAgo(n.createdAt)].where((s) => s.isNotEmpty).join('. '),
      excludeSemantics: true,
      child: Material(
        color: unread ? c.card : c.cream2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: unread ? c.primary.withValues(alpha: 0.5) : c.border)),
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: c.onOliveSoft, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(n.title ?? tr('Bildirishnoma'),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: unread ? FontWeight.w800 : FontWeight.w600, color: c.text)),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Container(margin: const EdgeInsets.only(top: 6), width: 10, height: 10, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    ],
                  ]),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(n.body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 15, height: 1.35)),
                  ],
                  const SizedBox(height: 4),
                  Text(timeAgo(n.createdAt), style: TextStyle(color: c.muted, fontSize: 14)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
