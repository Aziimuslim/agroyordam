import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/bottom_nav.dart';
import '../../../core/widgets/crop_status.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'crop_actions.dart';
import 'crop_card.dart';

/// S02 Mening bog'im: qidiruv + Barchasi / E'tibor kerak / Arxiv filtrlari birga ishlaydi,
/// foizsiz holat belgilari, kartadagi "⋮" → tahrirlash yoki arxivlash.
/// Filtr, qidiruv va skroll S06 dan qaytganda saqlanadi (ekran stekda qoladi).
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});
  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _needsCare(Crop c) {
    final s = cropState(c);
    return s == CropState.attention || s == CropState.watch;
  }

  Future<void> _menu(Crop crop) async {
    final c = context.c;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(crop.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
          ),
          if (!crop.isArchived)
            ListTile(
              minTileHeight: 52,
              leading: const Icon(AppIcons.edit),
              title: Text(tr('Tahrirlash')),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          ListTile(
            minTileHeight: 52,
            leading: Icon(crop.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            title: Text(crop.isArchived ? tr('Arxivdan tiklash') : tr('Arxivlash')),
            onTap: () => Navigator.pop(ctx, crop.isArchived ? 'restore' : 'archive'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        context.push('/garden/${crop.id}/edit');
      case 'archive':
        await archiveCrop(context, ref, crop);
      case 'restore':
        await restoreCrop(context, ref, crop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final archive = _filter == 'archived';
    final value = ref.watch(archive ? archivedCropsProvider : cropsProvider);
    final active = ref.watch(cropsProvider).value;
    final q = _search.text.trim().toLowerCase();

    Widget body;
    final list = value.value;
    if (list == null && value.hasError) {
      body = BlockError(error: value.error!, what: tr('Ekinlar'), onRetry: () => ref.invalidate(archive ? archivedCropsProvider : cropsProvider));
    } else if (list == null) {
      body = _grid(context, [for (var i = 0; i < 4; i++) const Skeleton(height: 230)]);
    } else {
      var shown = list.where((x) => q.isEmpty || '${x.name} ${x.plantName ?? ''} ${x.variety ?? ''} ${x.location ?? ''}'.toLowerCase().contains(q)).toList();
      if (_filter == 'care') shown = shown.where(_needsCare).toList();
      shown.sort((a, b) => cropStateRank(cropState(a)).compareTo(cropStateRank(cropState(b))));
      final filtered = q.isNotEmpty || _filter == 'care';
      if (list.isEmpty && !archive) {
        body = _EmptyGarden(onAdd: () => context.push('/garden/add'));
      } else if (list.isEmpty) {
        body = EmptyNote(tr("Arxivda ekin yo'q"), icon: Icons.archive_outlined);
      } else if (shown.isEmpty) {
        body = Column(children: [
          EmptyNote(_filter == 'care' && q.isEmpty ? tr("Hozir e'tibor talab qiladigan ekin yo'q") : tr('Hech narsa topilmadi'), icon: Icons.search_off_rounded),
          TextButton(
            onPressed: () => setState(() {
              _search.clear();
              _filter = archive ? 'archived' : 'all';
            }),
            child: Text(tr('Tozalash')),
          ),
        ]);
      } else {
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(trf('{0} ta natija (jami {1})', [shown.length, list.length]), style: TextStyle(color: c.muted, fontSize: 14)),
            ),
          _grid(context, [for (final x in shown) CropCard(crop: x, onMenu: () => _menu(x))]),
        ]);
      }
    }

    final care = active?.where(_needsCare).length ?? 0;
    return PageShell(
      bottom: const AppBottomNav(current: '/garden'),
      maxWidth: 1200,
      onRefresh: () async {
        ref.invalidate(cropsProvider);
        ref.invalidate(archivedCropsProvider);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Semantics(header: true, child: Text(tr("Mening bog'im"), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.text)))),
          Tooltip(
            message: tr("Ekin qo'shish"),
            child: Material(
              color: c.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/garden/add'),
                child: SizedBox(width: 52, height: 52, child: Icon(AppIcons.plus, color: c.onPrimary, size: 28)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (active != null && active.isNotEmpty) ...[
          _Summary(total: active.length, care: care, onCare: () => setState(() => _filter = 'care')),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: tr('Ekinni qidirish...'),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(tooltip: tr('Tozalash'), icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
          ),
        ),
        const SizedBox(height: 12),
        ChipTabs(
          tabs: [('all', tr('Barchasi')), ('care', tr("E'tibor kerak")), ('archived', tr('Arxiv'))],
          selected: _filter,
          onSelect: (v) => setState(() => _filter = v),
        ),
        AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_filter), child: body)),
      ]),
    );
  }

  Widget _grid(BuildContext context, List<Widget> children) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 560 ? 3 : 2);
        const gap = 12.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.care, required this.onCare});
  final int total, care;
  final VoidCallback onCare;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: care > 0,
      child: Material(
        color: c.cream2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: care > 0 ? onCare : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.eco_outlined, color: c.onOliveSoft),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trf('{0} ta ekin', [total]), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                  Text(
                    care > 0 ? trf("{0} tasi e'tibor yoki kuzatuv talab qiladi", [care]) : tr("Hozircha shoshilinch e'tibor talab qiladigan ekin yo'q"),
                    style: TextStyle(fontSize: 14, color: care > 0 ? c.primaryDark : c.muted, fontWeight: care > 0 ? FontWeight.w600 : FontWeight.w400),
                  ),
                ]),
              ),
              if (care > 0) Icon(AppIcons.chevron, color: c.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: c.oliveSoft, shape: BoxShape.circle),
          child: Icon(Icons.eco_outlined, color: c.onOliveSoft, size: 36),
        ),
        const SizedBox(height: 16),
        Text(tr("Bog'ingiz hali bo'sh"), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 6),
        Text(tr("Ekin qo'shsangiz, vazifalar va kuzatuvlar shu yerda ko'rinadi"), textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15)),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: onAdd,
            icon: const Icon(AppIcons.plus),
            label: Text(tr("Birinchi ekinni qo'shing"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
