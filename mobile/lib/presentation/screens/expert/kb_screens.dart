import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../catalog/catalog_screen.dart';
import 'expert_shell.dart';

const _riskOrder = {'high': 0, 'medium': 1, 'low': 2};

/// Bilimlar bazasi: kasallik / dori / o'simlik tahrirlash va o'zgarishlar tarixi.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});
  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeState();
}

class _KnowledgeState extends ConsumerState<KnowledgeScreen> {
  String _tab = 'diseases';

  Future<void> _add() async {
    final kind = await showSheet<String>(
      context,
      title: tr("Yangi qo'shish"),
      builder: (ctx) => Column(
        children: [
          ListRow(icon: AppIcons.virus, label: tr('Kasallik'), onTap: () => Navigator.pop(ctx, 'disease')),
          ListRow(icon: AppIcons.pill, label: tr('Dori'), onTap: () => Navigator.pop(ctx, 'medicine')),
          ListRow(icon: AppIcons.plant, label: tr("O'simlik"), onTap: () => Navigator.pop(ctx, 'plant')),
        ],
      ),
    );
    if (kind != null && mounted) context.push('/expert/kb/$kind/new');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ExpertPage(
      current: '/expert/kb',
      onRefresh: () async {
        ref.invalidate(diseasesProvider);
        ref.invalidate(medicinesProvider);
        ref.invalidate(plantsProvider);
        ref.invalidate(catalogChangesProvider);
      },
      children: [
        ExpertHeader(
          title: tr('Bilimlar bazasi'),
          trailing: CircleIconButton(icon: AppIcons.plus, tooltip: tr("Qo'shish"), onTap: _add, color: c.expert),
        ),
        SegmentTabs(
          expert: true,
          tabs: [('diseases', tr('Kasalliklar')), ('medicines', tr('Dorilar')), ('plants', tr("O'simliklar")), ('history', tr('Tarix'))],
          selected: _tab,
          onSelect: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 14),
        switch (_tab) {
          'medicines' => AsyncView(
            value: ref.watch(medicinesProvider),
            onRetry: () => ref.invalidate(medicinesProvider),
            data: (list) => Column(children: [for (final m in list) MedicineRow(m, onTap: () => context.push('/expert/kb/medicine/${m.id}'))]),
          ),
          'plants' => AsyncView(
            value: ref.watch(plantsProvider),
            onRetry: () => ref.invalidate(plantsProvider),
            data: (list) => Column(children: [for (final p in list) PlantRow(p, onTap: () => context.push('/expert/kb/plant/${p.id}'))]),
          ),
          'history' => AsyncView(
            value: ref.watch(catalogChangesProvider),
            onRetry: () => ref.invalidate(catalogChangesProvider),
            data: (list) => list.isEmpty
                ? EmptyNote(tr("Hali o'zgarish yo'q"), icon: Icons.history_rounded)
                : AppCard(
                    shadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final (k, ch) in list.indexed) ...[if (k > 0) Divider(height: 1, color: c.border), _ChangeRow(ch)],
                      ],
                    ),
                  ),
          ),
          _ => AsyncView(
            value: ref.watch(diseasesProvider),
            onRetry: () => ref.invalidate(diseasesProvider),
            data: (list) {
              final sorted = [...list]..sort((a, b) => (_riskOrder[a.riskLevel] ?? 1).compareTo(_riskOrder[b.riskLevel] ?? 1));
              final noImage = sorted.where((d) => CatalogImages.disease(d.aiLabel) == null && d.imageUrl == null).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (noImage.isNotEmpty) ...[
                    NoteBox(
                      kind: NoteKind.risk,
                      icon: Icons.image_not_supported_outlined,
                      title: trf('{0} ta kasallikning rasmi yo\'q', [noImage.length]),
                      text: trf('{0}. Tasdiqlangan dala rasmlaridan tanlang.', [noImage.map((d) => d.name).join(', ')]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final d in sorted) DiseaseRow(d, onTap: () => context.push('/expert/kb/disease/${d.id}')),
                ],
              );
            },
          ),
        },
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow(this.ch);
  final CatalogChange ch;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final verb = switch (ch.action) {
      'create' => tr("qo'shildi"),
      'delete' => tr("o'chirildi"),
      _ => tr('tahrirlandi'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ch.mine ? c.expert : c.border, width: 1.5),
            ),
            child: Avatar(name: ch.userName ?? '?', size: 36, color: ch.mine ? c.expertBg : null, textColor: ch.mine ? c.expert : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ch.summary, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 2),
                Text(
                  '${ch.mine ? tr('Siz') : (ch.userName ?? 'Admin')} · $verb · ${timeAgo(ch.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Tahrirlash ----------
class _Field {
  _Field(this.key, this.label, {this.lines = 1, this.hint});
  final String key, label;
  final int lines;
  final String? hint;
}

/// Kasallik / dori / o'simlikni tahrirlash yoki qo'shish (id == null). O'zgarish tarixga yoziladi.
class KbEditScreen extends ConsumerStatefulWidget {
  const KbEditScreen({super.key, required this.entity, this.id});
  final String entity; // disease | medicine | plant
  final String? id;
  @override
  ConsumerState<KbEditScreen> createState() => _KbEditState();
}

class _KbEditState extends ConsumerState<KbEditScreen> {
  final _ctl = <String, TextEditingController>{};
  String? _risk = 'medium';
  String? _plantId;
  String? _imageUrl, _aiLabel;
  bool _loaded = false, _busy = false;
  Map<String, dynamic> _initial = const {}; // tahrirlashda faqat o'zgargan maydonlar yuboriladi (tarix aniq bo'lsin)

  List<_Field> get _fields => switch (widget.entity) {
    'medicine' => [
      _Field('name', tr('Nomi')),
      _Field('active_ingredient', tr("Ta'sir etuvchi modda"), hint: tr('Masalan: Mis oksixlorid 90%')),
      _Field('description', tr('Tavsif'), lines: 3),
      _Field('usage', tr("Qo'llash me'yori"), lines: 2, hint: tr('40 g / 10 l suv, 7–10 kun oralig\'ida')),
      _Field('precautions', tr('Ehtiyot choralari'), lines: 2),
      _Field('manufacturer', tr('Ishlab chiqaruvchi')),
    ],
    'plant' => [
      _Field('name', tr('Nomi')),
      _Field('scientific_name', tr('Ilmiy nomi'), hint: 'Solanum lycopersicum'),
      _Field('description', tr('Tavsif'), lines: 3),
      _Field('care_info', tr('Parvarish'), lines: 3),
    ],
    _ => [
      _Field('name', tr('Nomi')),
      _Field('symptoms', tr('Belgilari'), lines: 3),
      _Field('causes', tr('Sababi'), lines: 2),
      _Field('treatment', tr('Davolash'), lines: 3),
      _Field('prevention', tr('Oldini olish'), lines: 2),
    ],
  };

  TextEditingController _c(String k) => _ctl.putIfAbsent(k, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    if (widget.id == null) _loaded = true;
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id == null) return;
    final repo = ref.read(catalogRepoProvider);
    try {
      final Map<String, String?> v;
      switch (widget.entity) {
        case 'medicine':
          final m = await repo.medicine(id);
          v = {
            'name': m.name,
            'active_ingredient': m.activeIngredient,
            'description': m.description,
            'usage': m.usage,
            'precautions': m.precautions,
            'manufacturer': m.manufacturer,
          };
        case 'plant':
          final p = await repo.plant(id);
          v = {'name': p.name, 'scientific_name': p.scientificName, 'description': p.description, 'care_info': p.careInfo};
          _imageUrl = p.imageUrl;
        default:
          final d = await repo.disease(id);
          v = {'name': d.name, 'symptoms': d.symptoms, 'causes': d.causes, 'treatment': d.treatment, 'prevention': d.prevention};
          _risk = d.riskLevel ?? 'medium';
          _plantId = d.plantId;
          _imageUrl = d.imageUrl;
          _aiLabel = d.aiLabel;
      }
      for (final e in v.entries) {
        _c(e.key).text = e.value ?? '';
      }
      _initial = _data();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_c('name').text.trim().length < 2) {
      showToast(context, tr('Nomini yozing'));
      return;
    }
    if (widget.entity == 'disease' && widget.id == null && _plantId == null) {
      showToast(context, tr("O'simlikni tanlang"));
      return;
    }
    final data = _data();
    if (widget.id != null) data.removeWhere((k, v) => _initial[k] == v);
    if (data.isEmpty) {
      showToast(context, tr("O'zgarish yo'q"));
      context.pop();
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(catalogRepoProvider);
      switch (widget.entity) {
        case 'medicine':
          await repo.saveMedicine(data, id: widget.id);
          ref.invalidate(medicinesProvider);
          if (widget.id != null) ref.invalidate(medicineProvider(widget.id!));
        case 'plant':
          await repo.savePlant(data, id: widget.id);
          ref.invalidate(plantsProvider);
          if (widget.id != null) ref.invalidate(plantProvider(widget.id!));
        default:
          await repo.saveDisease(data, id: widget.id);
          ref.invalidate(diseasesProvider);
          if (widget.id != null) ref.invalidate(diseaseProvider(widget.id!));
      }
      ref.invalidate(catalogChangesProvider);
      if (!mounted) return;
      showToast(context, widget.id == null ? tr("Qo'shildi") : tr('Saqlandi'));
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _data() {
    final data = <String, dynamic>{for (final f in _fields) f.key: _c(f.key).text.trim().isEmpty ? null : _c(f.key).text.trim()};
    if (widget.entity == 'disease') {
      data['risk_level'] = _risk;
      if (_plantId != null) data['plant_id'] = _plantId;
      if (_imageUrl != null) data['image_url'] = _imageUrl;
    }
    return data;
  }

  Future<void> _pickImage() async {
    final label = _aiLabel;
    if (label == null) {
      showToast(context, tr("Bu kasallikning AI sinfi yo'q — dataset rasmlari topilmaydi"));
      return;
    }
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => _DatasetPicker(label: label),
    );
    if (url != null) setState(() => _imageUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final title = switch (widget.entity) {
      'medicine' => tr('Dori'),
      'plant' => tr("O'simlik"),
      _ => tr('Kasallik'),
    };
    final asset = widget.entity == 'disease' ? CatalogImages.disease(_aiLabel) : null;
    return PageShell(
      padBottom: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: c.expert,
                    foregroundColor: c.onExpert,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  onPressed: _busy || !_loaded ? null : _save,
                  icon: _busy
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onExpert))
                      : const Icon(AppIcons.check),
                  label: Text(tr('Saqlash'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ),
              ),
            ),
          ),
        ),
      ),
      child: !_loaded
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  title: widget.id == null ? trf("Yangi: {0}", [title.toLowerCase()]) : tr('Tahrirlash'),
                  subtitle: widget.id == null ? null : _c('name').text,
                  actions: [
                    if (widget.id != null)
                      CircleIconButton(
                        icon: AppIcons.eye,
                        tooltip: tr("Dehqon ko'rinishi"),
                        onTap: () => context.push('/catalog/${widget.entity}/${widget.id}'),
                      ),
                  ],
                ),
                if (widget.entity == 'disease' && widget.id != null) ...[
                  Stack(
                    children: [
                      CatalogImage(
                        asset: asset,
                        url: AppConfig.mediaUrl(_imageUrl),
                        width: double.infinity,
                        height: 180,
                        radius: AppRadius.lg,
                        placeholderText: tr("Rasm yo'q"),
                      ),
                      if (asset == null)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: PillButton(label: tr('Datasetdan tanlash'), icon: AppIcons.gallery, style: PillStyle.light, onPressed: _pickImage),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (widget.entity == 'disease' && widget.id == null) ...[
                  FieldLabel(tr("O'simlik")),
                  AsyncView(
                    value: ref.watch(plantsProvider),
                    data: (plants) => ChipTabs(
                      tabs: [for (final p in plants) (p.id, p.name)],
                      selected: _plantId ?? '',
                      onSelect: (v) => setState(() => _plantId = v),
                    ),
                  ),
                ],
                for (final f in _fields) ...[
                  FieldLabel(f.label),
                  TextField(
                    controller: _c(f.key),
                    minLines: f.lines,
                    maxLines: f.lines == 1 ? 1 : 8,
                    decoration: InputDecoration(hintText: f.hint),
                  ),
                  if (f.key == 'name' && widget.entity == 'disease') ...[
                    FieldLabel(tr('Xavf darajasi')),
                    SegmentTabs(
                      expert: true,
                      tabs: [('low', tr('Past')), ('medium', tr("O'rta")), ('high', tr('Yuqori'))],
                      selected: _risk ?? 'medium',
                      onSelect: (v) => setState(() => _risk = v),
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                Text(tr("O'zgarish «Tarix»ga yoziladi; admin ko'radi va kerak bo'lsa qaytaradi."), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}

/// Agronomlar tasdiqlagan dala rasmlaridan ma'lumotnoma rasmini tanlash.
class _DatasetPicker extends ConsumerWidget {
  const _DatasetPicker({required this.label});
  final String label;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (ctx, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(tr('Datasetdan tanlash'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('Agronomlar tasdiqlagan dala rasmlari. Belgilari aniq ko\'ringanini tanlang.'), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        AsyncView(
          value: ref.watch(datasetImagesProvider(label)),
          onRetry: () => ref.invalidate(datasetImagesProvider(label)),
          data: (imgs) => imgs.isEmpty
              ? EmptyNote(
                  tr("Hali tasdiqlangan rasm yo'q. Navbatda shu kasallikni tasdiqlasangiz, rasmi shu yerda paydo bo'ladi."),
                  icon: Icons.image_search_rounded,
                )
              : GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final i in imgs)
                      Semantics(
                        button: true,
                        label: tr('Rasmni tanlash'),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => Navigator.pop(ctx, i.imageUrl),
                          child: CatalogImage(url: AppConfig.mediaUrl(i.imageUrl)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
