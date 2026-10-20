import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/data/farm_options.dart';
import '../../../core/data/uz_regions.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'contact_sheet.dart';

/// "Ma'lumotlarim": umumiy qism + dehqon uchun xo'jalik, agronom uchun mutaxassis ma'lumotlari.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileState();
}

/// Agronom yo'nalishlari uchun ekinlardan tashqari mavzular.
List<String> get _expertTopics => [tr('Zararkunandalar'), tr("O'g'itlash"), tr("Sug'orish"), tr('Issiqxona'), tr('Tuproq'), tr("Urug'chilik"), tr('Organik dehqonchilik')];

class _EditProfileState extends ConsumerState<EditProfileScreen> {
  late final user = ref.read(currentUserProvider)!;
  late final _name = TextEditingController(text: user.fullName);
  late final _phone = TextEditingController(text: user.phone);
  late final _email = TextEditingController(text: user.email);
  late final _address = TextEditingController(text: user.address);
  late final _about = TextEditingController(text: user.about);
  late final _experience = TextEditingController(text: user.experienceYears?.toString());
  // Agronom
  late final _specialization = TextEditingController(text: user.specialization);
  late final _education = TextEditingController(text: user.education);
  late final _workHours = TextEditingController(text: user.workHours);
  late List<String> _skills = [...user.skills];
  // Dehqon xo'jaligi
  late String? _farmType = user.farmType;
  late String? _irrigation = user.irrigation;
  late List<String> _crops = [...user.mainCrops];
  late bool _sotix = user.farmArea == null || user.farmArea! < 1;
  late final _area = TextEditingController(text: _areaText(user.farmArea));

  late String? _region = uzRegions.containsKey(user.region) ? user.region : null;
  late String? _district = user.district;
  bool _loading = false, _uploading = false;

  bool get _expert => user.isExpert;

