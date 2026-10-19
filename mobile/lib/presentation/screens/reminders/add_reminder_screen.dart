import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'task_sheet.dart' show askSeriesScope, refreshTasks, remindBeforeLabel, repeatLabel;

/// A03 → Tahrirlash: vazifa serverdan olinadi, so'ng S26 forma mavjud qiymatlar bilan ochiladi.
class EditReminderRoute extends ConsumerWidget {
  const EditReminderRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(reminderProvider(id));
    return v.when(
      data: (r) => AddReminderScreen(reminder: r),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => PageShell(
        padBottom: false,
        child: Column(children: [
          TopBar(title: tr('Eslatmani tahrirlash')),
          AsyncView(value: v, data: (_) => const SizedBox.shrink(), onRetry: () => ref.invalidate(reminderProvider(id))),
        ]),
      ),
    );
  }
}

/// S26 Yangi eslatma / tahrirlash. Tekshiruv TZ bo'yicha (server ham tekshiradi): sarlavha 3–120, sana majburiy,
/// vaqt ixtiyoriy (yo'q — kun bo'yi), takrorlash kunlik/haftalik/oylik/har N kunda + tugash sanasi ≥ boshlanish,
/// izoh ≤ 1000. O'tgan vaqt — tasdiq bilan kechikkan sifatida. Ilovada push yo'q: eslatma ilova ichidagi
/// Bildirishnomalarda chiqadi (yolg'on push va'da qilinmaydi).
class AddReminderScreen extends ConsumerStatefulWidget {
  const AddReminderScreen({super.key, this.cropId, this.reminder});
  final String? cropId;
  final Reminder? reminder; // berilsa — tahrirlash
  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderState();
}

