import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

/// Savol berish: ekin tanlanadi, oxirgi tashxis (agar berilgan bo'lsa) o'zi biriktiriladi.
class AskQuestionScreen extends ConsumerStatefulWidget {
  const AskQuestionScreen({super.key, this.diagnosisId, this.cropId});
  final String? diagnosisId, cropId;
  @override
  ConsumerState<AskQuestionScreen> createState() => _AskState();
}

class _AskState extends ConsumerState<AskQuestionScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late String? _crop = widget.cropId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().length < 3) {
      showToast(context, "Savolni qisqacha yozing, masalan «Pomidor barglarida dog'lar»");
      return;
    }
    setState(() => _busy = true);
    try {
      final q = await ref.read(expertRepoProvider).ask(
          title: _title.text.trim(), body: _body.text.trim(), cropId: _crop, diagnosisId: widget.diagnosisId);
      ref.invalidate(myQuestionsProvider);
      ref.invalidate(questionQuotaProvider);
      if (widget.diagnosisId != null) ref.invalidate(diagnosisProvider(widget.diagnosisId!));
      if (!mounted) return;
      showToast(context, 'Agronomga yuborildi. Javob kelsa xabar beramiz.');
      context.pushReplacement('/help/q/${q.id}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final quota = ref.watch(questionQuotaProvider).value;
    final diag = widget.diagnosisId == null ? null : ref.watch(diagnosisProvider(widget.diagnosisId!)).value;
    return PageShell(
      padBottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Savol berish'),
        if (quota != null && !quota.unlimited)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: NoteBox(title: 'Bu oy: ${quota.remaining} ta bepul savol qoldi', text: "Premium'da agronomga cheksiz savol berasiz."),
          ),
        if (diag != null) ...[
          Text('BIRIKTIRILGAN TASHXIS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          _DiagnosisChip(d: diag),
          const SizedBox(height: 14),
        ],
        if (crops.isNotEmpty) ...[
          const FieldLabel('Qaysi ekin?'),
          ChipTabs(
            tabs: [('', "Ko'rsatmaslik"), for (final cr in crops) (cr.id, cr.name)],
            selected: _crop ?? '',
            onSelect: (v) => setState(() => _crop = v.isEmpty ? null : v),
          ),
        ],
        const FieldLabel('Savol'),
        TextField(controller: _title, maxLength: 200, textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: "Masalan: Pomidor barglarida qo'ng'ir dog'lar", counterText: '')),
        const FieldLabel('Batafsil (ixtiyoriy)'),
        TextField(controller: _body, maxLines: 4, minLines: 3,
            decoration: const InputDecoration(hintText: "Qachondan beri, qancha joyda, nima qilib ko'rdingiz")),
        const SizedBox(height: 20),
        if (quota != null && quota.remaining == 0)
          PillButton(label: "Limit tugadi — Premium'ga o'tish", icon: Icons.workspace_premium_outlined, style: PillStyle.primary, block: true,
              onPressed: () => context.push('/premium'))
        else
          PillButton(label: 'Agronomga yuborish', icon: Icons.send_rounded, style: PillStyle.primary, block: true, loading: _busy, onPressed: _send),
      ]),
    );
  }
}

class _DiagnosisChip extends StatelessWidget {
  const _DiagnosisChip({required this.d});
  final Diagnosis d;
  @override
  Widget build(BuildContext context) => AppCard(
        shadow: false,
        padding: const EdgeInsets.all(10),
        margin: EdgeInsets.zero,
        onTap: () => context.push('/diagnosis/${d.id}'),
        child: Row(children: [
          CatalogImage(url: AppConfig.mediaUrl(d.imageUrl), width: 60, height: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              StatusTag('AI: ${d.confidence.round()}%${d.lowConfidence ? ' · taxminiy' : ''}', kind: d.lowConfidence ? StatusKind.risk : StatusKind.neutral),
            ]),
          ),
        ]),
      );
}

