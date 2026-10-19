import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// A07 Foydalanuvchi qidiruvi: ism yoki @username, kamida 2 belgi. Faqat ommaviy minimal profil
/// (telefon/email bo'yicha qidirilmaydi). Natija → profil (S14) yoki darhol xabar yozish (S16).
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});
  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchState();
}

class _UserSearchState extends ConsumerState<UserSearchScreen> {
  String _q = '';
  Timer? _debounce;
  String? _busyId;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => mounted ? setState(() => _q = s.trim()) : null);
  }

  Future<void> _message(AppUser u) async {
    if (_busyId != null) return;
    setState(() => _busyId = u.id);
    try {
      final conv = await ref.read(communityRepoProvider).startConversation(u.id);
      ref.invalidate(conversationsProvider);
      if (mounted) context.push('/messages/${conv.id}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget body;
    if (_q.replaceAll('@', '').length < 2) {
      body = EmptyNote(tr('Ism yoki foydalanuvchi nomidan kamida 2 ta belgi yozing'), icon: Icons.person_search_outlined);
    } else {
      final v = ref.watch(userSearchProvider(_q));
      final list = v.value;
      if (list == null && v.hasError) {
        body = BlockError(error: v.error!, what: tr('Qidiruv'), onRetry: () => ref.invalidate(userSearchProvider(_q)));
      } else if (list == null) {
        body = Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 68))]);
      } else if (list.isEmpty) {
        body = EmptyNote(tr('Hech kim topilmadi'), icon: Icons.search_off_rounded);
      } else {
        body = Column(children: [
          for (final u in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: c.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/users/${u.id}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(children: [
                      Avatar(name: u.fullName, url: u.avatarUrl, size: 48, color: c.olive, textColor: c.onOlive),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                          Text(['@${u.username}', if (u.isExpert) tr('Agronom'), if ((u.region ?? '').isNotEmpty) u.region!].join(' · '),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted)),
                        ]),
                      ),
                      IconButton(
                        tooltip: trf('{0} ga xabar yozish', [u.fullName]),
                        onPressed: _busyId == null ? () => _message(u) : null,
                        icon: _busyId == u.id ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.chat_bubble_outline_rounded, color: c.primaryDark),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      }
    }
    return PageShell(
      maxWidth: 760,
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Foydalanuvchi qidirish')),
        TextField(
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(hintText: tr('Ism yoki @username'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        ),
        const SizedBox(height: 12),
        body,
      ]),
    );
  }
}
