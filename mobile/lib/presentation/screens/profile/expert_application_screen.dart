import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';

/// "Men agronomman" arizasi. Admin tasdiqlagach, ilova agronom rejimida ochiladi.
class ExpertApplicationScreen extends ConsumerStatefulWidget {
  const ExpertApplicationScreen({super.key});
  @override
  ConsumerState<ExpertApplicationScreen> createState() => _State();
}

class _State extends ConsumerState<ExpertApplicationScreen> {
  final _spec = TextEditingController();
  final _years = TextEditingController();
  final _about = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _spec.dispose();
    _years.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final years = int.tryParse(_years.text.trim());
    if (_spec.text.trim().length < 3) {
      showToast(context, 'Mutaxassisligingizni yozing, masalan «mevali daraxtlar»');
      return;
    }
    if (years == null || years < 0 || years > 60) {
      showToast(context, 'Tajribani yillarda yozing, masalan 5');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(expertRepoProvider).apply(specialization: _spec.text.trim(), experienceYears: years, about: _about.text.trim());
      ref.invalidate(myApplicationProvider);
      if (!mounted) return;
      showToast(context, 'Ariza yuborildi. Javob 1–2 kunda keladi.');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
        padBottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TopBar(title: 'Men agronomman'),
          const NoteBox(
            kind: NoteKind.expert,
            title: 'Agronom nima qiladi',
            text: "AI tashxislarini tekshiradi, dehqonlar savollariga javob beradi va ma'lumotnomani to'ldiradi. "
                "Arizani admin ko'rib chiqadi; tasdiqlangach ilovada agronom rejimi ochiladi.",
          ),
          const FieldLabel('Mutaxassislik'),
          TextField(controller: _spec, maxLength: 200, decoration: const InputDecoration(hintText: 'Masalan: mevali daraxtlar, sabzavotlar', counterText: '')),
          const FieldLabel('Tajriba (yil)'),
          TextField(controller: _years, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Masalan: 5')),
          const FieldLabel("O'zingiz haqingizda (ixtiyoriy)"),
          TextField(controller: _about, maxLines: 4, minLines: 3, decoration: const InputDecoration(hintText: "Ma'lumotingiz, qayerda ishlagansiz, diplom yoki sertifikat")),
          const SizedBox(height: 20),
          PillButton(label: 'Ariza yuborish', style: PillStyle.primary, block: true, loading: _busy, onPressed: _send),
        ]),
      );
}