class _AddReminderState extends ConsumerState<AddReminderScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.reminder?.title);
  late final _desc = TextEditingController(text: widget.reminder?.description);
  late final _every = TextEditingController(text: '${widget.reminder?.repeatEvery ?? 3}');
  late String? _cropId = widget.reminder?.cropId ?? widget.cropId;
  late String _type = widget.reminder?.type ?? 'watering';
  late DateTime _date = widget.reminder?.date ?? _todayDate;
  late TimeOfDay? _time = _parseTime(widget.reminder?.time);
  String? _repeat; // null | daily | weekly | monthly | custom (faqat yangi vazifada)
  DateTime? _until;
  late int? _before = widget.reminder?.remindBefore;
  bool _loading = false, _dirty = false, _submitted = false;
  String? _serverError;

  bool get _editing => widget.reminder != null;
  static DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static TimeOfDay? _parseTime(String? t) {
    if (t == null || t.length < 5) return null;
    return TimeOfDay(hour: int.parse(t.substring(0, 2)), minute: int.parse(t.substring(3, 5)));
  }

  @override
  void initState() {
    super.initState();
    for (final t in [_title, _desc, _every]) {
      t.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _set(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  @override
  void dispose() {
    for (final t in [_title, _desc, _every]) {
      t.dispose();
    }
    super.dispose();
  }

  String? _hms(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_repeat != null && _until == null) {
      setState(() => _serverError = tr('Takrorlash uchun tugash sanasini tanlang'));
      return;
    }
    if (_loading) return;
    // O'tgan vaqtga yangi vazifa — tasdiq bilan kechikkan sifatida (TZ S26)
    final at = DateTime(_date.year, _date.month, _date.day, _time?.hour ?? 23, _time?.minute ?? 59);
    if (!_editing && at.isBefore(DateTime.now())) {
      final ok = await confirm(context, tr("Vaqt o'tib ketgan"), tr("Bu vazifa kechikkan sifatida yaratiladi. Davom etasizmi?"), ok: tr('Yaratish'));
      if (!ok || !mounted) return;
    }
    var scope = 'one';
    if (_editing && widget.reminder!.isSeries) {
      final s = await askSeriesScope(context, title: tr("O'zgarish qaysi vazifalarga tegishli?"));
      if (s == null || !mounted) return;
      scope = s;
    }
    setState(() => _loading = true);
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'reminder_type': _type,
      'reminder_date': DateFormat('yyyy-MM-dd').format(_date),
      'reminder_time': _hms(_time),
      'crop_id': _cropId,
      'remind_before': _before,
      if (!_editing && _repeat != null) ...{
        'repeat': _repeat,
        'repeat_until': DateFormat('yyyy-MM-dd').format(_until!),
        if (_repeat == 'custom') 'repeat_every': int.tryParse(_every.text.trim()),
      },
    };
    final repo = ref.read(gardenRepoProvider);
    try {
      if (_editing) {
        await repo.updateReminder(widget.reminder!.id, data, scope: scope);
      } else {
        await repo.createReminder(data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _serverError = ApiException.from(e).message;
        });
      }
      return;
    }
    refreshTasks(ref, cropId: _cropId);
    if (widget.reminder?.cropId != null && widget.reminder!.cropId != _cropId) refreshTasks(ref, cropId: widget.reminder!.cropId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _dirty = false;
    });
    showToast(context, _editing ? tr('Saqlandi') : tr("Eslatma qo'shildi"));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/reminders');
    }
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) => showDatePicker(
        context: context,
        firstDate: first ?? _todayDate.subtract(const Duration(days: 365)),
        lastDate: _todayDate.add(const Duration(days: 730)),
        initialDate: initial,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final crops = ref.watch(cropsProvider);
    final r = widget.reminder;
    Widget label(String t, [String? hint]) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: t, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              if (hint != null) TextSpan(text: ' $hint', style: TextStyle(color: c.muted)),
            ]),
            style: const TextStyle(fontSize: 15),
          ),
        );
    Widget pickerBox({required IconData icon, required String text, bool placeholder = false, VoidCallback? onTap, VoidCallback? onClear}) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              suffixIcon: onClear == null ? null : IconButton(tooltip: tr('Tozalash'), icon: const Icon(Icons.close_rounded), onPressed: onClear),
            ),
            child: Text(text, style: TextStyle(fontSize: 16, color: placeholder ? c.muted : c.text)),
          ),
        );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, tr("O'zgarishlar saqlanmagan"), tr("Chiqsangiz, kiritilgan ma'lumotlar yo'qoladi."), ok: tr('Chiqish'), danger: true);
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/reminders');
          }
        }
      },
      child: PageShell(
        padBottom: false,
        maxWidth: 640,
        child: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: _editing ? tr('Eslatmani tahrirlash') : tr('Yangi eslatma')),
            label(tr('Turi')),
            ChipTabs(
              tabs: [for (final e in reminderTypeLabels.entries) (e.key, e.value)],
              selected: _type,
              onSelect: (v) => _set(() => _type = v),
            ),
            label(tr('Sarlavha')),
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr("Masalan: Chuqur sug'orish"), counterText: ''),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return tr('Sarlavhani kiriting');
                if (t.length < 3) return tr("Sarlavha kamida 3 ta belgidan iborat bo'lsin");
                return null;
              },
            ),
            label(tr('Ekin'), tr('(ixtiyoriy)')),
            crops.when(
              data: (list) => DropdownButtonFormField<String?>(
                initialValue: list.any((e) => e.id == _cropId) ? _cropId : null,
                isExpanded: true,
                dropdownColor: c.card,
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(tr('Umumiy (ekinga bog\'lanmagan)'))),
                  for (final cr in list) DropdownMenuItem<String?>(value: cr.id, child: Text(cr.name)),
                ],
                onChanged: (v) => _set(() => _cropId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(tr("Ekinlarni yuklab bo'lmadi"), style: TextStyle(color: c.danger)),
            ),
            LayoutBuilder(builder: (context, box) {
              final date = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label(tr('Sana')),
                pickerBox(
                  icon: AppIcons.calendar,
                  text: DateFormat('dd.MM.yyyy').format(_date),
                  onTap: () async {
                    final d = await _pickDate(_date);
                    if (d != null) _set(() => _date = d);
                  },
                ),
              ]);
              final time = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label(tr('Vaqt'), tr('(ixtiyoriy)')),
                pickerBox(
                  icon: AppIcons.clock,
                  text: _time == null ? tr("Kun bo'yi") : _hms(_time)!.substring(0, 5),
                  placeholder: _time == null,
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0));
                    if (t != null) _set(() => _time = t);
                  },
                  onClear: _time == null ? null : () => _set(() => _time = null),
                ),
              ]);
              if (box.maxWidth < 300) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [date, time]);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: date), const SizedBox(width: 12), Expanded(child: time)]);
            }),
            label(tr('Takrorlash')),
            if (_editing)
              Text(r!.isSeries ? (repeatLabel(r) ?? tr('Takrorlanadi')) : tr('Takrorlanmaydi'), style: TextStyle(fontSize: 16, color: c.text))
            else ...[
              DropdownButtonFormField<String?>(
                initialValue: _repeat,
                isExpanded: true,
                dropdownColor: c.card,
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(tr('Takrorlanmaydi'))),
                  DropdownMenuItem<String?>(value: 'daily', child: Text(tr('Har kuni'))),
                  DropdownMenuItem<String?>(value: 'weekly', child: Text(tr('Har hafta'))),
                  DropdownMenuItem<String?>(value: 'monthly', child: Text(tr('Har oy'))),
                  DropdownMenuItem<String?>(value: 'custom', child: Text(tr('Har N kunda'))),
                ],
                onChanged: (v) => _set(() {
                  _repeat = v;
                  _until ??= v == null ? null : _date.add(Duration(days: v == 'monthly' ? 90 : 30));
                }),
              ),
              if (_repeat == 'custom') ...[
                label(tr('Necha kunda?')),
                TextFormField(
                  controller: _every,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(suffixText: tr('kun')),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return n == null || n < 1 || n > 60 ? tr('1 dan 60 gacha son kiriting') : null;
                  },
                ),
              ],
              if (_repeat != null) ...[
                label(tr('Tugash sanasi')),
                pickerBox(
                  icon: Icons.event_busy_outlined,
                  text: _until == null ? tr('Tanlang') : DateFormat('dd.MM.yyyy').format(_until!),
                  placeholder: _until == null,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: _date,
                      lastDate: _date.add(const Duration(days: 366)),
                      initialDate: _until != null && !_until!.isBefore(_date) ? _until! : _date,
                    );
                    if (d != null) _set(() => _until = d);
                  },
                ),
                if (_until != null && _until!.isBefore(_date))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(tr("Tugash sanasi boshlanish sanasidan oldin bo'lishi mumkin emas"), style: TextStyle(color: c.danger, fontSize: 14)),
                  ),
                if (_repeat == 'monthly' && _date.day > 28)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(trf("{0}-kun bo'lmagan oylarda vazifa oyning oxirgi kuniga qo'yiladi.", [_date.day]),
                        style: TextStyle(color: c.muted, fontSize: 14)),
                  ),
              ],
            ],
            label(tr('Oldindan eslatish')),
            DropdownButtonFormField<int?>(
              initialValue: const [null, 0, 15, 60, 1440].contains(_before) ? _before : null,
              isExpanded: true,
              dropdownColor: c.card,
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(tr('Eslatmasiz (standart vaqtda)'))),
                for (final m in const [0, 15, 60, 1440]) DropdownMenuItem<int?>(value: m, child: Text(remindBeforeLabel(m))),
              ],
              onChanged: (v) => _set(() => _before = v),
            ),
            label(tr('Izoh'), tr('(ixtiyoriy)')),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(hintText: tr("Masalan: ildiz atrofini yumshatib, kechqurun sug'oring")),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(AppIcons.bell, color: c.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr("Vaqti kelganda eslatma ilovadagi Bildirishnomalar bo'limida chiqadi. Kun bo'yi vazifa ertalab soat 8:00 da eslatiladi."),
                    style: TextStyle(color: c.muted, fontSize: 14, height: 1.4),
                  ),
                ),
              ]),
            ),
            if (_serverError != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: c.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_serverError!, style: TextStyle(color: c.danger, fontSize: 15))),
                ]),
              ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _loading ? null : _save,
                icon: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary)) : const Icon(AppIcons.check),
                label: Text(_editing ? tr("O'zgarishlarni saqlash") : tr('Saqlash'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
