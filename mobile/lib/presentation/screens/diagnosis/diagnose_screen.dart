import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../application/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'diagnosis_actions.dart';

enum _Step { intro, analyzing, result, error }

class DiagnoseScreen extends ConsumerStatefulWidget {
  const DiagnoseScreen({super.key, this.cropId});
  final String? cropId;
  @override
  ConsumerState<DiagnoseScreen> createState() => _DiagnoseState();
}

class _DiagnoseState extends ConsumerState<DiagnoseScreen> {
  _Step _step = _Step.intro;
  late String? _cropId = widget.cropId;
  String? _plantId;
  Uint8List? _image;
  Diagnosis? _result;
  ApiException? _error;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _step = _Step.analyzing;
      _error = null;
    });
    try {
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      final d = await ref.read(gardenRepoProvider).diagnose(bytes, name, cropId: _cropId, plantId: _plantId);
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(cropsProvider);
      ref.invalidate(diagnosesProvider);
      if (_cropId != null) {
        ref.invalidate(cropProvider(_cropId!));
        ref.invalidate(cropDiagnosesProvider(_cropId!));
        ref.invalidate(cropHealthProvider(_cropId!));
      }
      setState(() {
        _result = d;
        _step = _Step.result;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e);
        _step = _Step.error;
      });
    }
  }

  void _restart() => setState(() {
        _step = _Step.intro;
        _image = null;
        _result = null;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final crops = ref.watch(cropsProvider);
    final sub = ref.watch(mySubscriptionProvider);
    final quota = sub.value;
    final overLimit = quota != null && quota.aiDailyLimit != null && quota.aiUsedToday >= quota.aiDailyLimit!;

    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'AI Tashxis', subtitle: 'Onlayn — darhol javob beradi'),
        const _Bubble(text: "Salom! Menga o'simlik yoki bargning aniq rasmini yuboring — men tahlil qilib, kasallik va davolash yo'lini aytib beraman."),
        if (_step == _Step.intro) ...[
          const FieldLabel('Qaysi ekin haqida? (tashxis shu ekin tarixiga saqlanadi)'),
          crops.maybeWhen(
            data: (list) => DropdownButtonFormField<String?>(
              initialValue: list.any((e) => e.id == _cropId) ? _cropId : null,
              isExpanded: true,
              dropdownColor: c.card,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text("— Bog'imga bog'lamasdan —")),
                for (final cr in list) DropdownMenuItem<String?>(value: cr.id, child: Text('${cr.name}${cr.plantName != null ? ' · ${cr.plantName}' : ''}')),
              ],
              onChanged: (v) => setState(() => _cropId = v),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          if (_cropId == null) ...[
            const SizedBox(height: 12),
            const FieldLabel("Ekin turi (aniqroq natija uchun)"),
            DropdownButtonFormField<String?>(
              initialValue: _plantId,
              isExpanded: true,
              dropdownColor: c.card,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Bilmayman — AI o\'zi aniqlasin')),
                for (final p in ref.watch(plantsProvider).value ?? const <Plant>[]) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _plantId = v),
            ),
          ],
          const SizedBox(height: 10),
          if (quota != null && quota.aiDailyLimit != null)
            Text('Bugungi bepul tashxis: ${quota.aiUsedToday}/${quota.aiDailyLimit}', style: TextStyle(color: c.muted, fontSize: 12.5)),
          const SizedBox(height: 16),
          if (overLimit)
            _LimitCard(onUpgrade: () => context.push('/premium'))
          else ...[
            PillButton(label: 'Rasmga olish', icon: AppIcons.camera, style: PillStyle.primary, block: true, onPressed: () => _pick(ImageSource.camera)),
            const SizedBox(height: 10),
            PillButton(label: 'Galereyadan tanlash', icon: AppIcons.image, style: PillStyle.outline, block: true, onPressed: () => _pick(ImageSource.gallery)),
            const SizedBox(height: 16),
            _Tips(),
          ],
        ],
        if (_image != null) _Bubble(me: true, image: _image, text: 'Bargning rasmi yuborildi'),
        if (_step == _Step.analyzing) const _Bubble(typing: true, text: 'AI tahlil qilmoqda'),
        if (_step == _Step.error && _error != null)
          _error!.isPaymentRequired
              ? _LimitCard(onUpgrade: () => context.push('/premium'), message: _error!.message)
              : _ResultShell(children: [
                  Text('Tahlil qilib bo\'lmadi', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.danger)),
                  const SizedBox(height: 6),
                  Text(_error!.message),
                  const SizedBox(height: 10),
                  MiniButton(label: 'Qayta urinish', filled: true, onTap: _restart),
                ]),
        if (_step == _Step.result && _result != null) _ResultCard(d: _result!, onRetry: _restart, cropLinked: _cropId != null),
      ]),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({required this.d, required this.onRetry, required this.cropLinked});
  final Diagnosis d;
  final VoidCallback onRetry;
  final bool cropLinked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final planLabel = cropLinked ? 'Parvarish rejasi' : "Bog'imga qo'shish";
    void openPlan() => context.push('/diagnosis/${d.id}/plan');
    if (d.lowConfidence && !d.isHealthy && d.diseaseName == null) {
      return _ResultShell(children: [
        Text('Aniqlab bo\'lmadi (${d.confidence.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text("Ekin turini tanlab yoki bargni yaqinroqdan qayta suratga olib ko'ring.", style: TextStyle(color: c.muted)),
        const SizedBox(height: 10),
        MiniButton(label: 'Qayta urinish', filled: true, onTap: onRetry),
      ]);
    }
    if (d.isHealthy) {
      return _ResultShell(children: [
        Row(children: [
          Icon(Icons.verified_rounded, color: c.success),
          const SizedBox(width: 8),
          Expanded(child: Text("O'simlik sog'lom · ishonch ${d.confidence.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        Text(d.recommendations ?? "Parvarishni davom ettiring.", style: const TextStyle(height: 1.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          MiniButton(label: planLabel, icon: AppIcons.leaf, filled: true, onTap: openPlan),
          MiniButton(label: 'Jamoatda ulashish', onTap: () => shareDiagnosis(context, ref, d)),
          MiniButton(label: 'Yangi tashxis', onTap: onRetry),
        ]),
        _Feedback(d: d),
      ]);
    }
    final med = d.medicines.isNotEmpty ? d.medicines.first : null;
    return _ResultShell(children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: '${d.lowConfidence ? 'Ehtimoliy kasallik' : 'Aniqlangan kasallik'}: ${d.diseaseName} · '),
        TextSpan(text: '${d.lowConfidence ? 'taxminan' : 'ishonch'} ${d.confidence.toStringAsFixed(0)}%', style: TextStyle(color: c.primary)),
      ]), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (d.plantName != null) Tag(d.plantName!, bg: c.tagCare, fg: c.onTagCare),
        if (d.riskLevel != null)
          Tag(riskLabels[d.riskLevel] ?? d.riskLevel!, bg: d.riskLevel == 'high' ? c.dangerBg : c.primaryLight, fg: d.riskLevel == 'high' ? c.danger : c.primaryDark),
      ]),
      if (d.lowConfidence) ...[
        const SizedBox(height: 8),
        Text("AI to'liq ishonch hosil qilmadi — belgilarni solishtiring. Ekin turini tanlab qayta tekshirsangiz, natija aniqroq bo'ladi.",
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      ],
      if (d.symptoms != null) ...[
        const SizedBox(height: 8),
        Text('Belgilari: ${d.symptoms}', style: const TextStyle(height: 1.5, fontSize: 13.5)),
      ],
      const SizedBox(height: 8),
      Text(d.treatment ?? d.recommendations ?? '', style: const TextStyle(height: 1.5, fontSize: 13.5)),
      if (med != null) InfoBox(label: 'Tavsiya etilgan dori', value: '${med.name}${med.recommendation != null ? ', ${med.recommendation}' : ''}'),
      if (cropLinked)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [Icon(AppIcons.check, size: 16, color: c.success), const SizedBox(width: 6), Text("Bog'imdagi ekin tarixiga saqlandi", style: TextStyle(color: c.success, fontWeight: FontWeight.w700, fontSize: 12.5))]),
        ),
      const SizedBox(height: 6),
      PillButton(label: cropLinked ? 'Davolash rejasi' : "Bog'imga qo'shish va reja", icon: AppIcons.leaf, style: PillStyle.primary, block: true, onPressed: openPlan),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        MiniButton(label: 'Batafsil', onTap: () => context.push('/diagnosis/${d.id}')),
        MiniButton(label: 'Jamoatda ulashish', onTap: () => shareDiagnosis(context, ref, d)),
        MiniButton(label: 'Yangi tashxis', onTap: onRetry),
      ]),
      _Feedback(d: d),
    ]);
  }
}

