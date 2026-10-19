import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// A02 Saqlanganlar: Barchasi / Postlar / O'simliklar / Kasalliklar / Vositalar, qidiruv. Element o'z sahifasini
/// ochadi. O'chirilgan obyekt uchun placeholder va "Olib tashlash". Olib tashlash optimistik, xatoda tiklanadi.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});
  @override
  ConsumerState<SavedScreen> createState() => _SavedState();
}

class _SavedState extends ConsumerState<SavedScreen> {
  String _tab = 'all', _q = '';
  final Set<String> _removing = {};

  static Map<String, String> get _labels => {'post': tr('Postlar'), 'plant': tr("O'simliklar"), 'disease': tr('Kasalliklar'), 'medicine': tr('Vositalar')};

  Future<void> _remove(Bookmark b) async {
    setState(() => _removing.add(b.key));
    try {
      await ref.read(communityRepoProvider).removeBookmark(b.kind, b.targetId);
      ref.invalidate(bookmarksProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _removing.remove(b.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(bookmarksProvider);
    final all = v.value;
    Widget body;
    if (all == null && v.hasError) {
      body = BlockError(error: v.error!, what: tr('Saqlanganlar'), onRetry: () => ref.invalidate(bookmarksProvider));
    } else if (all == null) {
      body = Column(children: [for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: Skeleton(height: 76))]);
    } else {
      final q = _q.trim().toLowerCase();
      final shown = all
          .where((b) => !_removing.contains(b.key))
          .where((b) => _tab == 'all' || b.kind == _tab)
          .where((b) => q.isEmpty || '${b.title ?? ''} ${b.subtitle ?? ''}'.toLowerCase().contains(q))
          .toList();
      if (all.isEmpty) {
        body = Column(children: [
          EmptyNote(tr("Hali hech narsa saqlanmagan. Post yoki ma'lumotnoma sahifasidagi belgi bilan saqlang."), icon: Icons.bookmark_border_rounded),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            OutlinedButton(onPressed: () => context.push('/catalog'), child: Text(tr("Ma'lumotnoma"))),
            OutlinedButton(onPressed: () => context.go('/help?tab=comm'), child: Text(tr('Jamoat'))),
          ]),
        ]);
      } else if (shown.isEmpty) {
        body = EmptyNote(tr('Hech narsa topilmadi'), icon: Icons.search_off_rounded);
      } else {
        body = Column(children: [for (final b in shown) _Tile(b: b, label: _labels[b.kind] ?? b.kind, onRemove: () => _remove(b))]);
      }
    }
    return PageShell(
      maxWidth: 760,
      padBottom: false,
      onRefresh: () async => ref.invalidate(bookmarksProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TopBar(title: tr('Saqlanganlar')),
        if ((all?.length ?? 0) > 0) ...[
          TextField(
            onChanged: (s) => setState(() => _q = s),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(hintText: tr('Saqlanganlardan qidirish'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(height: 10),
          ChipTabs(tabs: [('all', tr('Barchasi')), for (final e in _labels.entries) (e.key, e.value)], selected: _tab, onSelect: (t) => setState(() => _tab = t)),
          const SizedBox(height: 6),
        ],
        body,
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.b, required this.label, required this.onRemove});
  final Bookmark b;
  final String label;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final img = AppConfig.mediaUrl(b.imageUrl);
    // Katalog rasmlari ilova ichida (assets) — serverda URL bo'lmasa shulardan olinadi
    final asset = !b.exists ? null : switch (b.kind) { 'plant' => CatalogImages.plant(b.title), 'disease' => CatalogImages.disease(b.aiLabel), _ => null };
    final icon = switch (b.kind) { 'post' => Icons.article_outlined, 'plant' => Icons.eco_outlined, 'disease' => Icons.coronavirus_outlined, _ => Icons.science_outlined };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: b.exists ? c.card : c.cream2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: b.exists ? () => context.push(b.route) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  color: c.oliveSoft,
                  child: asset != null
                      ? Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, color: c.olive))
                      : img != null && b.exists
                          ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, color: c.olive))
                          : Icon(icon, color: c.olive),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
                  Text(b.exists ? trData(b.title ?? '') : tr("Bu element o'chirilgan yoki mavjud emas"),
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: b.exists ? c.text : c.muted)),
                  if (b.exists && (b.subtitle ?? '').isNotEmpty)
                    Text(trData(b.subtitle), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted)),
                ]),
              ),
              IconButton(tooltip: tr('Saqlanganlardan olib tashlash'), onPressed: onRemove, icon: Icon(Icons.bookmark_remove_outlined, color: c.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