/// Savol va agronom bilan yozishma.
class QuestionThreadScreen extends ConsumerStatefulWidget {
  const QuestionThreadScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<QuestionThreadScreen> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<QuestionThreadScreen> {
  final _msg = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, [String? ok]) async {
    setState(() => _busy = true);
    try {
      await f();
      ref.invalidate(questionProvider(widget.id));
      ref.invalidate(myQuestionsProvider);
      if (ok != null && mounted) showToast(context, ok);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final value = ref.watch(questionProvider(widget.id));
    final q = value.value;
    final closed = q?.status == 'closed';
    return PageShell(
      padBottom: false,
      bottom: q == null || closed
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(color: c.cream, border: Border(top: BorderSide(color: c.border))),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _msg,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'Xabar yozing'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.card, fixedSize: const Size(50, 50)),
                        tooltip: 'Yuborish',
                        onPressed: _busy
                            ? null
                            : () {
                                final t = _msg.text.trim();
                                if (t.isEmpty) return;
                                _msg.clear();
                                _run(() => ref.read(expertRepoProvider).send(widget.id, body: t));
                              },
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
      child: AsyncView(
        value: value,
        onRetry: () => ref.invalidate(questionProvider(widget.id)),
        data: (q) {
          final expert = q.expert;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TopBar(
              title: expert?.fullName ?? 'Agronom javobini kutmoqda',
              subtitle: expert != null ? 'Agronom' : 'Savolingiz navbatda',
              actions: [
                if (q.status == 'answered' && q.author.id == me?.id)
                  TextButton(onPressed: _busy ? null : () => _run(() => ref.read(expertRepoProvider).close(widget.id), "Savol yopildi. Javobni baholang"),
                      child: Text("Hal bo'ldi", style: TextStyle(color: c.primary, fontWeight: FontWeight.w700))),
              ],
            ),
            Text(q.title, style: Theme.of(context).textTheme.headlineSmall),
            if (q.body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(q.body!, style: Theme.of(context).textTheme.bodyLarge)),
            if (q.diagnosisId != null) ...[
              const SizedBox(height: 12),
              AppCard(
                shadow: false,
                padding: const EdgeInsets.all(10),
                margin: EdgeInsets.zero,
                onTap: () => context.push('/diagnosis/${q.diagnosisId}'),
                child: Row(children: [
                  CatalogImage(url: AppConfig.mediaUrl(q.imageUrl), width: 56, height: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('BIRIKTIRILGAN TASHXIS', style: Theme.of(context).textTheme.labelSmall),
                      Text(q.diagnosisName ?? 'Tashxis', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  if (q.diagnosisConfidence != null) StatusTag('AI ${q.diagnosisConfidence!.round()}%', kind: StatusKind.neutral),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            if (q.messages.isEmpty)
              const NoteBox(title: 'Savolingiz agronomlarga yuborildi', text: 'Birinchi javob bergan agronom shu yerda yozadi. Javob kelsa bildirishnoma keladi.'),
            for (final m in q.messages) _Bubble(m: m, mine: m.sender.id == me?.id),
            if (closed) ...[
              const SizedBox(height: 12),
              const NoteBox(kind: NoteKind.expert, title: 'Savol yopilgan'),
              if (q.rating == null && q.author.id == me?.id && expert != null) ...[
                const SizedBox(height: 12),
                AppCard(
                  shadow: false,
                  margin: EdgeInsets.zero,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Javob yordam berdimi?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          tooltip: '$i yulduz',
                          onPressed: _busy ? null : () => _run(() => ref.read(expertRepoProvider).rate(widget.id, i), 'Baho uchun rahmat'),
                          icon: Icon(Icons.star_rounded, color: c.gold, size: 32),
                        ),
                    ]),
                  ]),
                ),
              ] else if (q.rating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: StatusTag('Sizning bahoyingiz: ${q.rating}', kind: StatusKind.premium, icon: Icons.star_rounded),
                ),
            ],
            const SizedBox(height: 12),
          ]);
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.mine});
  final QuestionMessage m;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final expert = m.sender.isExpert;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: mine ? c.primary : c.card,
          border: mine ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine && expert)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_user_outlined, size: 14, color: c.expert),
                const SizedBox(width: 4),
                Text('Agronom · ${m.sender.fullName}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.expert)),
              ]),
            ),
          if (m.body != null) Text(m.body!, style: TextStyle(fontSize: 15.5, height: 1.45, color: mine ? c.card : c.text)),
          if (m.medicineName != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.infoBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.science_outlined, color: c.info, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.medicineName!, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                    if (m.medicineUsage != null) Text(m.medicineUsage!, style: TextStyle(fontSize: 13.5, color: c.muted)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Text(timeAgo(m.createdAt), style: TextStyle(fontSize: 11.5, color: mine ? c.card.withValues(alpha: 0.75) : c.subtle)),
        ]),
      ),
    );
  }
}

