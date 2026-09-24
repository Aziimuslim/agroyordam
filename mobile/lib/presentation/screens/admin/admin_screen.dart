import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'dataset_tab.dart';

final _statsProvider = FutureProvider.autoDispose((ref) async {
  final r = ref.watch(adminRepoProvider);
  return (await r.platform(), await r.ai(), await r.revenue());
});
final _usersProvider = FutureProvider.autoDispose.family<List<AppUser>, String>((ref, q) => ref.watch(adminRepoProvider).users(q: q));
final _reportsProvider = FutureProvider.autoDispose((ref) => ref.watch(adminRepoProvider).reports());

/// Admin panel (Flutter Web'da keng ekranga moslashadi): statistika, dataset, foydalanuvchilar, katalog, shikoyatlar.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminState();
}

class _AdminState extends ConsumerState<AdminScreen> {
  String _tab = 'stats';

  @override
  Widget build(BuildContext context) {
    return PageShell(
      maxWidth: 1100,
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Admin panel', subtitle: 'AgroYordam boshqaruvi'),
        ChipTabs(
          tabs: const [('stats', 'Statistika'), ('dataset', 'Dataset'), ('users', 'Foydalanuvchilar'), ('catalog', 'Katalog'), ('reports', 'Shikoyatlar')],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        switch (_tab) {
          'dataset' => const DatasetTab(),
          'users' => const _UsersTab(),
          'catalog' => const _CatalogTab(),
          'reports' => const _ReportsTab(),
          _ => const _StatsTab(),
        },
      ]),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AsyncView(
      value: ref.watch(_statsProvider),
      onRetry: () => ref.invalidate(_statsProvider),
      data: (s) {
        final (platform, ai, revenue) = s;
        Widget tile(String label, Object value, IconData icon) => SizedBox(
              width: 200,
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Row(children: [
                  ThumbIcon(icon: icon, size: 40, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.primary)),
                      Text(label, style: TextStyle(fontSize: 11.5, color: c.muted, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            );
        final top = (ai['top_diseases'] as List).cast<Map>();
        final maxCount = top.isEmpty ? 1 : top.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Platforma'),
          Wrap(spacing: 12, runSpacing: 12, children: [
            tile('Foydalanuvchilar', platform['users_total'], AppIcons.user),
            tile('Yangi (7 kun)', platform['users_new_7d'], Icons.person_add_alt_outlined),
            tile('Premium', platform['premium_users'], AppIcons.star),
            tile('Ekinlar', platform['crops_total'], AppIcons.leaf),
            tile('Postlar', platform['posts_total'], AppIcons.chat),
            tile('Kutilayotgan shikoyat', platform['reports_pending'], AppIcons.flag),
          ]),
          const SizedBox(height: 18),
          const SectionTitle('AI tashxis'),
          Wrap(spacing: 12, runSpacing: 12, children: [
            tile('Jami tashxis', ai['diagnoses_total'], AppIcons.camera),
            tile('Oxirgi 7 kun', ai['diagnoses_7d'], AppIcons.history),
            tile("O'rtacha ishonch", '${ai['avg_confidence']}%', AppIcons.chart),
            tile('Aniqlanmagan', ai['unrecognized'], Icons.help_outline_rounded),
          ]),
          const SizedBox(height: 14),
          if (top.isNotEmpty)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Eng ko\'p uchragan kasalliklar', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final t in top)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(width: 180, child: Text('${t['name']}', overflow: TextOverflow.ellipsis)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: (t['count'] as int) / maxCount, minHeight: 10, backgroundColor: c.cream2, color: c.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('${t['count']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
          const SectionTitle('Daromad'),
          Wrap(spacing: 12, runSpacing: 12, children: [
            tile('Jami tushum', formatMoney(revenue['revenue_total'] as num), AppIcons.card),
            tile('Faol obunalar', revenue['active_subscriptions'], AppIcons.star),
            for (final p in (revenue['by_provider'] as List).cast<Map>()) tile('${p['provider']}', formatMoney(p['amount'] as num), AppIcons.card),
          ]),
        ]);
      },
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    return Column(children: [
      TextField(
        onSubmitted: (v) => setState(() => _q = v.trim()),
        decoration: InputDecoration(hintText: 'Ism, username, email yoki telefon (Enter)', prefixIcon: Icon(Icons.search_rounded, color: c.muted)),
      ),
      const SizedBox(height: 14),
      AsyncView(
        value: ref.watch(_usersProvider(_q)),
        onRetry: () => ref.invalidate(_usersProvider(_q)),
        data: (users) => Column(children: [
          for (final u in users)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Avatar(name: u.fullName, url: u.avatarUrl, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('@${u.username} · ${u.email ?? u.phone ?? ''}', style: TextStyle(color: c.muted, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (u.isPremium) Padding(padding: const EdgeInsets.only(right: 6), child: Tag('Premium', bg: c.gold, fg: c.onGold)),
                Tag(u.role),
                const SizedBox(width: 8),
                if (u.role != 'admin' && me?.role == 'admin')
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(adminRepoProvider).block(u.id, u.isActive);
                        ref.invalidate(_usersProvider(_q));
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                    child: Text(u.isActive ? 'Bloklash' : 'Blokdan chiqarish', style: TextStyle(color: u.isActive ? c.danger : c.success, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab();

  Future<void> _editPlant(BuildContext context, WidgetRef ref, [Plant? p]) async {
    final name = TextEditingController(text: p?.name), sci = TextEditingController(text: p?.scientificName);
    final desc = TextEditingController(text: p?.description), care = TextEditingController(text: p?.careInfo);
    final ok = await showSheet<bool>(context, title: p == null ? "O'simlik qo'shish" : "O'simlikni tahrirlash", builder: (ctx) => Column(children: [
          TextField(controller: name, decoration: const InputDecoration(hintText: 'Nomi')),
          const SizedBox(height: 10),
          TextField(controller: sci, decoration: const InputDecoration(hintText: 'Ilmiy nomi')),
          const SizedBox(height: 10),
          TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(hintText: 'Tavsif')),
          const SizedBox(height: 10),
          TextField(controller: care, maxLines: 2, decoration: const InputDecoration(hintText: 'Parvarish')),
          const SizedBox(height: 14),
          PillButton(label: 'Saqlash', block: true, onPressed: () => Navigator.pop(ctx, true)),
        ]));
    if (ok != true) return;
    try {
      await ref.read(catalogRepoProvider).savePlant({'name': name.text, 'scientific_name': sci.text, 'description': desc.text, 'care_info': care.text}, id: p?.id);
      ref.invalidate(plantsProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _editDisease(BuildContext context, WidgetRef ref, List<Plant> plants, [Disease? d]) async {
    final ctrls = {
      for (final k in ['name', 'ai_label', 'symptoms', 'causes', 'treatment', 'prevention'])
        k: TextEditingController(text: switch (k) {
          'name' => d?.name,
          'ai_label' => d?.aiLabel,
          'symptoms' => d?.symptoms,
          'causes' => d?.causes,
          'treatment' => d?.treatment,
          _ => d?.prevention,
        }),
    };
    String? plantId = d?.plantId;
    String risk = d?.riskLevel ?? 'medium';
    const labels = {'name': 'Nomi', 'ai_label': 'AI label (masalan Tomato_Late_blight)', 'symptoms': 'Belgilari', 'causes': 'Sabablari', 'treatment': 'Davolash', 'prevention': 'Oldini olish'};
    final ok = await showSheet<bool>(context, title: d == null ? "Kasallik qo'shish" : 'Kasallikni tahrirlash', builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Column(children: [
            DropdownButtonFormField<String>(
              initialValue: plantId,
              isExpanded: true,
              hint: const Text("O'simlik"),
              items: [for (final p in plants) DropdownMenuItem(value: p.id, child: Text(p.name))],
              onChanged: (v) => setS(() => plantId = v),
            ),
            const SizedBox(height: 10),
            for (final e in ctrls.entries) ...[
              TextField(controller: e.value, maxLines: e.key == 'name' || e.key == 'ai_label' ? 1 : 2, decoration: InputDecoration(hintText: labels[e.key])),
              const SizedBox(height: 10),
            ],
            ChipTabs(tabs: const [('low', 'Past'), ('medium', "O'rta"), ('high', 'Yuqori')], selected: risk, onSelect: (v) => setS(() => risk = v)),
            PillButton(label: 'Saqlash', block: true, onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ));
    if (ok != true) return;
    try {
      await ref.read(catalogRepoProvider).saveDisease({
        for (final e in ctrls.entries) e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        'plant_id': plantId,
        'risk_level': risk,
      }, id: d?.id);
      ref.invalidate(diseasesProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _editMedicine(BuildContext context, WidgetRef ref, [Medicine? m]) async {
    final name = TextEditingController(text: m?.name), ing = TextEditingController(text: m?.activeIngredient);
    final usage = TextEditingController(text: m?.usage), prec = TextEditingController(text: m?.precautions);
    final ok = await showSheet<bool>(context, title: m == null ? "Dori qo'shish" : 'Dorini tahrirlash', builder: (ctx) => Column(children: [
          TextField(controller: name, decoration: const InputDecoration(hintText: 'Nomi')),
          const SizedBox(height: 10),
          TextField(controller: ing, decoration: const InputDecoration(hintText: "Ta'sir etuvchi modda")),
          const SizedBox(height: 10),
          TextField(controller: usage, decoration: const InputDecoration(hintText: "Qo'llash / doza")),
          const SizedBox(height: 10),
          TextField(controller: prec, decoration: const InputDecoration(hintText: 'Ehtiyot choralari')),
          const SizedBox(height: 14),
          PillButton(label: 'Saqlash', block: true, onPressed: () => Navigator.pop(ctx, true)),
        ]));
    if (ok != true) return;
    try {
      await ref.read(catalogRepoProvider).saveMedicine({'name': name.text, 'active_ingredient': ing.text, 'usage': usage.text, 'precautions': prec.text}, id: m?.id);
      ref.invalidate(medicinesProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _linkMedicines(BuildContext context, WidgetRef ref, Disease d, List<Medicine> meds) async {
    final full = await ref.read(catalogRepoProvider).disease(d.id);
    if (!context.mounted) return;
    final selected = {for (final m in full.medicines) m.id: TextEditingController(text: m.recommendation)};
    final ok = await showSheet<bool>(context, title: '${d.name}: dorilar', builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Column(children: [
            for (final m in meds) ...[
              CheckboxListTile(
                value: selected.containsKey(m.id),
                title: Text(m.name),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setS(() => v == true ? selected[m.id] = TextEditingController() : selected.remove(m.id)),
              ),
              if (selected.containsKey(m.id)) TextField(controller: selected[m.id], decoration: const InputDecoration(hintText: 'Tavsiya / doza')),
            ],
            const SizedBox(height: 14),
            PillButton(label: 'Saqlash', block: true, onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ));
    if (ok != true) return;
    try {
      await ref.read(catalogRepoProvider).linkMedicines(d.id, [for (final e in selected.entries) {'medicine_id': e.key, 'recommendation': e.value.text}]);
      if (context.mounted) showToast(context, 'Saqlandi');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final plants = ref.watch(plantsProvider).value ?? [];
    final meds = ref.watch(medicinesProvider).value ?? [];
    Widget header(String t, VoidCallback onAdd) => SectionTitle(t, action: "+ Qo'shish", onAction: onAdd);
    Widget row(String title, String? sub, VoidCallback onEdit, Future<void> Function() onDelete, {VoidCallback? extra, String? extraLabel}) => AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (sub != null) Text(sub, style: TextStyle(color: c.muted, fontSize: 12)),
              ]),
            ),
            if (extra != null) TextButton(onPressed: extra, child: Text(extraLabel!)),
            IconButton(icon: Icon(AppIcons.edit, color: c.primaryDark), onPressed: onEdit, tooltip: 'Tahrirlash'),
            IconButton(
              icon: Icon(AppIcons.trash, color: c.danger),
              tooltip: "O'chirish",
              onPressed: () async {
                if (await confirm(context, "O'chirish", '$title o\'chirilsinmi?', ok: "O'chirish", danger: true)) {
                  try {
                    await onDelete();
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                }
              },
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      header("O'simliklar (${plants.length})", () => _editPlant(context, ref)),
      for (final p in plants)
        row(p.name, p.scientificName, () => _editPlant(context, ref, p), () async {
          await ref.read(catalogRepoProvider).deletePlant(p.id);
          ref.invalidate(plantsProvider);
        }),
      const SizedBox(height: 10),
      AsyncView(
        value: ref.watch(diseasesProvider),
        data: (list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header('Kasalliklar (${list.length})', () => _editDisease(context, ref, plants)),
          for (final d in list)
            row(d.name, '${d.plantName ?? '-'} · ${d.aiLabel ?? 'ai_label yo\'q'} · ${riskLabels[d.riskLevel] ?? ''}', () => _editDisease(context, ref, plants, d), () async {
              await ref.read(catalogRepoProvider).deleteDisease(d.id);
              ref.invalidate(diseasesProvider);
            }, extra: () => _linkMedicines(context, ref, d, meds), extraLabel: 'Dorilar'),
        ]),
      ),
      const SizedBox(height: 10),
      header('Dorilar (${meds.length})', () => _editMedicine(context, ref)),
      for (final m in meds)
        row(m.name, m.activeIngredient, () => _editMedicine(context, ref, m), () async {
          await ref.read(catalogRepoProvider).deleteMedicine(m.id);
          ref.invalidate(medicinesProvider);
        }),
    ]);
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AsyncView(
      value: ref.watch(_reportsProvider),
      onRetry: () => ref.invalidate(_reportsProvider),
      data: (list) {
        final pending = list.where((r) => r['status'] == 'pending').toList();
        if (pending.isEmpty) return const EmptyNote("Kutilayotgan shikoyat yo'q", icon: AppIcons.flag);
        return Column(children: [
          for (final r in pending)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Tag(r['post_id'] != null ? 'Post' : 'Izoh', bg: c.dangerBg, fg: c.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${r['reason'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(timeAgo(parseDate(r['created_at'])), style: TextStyle(color: c.muted, fontSize: 12)),
                ]),
                if (r['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['description']}')),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  MiniButton(label: 'Kontentni o\'chirish', filled: true, onTap: () async {
                    await ref.read(adminRepoProvider).resolve(r['id'], remove: true);
                    ref.invalidate(_reportsProvider);
                  }),
                  MiniButton(label: 'Rad etish', onTap: () async {
                    await ref.read(adminRepoProvider).resolve(r['id']);
                    ref.invalidate(_reportsProvider);
                  }),
                ]),
              ]),
            ),
        ]);
      },
    );
  }
}
