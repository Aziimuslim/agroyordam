import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'post_card.dart';

/// S14 Fermer profili: Postlar / Haqida, obuna (ikki marta bosish sonni buzmaydi), xabar yozish (mavjud
/// suhbat qayta ochiladi). O'z profilida — "Profilni tahrirlash". Telefon, email va manzil ko'rsatilmaydi.
/// Bloklash — backend'da yo'q.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileState();
}

class _UserProfileState extends ConsumerState<UserProfileScreen> {
  String _tab = 'posts';
  bool _busy = false;

  Future<void> _follow(bool follow) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(communityRepoProvider).follow(widget.id, follow);
      ref.invalidate(profileProvider(widget.id));
      ref.invalidate(feedProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final conv = await ref.read(communityRepoProvider).startConversation(widget.id);
      if (mounted) context.push('/messages/${conv.id}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A08: ta'siri tushuntiriladi, tasdiq bilan.
  Future<void> _block(UserProfile p, bool block) async {
    if (_busy) return;
    final name = p.user.fullName;
    final bool ok;
    if (block) {
      ok = await confirm(context, trf('{0} bloklansinmi?', [name]),
          tr("Bir-biringizning postlari, izohlari va qidiruvdagi profilingiz ko'rinmaydi, yozishib bo'lmaydi, obunalar bekor qilinadi. Blokdan chiqarish: Profil → Bloklanganlar."),
          ok: tr('Bloklash'), danger: true);
    } else {
      ok = await confirm(context, tr('Blokdan chiqarasizmi?'), trf("{0} postlari va izohlari yana ko'rinadi, u sizga yoza oladi.", [name]), ok: tr('Blokdan chiqarish'));
    }
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(communityRepoProvider).block(widget.id, block);
      ref.invalidate(profileProvider(widget.id));
      ref.invalidate(userPostsProvider(widget.id));
      ref.invalidate(feedProvider);
      ref.invalidate(blocksProvider);
      ref.invalidate(conversationsProvider);
      if (mounted) showToast(context, block ? trf('{0} bloklandi', [name]) : trf('{0} blokdan chiqarildi', [name]));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final v = ref.watch(profileProvider(widget.id));
    final p = v.value;
    if (p == null) {
      final err = v.hasError ? ApiException.from(v.error!) : null;
      return PageShell(
        padBottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TopBar(title: tr('Fermer profili')),
          if (err == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (err.statusCode == 404)
            EmptyNote(tr("Bu hisob mavjud emas yoki yopilgan"), icon: Icons.person_off_outlined)
          else
            BlockError(error: v.error!, what: tr('Profil'), onRetry: () => ref.invalidate(profileProvider(widget.id))),
        ]),
      );
    }
    final mine = me?.id == p.user.id;
    final u = p.user;
    final place = [u.district, u.region].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    Widget stat(int value, String label) => Expanded(
          child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Column(children: [
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
              Text(label, style: TextStyle(fontSize: 14, color: c.muted)),
            ]),
          ),
        );
    final posts = ref.watch(userPostsProvider(widget.id));
    final postList = posts.value;
    final body = _tab == 'about'
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Text((u.about ?? '').trim().isEmpty ? tr("Foydalanuvchi o'zi haqida hali yozmagan") : u.about!,
                style: TextStyle(fontSize: 16, height: 1.5, color: (u.about ?? '').trim().isEmpty ? c.muted : c.text)),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [Icon(Icons.place_outlined, color: c.muted, size: 20), const SizedBox(width: 8), Expanded(child: Text(place, style: TextStyle(fontSize: 15, color: c.text)))]),
            ],
            if (u.isExpert) ...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: () => context.push('/help/agronom/${u.id}'), icon: const Icon(Icons.verified_user_outlined), label: Text(tr('Agronom sahifasi'))),
            ],
          ])
        : postList == null && posts.hasError
            ? BlockError(error: posts.error!, what: tr('Postlar'), onRetry: () => ref.invalidate(userPostsProvider(widget.id)))
            : postList == null
                ? const Skeleton(height: 180)
                : postList.isEmpty
                    ? EmptyNote(p.isBlocked ? tr("Bloklangan foydalanuvchi postlari ko'rsatilmaydi") : tr("Hali post yo'q"), icon: p.isBlocked ? Icons.block_outlined : AppIcons.chat)
                    : Column(children: [for (final post in postList) PostCard(key: ValueKey(post.id), post: post)]);

    return PageShell(
      padBottom: false,
      maxWidth: 760,
      onRefresh: () async {
        ref.invalidate(profileProvider(widget.id));
        ref.invalidate(userPostsProvider(widget.id));
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: mine ? tr('Mening profilim') : tr('Fermer profili'), actions: [
          if (!mine)
            PopupMenuButton<String>(
              tooltip: tr('Amallar'),
              icon: Icon(Icons.more_vert_rounded, color: c.text),
              onSelected: (_) => _block(p, !p.isBlocked),
              itemBuilder: (_) => [PopupMenuItem(value: 'block', child: Text(p.isBlocked ? tr('Blokdan chiqarish') : tr('Bloklash')))],
            ),
        ]),
        Row(children: [
          Avatar(name: u.fullName, url: u.avatarUrl, size: 80, color: c.olive, textColor: c.onOlive),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(u.fullName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text))),
              Text('@${u.username}', style: TextStyle(fontSize: 15, color: c.muted)),
              if (u.isExpert) ...[
                const SizedBox(height: 4),
                Row(children: [Icon(Icons.verified_user_outlined, size: 16, color: c.olive), const SizedBox(width: 4), Text(tr('Agronom'), style: TextStyle(color: c.olive, fontWeight: FontWeight.w700))]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Row(children: [stat(p.posts, tr('Post')), stat(p.followers, tr('Obunachi')), stat(p.following, tr('Obuna'))]),
        ),
        const SizedBox(height: 14),
        if (mine)
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(AppIcons.edit),
              label: Text(tr('Profilni tahrirlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          )
        else if (p.isBlocked)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('Siz bu foydalanuvchini bloklagansiz'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 4),
              Text(tr("Uning postlari va izohlari sizga ko'rinmaydi, yozishib bo'lmaydi."), style: TextStyle(fontSize: 14.5, color: c.muted)),
              const SizedBox(height: 10),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: _busy ? null : () => _block(p, false), child: Text(tr('Blokdan chiqarish'))),
            ]),
          )
        else
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: p.isFollowing
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: c.text, side: BorderSide(color: c.lineStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _busy ? null : () => _follow(false),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(tr('Obunani bekor qilish'), maxLines: 1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _busy ? null : () => _follow(true),
                        child: Text(tr("Obuna bo'lish"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: c.primaryDark, side: BorderSide(color: c.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _busy ? null : _message,
                  icon: const Icon(AppIcons.chat),
                  label: Text(tr('Xabar yozish'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        const SizedBox(height: 16),
        ChipTabs(tabs: [('posts', tr('Postlar')), ('about', tr('Haqida'))], selected: _tab, onSelect: (t) => setState(() => _tab = t)),
        body,
      ]),
    );
  }
}
