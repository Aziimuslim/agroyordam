import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key, this.crop});
  final Crop? crop; // berilsa — tahrirlash
  @override
  ConsumerState<AddCropScreen> createState() => _AddCropState();
}

class _AddCropState extends ConsumerState<AddCropScreen> {
  late final _name = TextEditingController(text: widget.crop?.name);
  late final _variety = TextEditingController(text: widget.crop?.variety);
  late final _area = TextEditingController(text: widget.crop?.area?.toString());
  late final _location = TextEditingController(text: widget.crop?.location);
  late final _notes = TextEditingController(text: widget.crop?.notes);
  late String? _plantId = widget.crop?.plantId;
  late DateTime? _date = widget.crop?.plantingDate;
  bool _loading = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, 'Ekin nomini kiriting');
      return;
    }
    setState(() => _loading = true);
    final data = {
      'name': _name.text.trim(),
      'plant_id': _plantId,
      'variety': _variety.text.trim().isEmpty ? null : _variety.text.trim(),
      'area': _area.text.trim().isEmpty ? null : _area.text.trim().replaceAll(',', '.'),
      'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'planting_date': _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
    };
    try {
      final repo = ref.read(gardenRepoProvider);
      if (widget.crop == null) {
        await repo.createCrop(data);
      } else {
        await repo.updateCrop(widget.crop!.id, data);
        ref.invalidate(cropProvider(widget.crop!.id));
      }
      ref.invalidate(cropsProvider);
      if (mounted) {
        showToast(context, widget.crop == null ? "Ekin qo'shildi" : 'Saqlandi');
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plants = ref.watch(plantsProvider);
    final c = context.c;
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: widget.crop == null ? "Ekin qo'shish" : 'Ekinni tahrirlash'),
        const FieldLabel('Nomi (masalan, taxallus)'),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'Masalan: Yashilvoy')),
        const FieldLabel('Ekin turi'),
        plants.when(
          data: (list) => DropdownButtonFormField<String>(
            initialValue: _plantId,
            isExpanded: true,
            dropdownColor: c.card,
            hint: const Text('Tanlang'),
            items: [for (final p in list) DropdownMenuItem(value: p.id, child: Text(p.name))],
            onChanged: (v) {
              setState(() => _plantId = v);
              if (_name.text.isEmpty && v != null) _name.text = list.firstWhere((p) => p.id == v).name;
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Turlarni yuklab bo\'lmadi', style: TextStyle(color: c.danger)),
        ),
        const FieldLabel('Navi'),
        TextField(controller: _variety, decoration: const InputDecoration(hintText: 'Masalan: Pushti gigant')),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Maydon (sotix)'),
              TextField(controller: _area, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '5')),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Ekilgan sana'),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(2015), lastDate: DateTime.now(), initialDate: _date ?? DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(_date == null ? 'Tanlang' : DateFormat('dd.MM.yyyy').format(_date!), style: TextStyle(color: _date == null ? c.muted : c.text)),
                ),
              ),
            ]),
          ),
        ]),
        const FieldLabel('Joylashuv'),
        TextField(controller: _location, decoration: const InputDecoration(hintText: 'Masalan: Issiqxona, 2-qator')),
        const FieldLabel('Izoh'),
        TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(hintText: 'Ixtiyoriy')),
        const SizedBox(height: 24),
        PillButton(label: 'Saqlash', block: true, loading: _loading, onPressed: _save),
      ]),
    );
  }
}