/// "AI to'g'ri topdimi?" — javoblar dataset tekshiruvida ishlatiladi ("xato"lar birinchi ko'riladi).
class _Feedback extends ConsumerStatefulWidget {
  const _Feedback({required this.d});
  final Diagnosis d;
  @override
  ConsumerState<_Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends ConsumerState<_Feedback> {
  late bool? _value = widget.d.userFeedback;

  Future<void> _send(bool correct) async {
    setState(() => _value = correct);
    try {
      await ref.read(gardenRepoProvider).feedback(widget.d.id, correct);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_value != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(_value! ? "Rahmat! Fikringiz AI'ni yaxshilashga yordam beradi." : "Rahmat! Mutaxassis rasmni tekshirib, AI'ni shu asosda o'rgatadi.",
            style: TextStyle(color: c.muted, fontSize: 12.5)),
      );
    }
    Widget btn(bool v, IconData icon, String label) => InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => _send(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: v ? c.success : c.danger),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text("AI to'g'ri topdimi?", style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        btn(true, Icons.thumb_up_alt_outlined, 'Ha'),
        btn(false, Icons.thumb_down_alt_outlined, "Yo'q"),
      ]),
    );
  }
}

class _ResultShell extends StatelessWidget {
  const _ResultShell({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14, right: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.c.card,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
          boxShadow: softShadow(context, 8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _Bubble extends StatefulWidget {
  const _Bubble({required this.text, this.me = false, this.image, this.typing = false});
  final String text;
  final bool me, typing;
  final Uint8List? image;
  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  Timer? _t;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    if (widget.typing) _t = Timer.periodic(const Duration(milliseconds: 400), (_) => setState(() => _dots = _dots % 3 + 1));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = widget.me;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width.clamp(0, 480) * 0.78),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: me ? c.primary : c.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(me ? 16 : 4),
              bottomRight: Radius.circular(me ? 4 : 16),
            ),
            boxShadow: softShadow(context, 8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(widget.image!, fit: BoxFit.cover))),
              ),
            Text(widget.typing ? '${widget.text}${'.' * _dots}' : widget.text,
                style: TextStyle(fontSize: 14, height: 1.45, color: me ? c.card : (widget.typing ? c.muted : c.text))),
          ]),
        ),
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.onUpgrade, this.message});
  final VoidCallback onUpgrade;
  final String? message;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(children: [
          const Text('Bepul limit tugadi', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message ?? "Bugungi bepul AI tashxislardan foydalandingiz. Ertaga qayta urinib ko'ring yoki Premium'ga o'ting.",
              textAlign: TextAlign.center, style: TextStyle(color: context.c.muted)),
          const SizedBox(height: 14),
          PillButton(label: "Premium'ga o'tish", icon: AppIcons.star, block: true, onPressed: onUpgrade),
        ]),
      );
}

class _Tips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget tip(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [Icon(i, size: 18, color: c.primary), const SizedBox(width: 10), Expanded(child: Text(t, style: TextStyle(color: c.muted, fontSize: 13)))]),
        );
    return AppCard(
      color: c.cream2,
      shadow: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Yaxshi natija uchun', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        tip(Icons.wb_sunny_outlined, "Kunduzgi yorug'likda suratga oling"),
        tip(Icons.center_focus_strong_outlined, 'Bitta zararlangan bargni kadr markaziga oling'),
        tip(Icons.back_hand_outlined, 'Kamerani qimirlatmang — rasm xira bo\'lmasin'),
        const SizedBox(height: 4),
        Text("Yuklangan rasmlar mutaxassis tekshiruvidan so'ng AI'ni yaxshilash uchun anonim ishlatilishi mumkin.",
            style: TextStyle(color: c.muted, fontSize: 11.5)),
      ]),
    );
  }
}