  String _areaText(double? ha) {
    if (ha == null) return '';
    final v = _sotix ? ha * 100 : ha;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  double? get _areaHa {
    final v = double.tryParse(_area.text.trim().replaceAll(',', '.'));
    if (v == null) return null;
    return _sotix ? v / 100 : v;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _about, _experience, _specialization, _education, _workHours, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return showToast(context, tr("F.I.O ni to'liq kiriting"));
    final phone = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) return showToast(context, tr("Telefon raqam noto'g'ri"));
    if (_area.text.trim().isNotEmpty && _areaHa == null) return showToast(context, tr("Yer maydonini raqamda yozing"));
    // TZ S24: kod kanali bor bo'lsa telefon/email faqat kod bilan o'zgaradi (alohida oyna) — bu yerda yuborilmaydi
    final opts = ref.read(authOptionsProvider).value;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).updateProfile({
        'full_name': _name.text.trim(),
        if (!(opts?.sms ?? false)) 'phone': phone.isEmpty ? null : phone,
        if (!(opts?.email ?? false)) 'email': _clean(_email),
        'region': _region,
        'district': _district,
        'address': _clean(_address),
        'experience_years': int.tryParse(_experience.text.trim()),
        if (_expert) ...{
          'about': _clean(_about),
          'specialization': _clean(_specialization),
          'education': _clean(_education),
          'work_hours': _clean(_workHours),
          'skills': _skills,
        } else ...{
          'farm_type': _farmType,
          'farm_area': _areaHa,
          'main_crops': _crops,
          'irrigation': _irrigation,
        },
      });
      if (mounted) {
        showToast(context, tr('Saqlandi'));
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeContact(String channel) async {
    if (await showContactChange(context, channel: channel) && mounted) {
      showToast(context, channel == 'sms' ? tr('Telefon raqami tasdiqlandi va saqlandi') : tr('Email tasdiqlandi va saqlandi'));
    }
  }

  Future<void> _pickAvatar() async {
    ImageSource? source = ImageSource.gallery;
    if (!kIsWeb) {
      source = await showSheet<ImageSource>(
        context,
        title: tr('Profil rasmi'),
        builder: (ctx) => Column(children: [
          ListRow(icon: Icons.photo_camera_outlined, label: tr('Kamera'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListRow(icon: Icons.photo_library_outlined, label: tr('Galereya'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      );
    }
    if (source == null) return;
    final f = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (f == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(authProvider.notifier).uploadAvatar(await f.readAsBytes(), f.name.contains('.') ? f.name : '${f.name}.jpg');
      if (mounted) showToast(context, tr('Rasm yangilandi'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPlace() async {
    final r = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (_) => _PlacePicker(region: _region),
    );
    if (r == null) return;
    setState(() {
      _region = r.$1;
      _district = r.$2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider) ?? user;
    final opts = ref.watch(authOptionsProvider).value;
    final accent = _expert ? c.expert : c.primary;
    final plants = ref.watch(plantsProvider).value?.map((p) => p.name).toList() ?? const <String>[];
    final place = placeText(_region, _district);
    return PageShell(
      padBottom: false,
      bottom: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(color: c.cream, border: Border(top: BorderSide(color: c.border))),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _expert
                  // Agronom rejimi aksenti (ikkala mavzuda ham kontrastli)
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.expert,
                        foregroundColor: c.onExpert,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onExpert))
                          : Text(tr('Saqlash'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    )
                  : PillButton(label: tr('Saqlash'), style: PillStyle.primary, block: true, loading: _loading, onPressed: _save),
            ),
          ),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TopBar(title: tr("Ma'lumotlarim")),
        Center(
          child: Semantics(
            button: true,
            label: tr("Profil rasmini o'zgartirish"),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _uploading ? null : _pickAvatar,
              child: Stack(clipBehavior: Clip.none, children: [
                Avatar(
                  name: me.fullName,
                  url: me.avatarUrl,
                  size: 96,
                  color: _expert ? c.expertBg : c.primaryLight,
                  textColor: accent,
                ),
                if (_uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.35)),
                      alignment: Alignment.center,
                      child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: Border.all(color: c.cream, width: 3)),
                    child: Icon(Icons.photo_camera_rounded, size: 16, color: c.card),
                  ),
                ),
              ]),
            ),
          ),
        ),
        _Section(tr("Shaxsiy ma'lumotlar")),
        FieldLabel(tr('F.I.O')),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: tr('Familiya Ism Otasining ismi'))),
        FieldLabel(tr('Telefon raqam')),
        if (opts?.sms ?? false)
          _VerifiedContact(value: me.phone, onChange: () => _changeContact('sms'))
        else
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+998 90 123 45 67')),
        FieldLabel(tr('Email (ixtiyoriy)')),
        if (opts?.email ?? false)
          _VerifiedContact(value: me.email, onChange: () => _changeContact('email'))
        else
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'pochta@misol.uz')),
        FieldLabel(tr('Hudud')),
        _PlaceField(text: place, accent: accent, onTap: _pickPlace),
        FieldLabel(tr("Qo'shimcha manzil")),
        TextField(controller: _address, decoration: InputDecoration(hintText: tr("Mahalla, qishloq, ko'cha (ixtiyoriy)"))),
        if (_expert) ...[
          _Section(tr("Mutaxassis ma'lumotlari"), hint: tr("Dehqonlar profilingizda ko'radi va shunga qarab sizga savol beradi")),
          FieldLabel(tr('Mutaxassislik')),
          TextField(controller: _specialization, decoration: InputDecoration(hintText: tr('Masalan: mevali bog\'lar, sabzavotlar'))),
          FieldLabel(tr('Men haqimda')),
          TextField(
            controller: _about,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(hintText: tr('Qisqacha o\'zingiz va qanday yordam bera olishingiz haqida...'), counterText: ''),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(tr('Tajriba (yil)')),
                _NumberField(controller: _experience, hint: '5'),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(tr('Ish vaqti')),
                TextField(controller: _workHours, decoration: InputDecoration(hintText: tr('Du–Ju, 9:00–18:00'))),
              ]),
            ),
          ]),
          FieldLabel(tr("Ta'lim")),
          TextField(controller: _education, decoration: InputDecoration(hintText: tr("Masalan: TDAU, agronomiya (2015)"))),
          FieldLabel(tr("Yo'nalishlar")),
          _TagsEditor(
            values: _skills,
            suggestions: [...plants, ..._expertTopics],
            accent: accent,
            hint: tr("Ekin yoki mavzu qo'shing"),
            onChanged: (v) => setState(() => _skills = v),
          ),
        ] else ...[
          _Section(tr("Xo'jaligim"), hint: tr("Agronom savolingizga javob berishda shu ma'lumotlarni ko'radi — maslahat aniqroq bo'ladi")),
          FieldLabel(tr("Xo'jalik turi")),
          _Choices(
            options: farmTypes,
            value: _farmType,
            accent: accent,
            onChanged: (v) => setState(() => _farmType = v),
          ),
          FieldLabel(tr('Yer maydoni')),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _area,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(hintText: _sotix ? '12' : '2.5'),
              ),
            ),
            const SizedBox(width: 10),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: accent,
                selectedForegroundColor: c.card,
                side: BorderSide(color: c.lineStrong, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              segments: [
                ButtonSegment(value: true, label: Text(tr('sotix'))),
                ButtonSegment(value: false, label: Text(tr('gektar'))),
              ],
              selected: {_sotix},
              onSelectionChanged: (s) {
                final ha = _areaHa;
                setState(() {
                  _sotix = s.first;
                  if (ha != null) _area.text = _areaText(ha);
                });
              },
            ),
          ]),
          FieldLabel(tr('Asosiy ekinlar')),
          _TagsEditor(
            values: _crops,
            suggestions: plants,
            accent: accent,
            hint: tr("Ekin nomini yozing"),
            onChanged: (v) => setState(() => _crops = v),
          ),
          FieldLabel(tr("Sug'orish usuli")),
          _Choices(
            options: irrigationTypes,
            value: _irrigation,
            accent: accent,
            onChanged: (v) => setState(() => _irrigation = v),
          ),
          FieldLabel(tr('Dehqonchilik tajribasi (yil)')),
          SizedBox(width: 140, child: _NumberField(controller: _experience, hint: '10')),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.hint});
  final String title;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(color: context.c.muted, fontSize: 13, height: 1.35)),
          ],
        ]),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        decoration: InputDecoration(hintText: hint),
      );
}

