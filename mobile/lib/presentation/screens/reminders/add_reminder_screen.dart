import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';

class AddReminderScreen extends ConsumerStatefulWidget {
  const AddReminderScreen({super.key, this.cropId});
  final String? cropId;
  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderState();
}

class _AddReminderState extends ConsumerState<AddReminderScreen> {
  final _title = TextEditingController(), _desc = TextEditingController();
  late String? _cropId = widget.cropId;
  String _type = 'watering';
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  bool _loading = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showToast(context, 'Sarlavhani kiriting');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(gardenRepoProvider).createReminder({
        'title': _title.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'reminder_type': _type,
        'reminder_date': DateFormat('yyyy-MM-dd').format(_date),
        if (_time != null) 'reminder_time': '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00',
        'crop_id': _cropId,
      });
      ref.invalidate(remindersProvider);
      if (mounted) {
        showToast(context, "Eslatma qo'shildi");
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
    final c = context.c;
    final crops = ref.watch(cropsProvider);
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Yangi eslatma'),
        const FieldLabel('Turi'),
        ChipTabs(
          tabs: [for (final e in reminderTypeLabels.entries) (e.key, e.value)],
          selected: _type,
          onSelect: (v) => setState(() => _type = v),
        ),
        const FieldLabel('Sarlavha'),
        TextField(controller: _title, decoration: const InputDecoration(hintText: "Masalan: Chuqur sug'orish")),
        const FieldLabel('Tavsif'),
        TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Ixtiyoriy')),
        const FieldLabel('Ekin'),
        crops.maybeWhen(
          data: (list) => DropdownButtonFormField<String?>(
            initialValue: list.any((e) => e.id == _cropId) ? _cropId : null,
            isExpanded: true,
            dropdownColor: c.card,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Umumiy')),
              for (final cr in list) DropdownMenuItem<String?>(value: cr.id, child: Text(cr.name)),
            ],
            onChanged: (v) => setState(() => _cropId = v),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Sana'),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _date);
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(decoration: const InputDecoration(), child: Text(DateFormat('dd.MM.yyyy').format(_date))),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Vaqt'),
              InkWell(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0));
                  if (t != null) setState(() => _time = t);
                },
                child: InputDecorator(decoration: const InputDecoration(), child: Text(_time?.format(context) ?? 'Ixtiyoriy', style: TextStyle(color: _time == null ? c.muted : c.text))),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        PillButton(label: 'Saqlash', block: true, loading: _loading, onPressed: _save),
      ]),
    );
  }
}