/// Hudud: viloyat + tuman (rasmdagidek yashil chegarali qator).
class _PlaceField extends StatelessWidget {
  const _PlaceField({required this.text, required this.accent, required this.onTap});
  final String text;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final empty = text.isEmpty;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: empty ? c.lineStrong : accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(children: [
            Icon(Icons.location_on_outlined, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                empty ? tr('Viloyat va tumanni tanlang') : text,
                style: TextStyle(fontSize: 15.5, fontWeight: empty ? FontWeight.w400 : FontWeight.w700, color: empty ? c.subtle : c.text),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ]),
        ),
      ),
    );
  }
}

/// Ikki bosqichli tanlash: viloyat → tuman/shahar.
class _PlacePicker extends StatefulWidget {
  const _PlacePicker({this.region});
  final String? region;
  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  late String? _region = widget.region;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _q.text.trim().toLowerCase();
    final items = (_region == null ? uzRegions.keys.toList() : uzRegions[_region]!).where((s) => s.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 6),
          child: Row(children: [
            if (_region != null)
              IconButton(
                tooltip: tr('Viloyatlar'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _region = null;
                  _q.clear();
                }),
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(_region ?? tr('Viloyatni tanlang'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (_region != null)
              TextButton(
                onPressed: () => Navigator.pop(context, (_region!, null)),
                child: Text(tr('Faqat viloyat'), style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _region == null ? tr('Viloyat qidirish') : tr('Tuman yoki shahar qidirish'),
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16, color: c.border),
            itemBuilder: (_, i) => ListTile(
              title: Text(items[i], style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: _region == null ? Icon(Icons.chevron_right_rounded, color: c.muted) : null,
              onTap: () {
                if (_region == null) {
                  setState(() {
                    _region = items[i];
                    _q.clear();
                  });
                } else {
                  Navigator.pop(context, (_region!, items[i]));
                }
              },
            ),
          ),
        ),
      ]),
    );
  }
}

/// Bitta tanlov (qayta bosilsa bekor bo'ladi).
class _Choices extends StatelessWidget {
  const _Choices({required this.options, required this.value, required this.accent, required this.onChanged});
  final Map<String, String> options;
  final String? value;
  final Color accent;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in options.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: value == e.key,
          showCheckmark: false,
          selectedColor: accent,
          backgroundColor: c.card,
          side: BorderSide(color: value == e.key ? accent : c.lineStrong),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(color: value == e.key ? c.card : c.text, fontWeight: FontWeight.w600),
          onSelected: (_) => onChanged(value == e.key ? null : e.key),
        ),
    ]);
  }
}

/// Teglar: tanlanganlar (o'chirsa bo'ladi) + yozib qo'shish + takliflar.
class _TagsEditor extends StatefulWidget {
  const _TagsEditor({required this.values, required this.suggestions, required this.accent, required this.hint, required this.onChanged});
  final List<String> values, suggestions;
  final Color accent;
  final String hint;
  final ValueChanged<List<String>> onChanged;
  @override
  State<_TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends State<_TagsEditor> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final t = raw.trim();
    _ctl.clear();
    setState(() {});
    if (t.isEmpty || t.length > 40 || widget.values.length >= 20) return;
    if (widget.values.any((v) => v.toLowerCase() == t.toLowerCase())) return;
    widget.onChanged([...widget.values, t]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _ctl.text.trim().toLowerCase();
    final taken = widget.values.map((v) => v.toLowerCase()).toSet();
    final sugg = widget.suggestions.where((s) => !taken.contains(s.toLowerCase()) && s.toLowerCase().contains(q)).toSet().take(10).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.values.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in widget.values)
            InputChip(
              label: Text(v),
              color: WidgetStatePropertyAll(widget.accent.withValues(alpha: 0.12)),
              side: BorderSide.none,
              shape: const StadiumBorder(),
              labelStyle: TextStyle(color: widget.accent, fontWeight: FontWeight.w700),
              deleteIconColor: widget.accent,
              deleteButtonTooltipMessage: tr("Olib tashlash"),
              onDeleted: () => widget.onChanged([...widget.values]..remove(v)),
            ),
        ]),
        const SizedBox(height: 10),
      ],
      TextField(
        controller: _ctl,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        onSubmitted: _add,
        decoration: InputDecoration(
          hintText: widget.hint,
          suffixIcon: q.isEmpty
              ? null
              : IconButton(tooltip: tr("Qo'shish"), icon: Icon(Icons.add_circle_rounded, color: widget.accent), onPressed: () => _add(_ctl.text)),
        ),
      ),
      if (sugg.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in sugg)
            ActionChip(
              avatar: Icon(Icons.add_rounded, size: 16, color: c.muted),
              label: Text(s),
              backgroundColor: c.card,
              side: BorderSide(color: c.border),
              shape: const StadiumBorder(),
              onPressed: () => _add(s),
            ),
        ]),
      ],
    ]);
  }
}


/// Kod bilan tasdiqlanadigan aloqa: joriy qiymat + "O'zgartirish" (TZ S24).
class _VerifiedContact extends StatelessWidget {
  const _VerifiedContact({required this.value, required this.onChange});
  final String? value;
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final has = value != null && value!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Row(children: [
        Expanded(
          child: Text(has ? value! : tr('Kiritilmagan'), style: TextStyle(fontSize: 16, color: has ? c.text : c.muted)),
        ),
        TextButton(onPressed: onChange, child: Text(has ? tr("O'zgartirish") : tr("Qo'shish"))),
      ]),
    );
  }
}
