import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/catalog_images.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/ds.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'expert_shell.dart';

/// Agronom TZ Y02 — Tashxisni tekshirish. Ochilganda ish shu agronomga biriktiriladi (claim); boshqasi olgan bo'lsa
/// ko'rib bo'lmaydi. AI taxmini — model ishonchi, ekspert tasdig'i emas. Tanlov qoralamada saqlanadi (Y03 ↔ Y02).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<ReviewScreen> {
  QueueItem? _item;
  Object? _error;
  bool _conflict = false;

  @override
  void initState() {
    super.initState();
    _claim();
  }

  Future<void> _claim() async {
    setState(() {
      _error = null;
      _conflict = false;
    });
    try {
      final i = await ref.read(expertRepoProvider).claim(widget.id);
      if (mounted) setState(() => _item = i);
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        _conflict = err.statusCode == 409;
        _error = e;
      });
    }
  }

  ReviewDraft get _draft => ref.read(reviewDraftsProvider.notifier).of(widget.id);
  void _setDraft(ReviewDraft d) => ref.read(reviewDraftsProvider.notifier).set(widget.id, d);

  Future<void> _pickOther(QueueItem i) async {
    final picked = await showModalBottomSheet<Alternative>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _OtherDiseaseSheet(plantName: i.plantName),
    );
    // Bekor qilinsa eski tanlov qoladi (TZ T07)
    if (picked != null) _setDraft(_draft.copyWith(label: picked.label, name: picked.diseaseName ?? picked.label, clearRetake: true));
  }

  Future<void> _pickRetake() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _RetakeSheet(current: _draft.retakeReason),
    );
    if (r != null) _setDraft(_draft.copyWith(retakeReason: r, clearLabel: true));
  }

  Future<void> _release() async {
    try {
      await ref.read(expertRepoProvider).release(widget.id);
    } catch (_) {
      /* navbatga baribir qaytamiz */
    }
    ref.read(reviewDraftsProvider.notifier).clear(widget.id);
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(queueCountsProvider);
    if (mounted) context.canPop() ? context.pop() : context.go('/expert');
  }

  void _viewer(String url) => Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, __) => _ImageViewer(url: url),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final draft = ref.watch(reviewDraftsProvider)[widget.id] ?? const ReviewDraft();
    final i = _item;
    final ready = i != null && (draft.label != null || draft.isRetake);
    return PageShell(
      padBottom: false,
      maxWidth: i != null && MediaQuery.sizeOf(context).width >= 1024 ? expertWideMax : 680,
      bottom: i == null
          ? null
          : _StickyCta(
              label: tr('Xulosani tayyorlash'),
              hint: ready ? null : tr("Avval AI taxminini, boshqa kasallikni yoki «Rasm yetarli emas»ni tanlang"),
              onPressed: ready ? () => context.push('/expert/review/${widget.id}/conclusion') : null,
            ),
      child: i == null
          ? Column(
              children: [
                TopBar(title: tr('Tashxisni tekshirish')),
                if (_error == null)
                  const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                else
                  _conflict
                      ? _InfoState(
                          icon: Icons.lock_person_outlined,
                          title: ApiException.from(_error!).message,
                          text: tr("Bu ishni boshqa agronom ko'rib chiqmoqda yoki u allaqachon tekshirilgan. Navbatdan boshqa ishni tanlang."),
                          action: PillButton(
                            label: tr('Navbatga qaytish'),
                            style: PillStyle.outline,
                            onPressed: () => context.canPop() ? context.pop() : context.go('/expert'),
                          ),
                        )
                      : _InfoState(
                          icon: Icons.cloud_off_rounded,
                          title: tr("Yuklab bo'lmadi"),
                          text: ApiException.from(_error!).message,
                          action: PillButton(label: tr('Qayta urinish'), style: PillStyle.soft, onPressed: _claim),
                        ),
              ],
            )
          : _body(context, c, i, draft),
    );
  }

  Widget _body(BuildContext context, AppColors c, QueueItem i, ReviewDraft draft) {
    final url = AppConfig.mediaUrl(i.imageUrl);
    final alts = i.alternatives;
    final chosenOther = draft.label != null && !alts.any((a) => a.label == draft.label);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar(
          title: tr('Tashxisni tekshirish'),
          actions: [
            PopupMenuButton<String>(
              tooltip: tr('Boshqa amallar'),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => v == 'release' ? _release() : null,
              itemBuilder: (_) => [PopupMenuItem(value: 'release', child: Text(tr('Ishni navbatga qaytarish')))],
            ),
          ],
        ),
        // Keng ekranda: chapda rasm va dehqon ma'lumoti, o'ngda AI taxmini va amallar (TZ 3.3)
        ExpertColumns(
          leftFlex: 6,
          rightFlex: 5,
          narrowGap: 0,
          left: [
            Semantics(
              button: true,
              label: tr('Rasmni kattalashtirish'),
              child: GestureDetector(
                onTap: url == null ? null : () => _viewer(url),
                child: Stack(
                  children: [
                    CatalogImage(url: url, width: double.infinity, height: wide ? 420 : 280, radius: 16),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              tr('Kattalashtirish'),
                              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              shadow: false,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CatalogImage(asset: CatalogImages.plant(i.plantName), width: 48, height: 48, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.plantName ?? tr("Ekin ko'rsatilmagan"),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
                        ),
                        Text(tr('Rasmni dehqon yuborgan'), style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: c.muted),
                          const SizedBox(width: 4),
                          Text(i.farmerName, style: TextStyle(fontSize: 13, color: c.muted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: c.muted),
                          const SizedBox(width: 4),
                          Text(timeAgo(i.diagnosedAt), style: TextStyle(fontSize: 13, color: c.muted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (i.reviewNote != null && i.reviewNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              NoteBox(title: tr('Dehqon izohi'), text: i.reviewNote, icon: Icons.chat_bubble_outline_rounded),
            ],
          ],
          right: [
            if (!wide) const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, color: c.olive),
                      const SizedBox(width: 8),
                      Text(
                        tr('AI taxmini'),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        triggerMode: TooltipTriggerMode.tap,
                        message: tr("Model ishonchi — modelning o'zi qanchalik ishonchi. Bu kasallikning haqiqiy ehtimoli ham, ekspert tasdig'i ham emas."),
                        child: Icon(Icons.info_outline_rounded, size: 18, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (alts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        i.plantName != null && CatalogImages.plantPrefix[i.plantName] == null
                            ? tr("Qo'llab-quvvatlanmaydi: AI bu ekinni tanimaydi. «Boshqa kasallik» orqali tanlang.")
                            : tr("AI taxmini mavjud emas. «Boshqa kasallik» orqali tanlang."),
                        style: TextStyle(color: c.muted, height: 1.4),
                      ),
                    ),
                  for (final a in alts)
                    _AltTile(
                      a: a,
                      selected: draft.label == a.label,
                      onTap: () => _setDraft(draft.copyWith(label: a.label, name: a.diseaseName ?? a.label, clearRetake: true)),
                    ),
                  if (chosenOther)
                    _AltTile(
                      a: Alternative(label: draft.label!, diseaseName: draft.name),
                      selected: true,
                      mine: true,
                      onTap: () => _pickOther(i),
                    ),
                ],
              ),
            ),
            if (draft.isRetake) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: c.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trf('Rasm yetarli emas: {0}', [tr(retakeReasons.firstWhere((r) => r.$1 == draft.retakeReason).$2)]),
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
                      ),
                    ),
                    TextButton(onPressed: () => _setDraft(draft.copyWith(clearRetake: true)), child: Text(tr('Bekor qilish'))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (ctx, box) {
                final b1 = _OutlineBtn(icon: Icons.search_rounded, label: tr('Boshqa kasallik'), onTap: () => _pickOther(i));
                final b2 = _OutlineBtn(icon: Icons.image_search_rounded, label: tr('Rasm yetarli emas'), onTap: _pickRetake, active: draft.isRetake);
                // Ikki tugma sig'masa — ustma-ust (TZ 3.2)
                return box.maxWidth < 340 || MediaQuery.textScalerOf(ctx).scale(10) > 13
                    ? Column(children: [b1, const SizedBox(height: 10), b2])
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: b1),
                            const SizedBox(width: 10),
                            Expanded(child: b2),
                          ],
                        ),
                      );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ],
    );
  }
}

/// Agronom TZ Y03 — Ekspert xulosasi: tanlov, dehqonga maslahat (majburiy), manba (ixtiyoriy, https), dehqon ko'radigan
/// ko'rinish va "Dehqonga yuborish". Server tasdiqlamaguncha "yuborildi" deyilmaydi; ikki marta bosish bloklanadi.
class ConclusionScreen extends ConsumerStatefulWidget {
  const ConclusionScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ConclusionScreen> createState() => _ConclusionState();
}

class _ConclusionState extends ConsumerState<ConclusionScreen> {
  late final ReviewDraft _initial = ref.read(reviewDraftsProvider.notifier).of(widget.id);
  late final _comment = TextEditingController(text: _initial.comment);
  late final _source = TextEditingController(text: _initial.source);
  bool _busy = false, _tried = false;
  static const _maxComment = 2000;

  @override
  void dispose() {
    _comment.dispose();
    _source.dispose();
    super.dispose();
  }

  void _save() {
    final n = ref.read(reviewDraftsProvider.notifier);
    n.set(widget.id, n.of(widget.id).copyWith(comment: _comment.text, source: _source.text));
  }

  String? get _commentError {
    final t = _comment.text.trim();
    if (t.length < 3) return tr('Dehqonga maslahat yozing');
    if (t.length > _maxComment) return trf('{0} belgidan oshmasin', [_maxComment]);
    return null;
  }

  String? get _sourceError {
    final t = _source.text.trim();
    if (t.isEmpty) return null;
    final u = Uri.tryParse(t);
    return u != null && u.scheme == 'https' && u.host.contains('.') ? null : tr("Manba https:// bilan boshlanadigan to'liq havola bo'lsin");
  }

  Future<void> _send(QueueItem i, ReviewDraft d) async {
    setState(() => _tried = true);
    if (_commentError != null || _sourceError != null) return;
    setState(() => _busy = true);
    final status = d.isRetake ? 'rejected' : (d.label == i.aiLabel ? 'confirmed' : 'corrected');
    try {
      final next = await ref
          .read(expertRepoProvider)
          .review(
            widget.id,
            status: status,
            label: status == 'corrected' ? d.label : null,
            comment: _comment.text,
            source: _source.text,
            retakeReason: d.retakeReason,
          );
      ref.read(reviewDraftsProvider.notifier).clear(widget.id);
      ref.invalidate(reviewQueueProvider);
      ref.invalidate(queueCountsProvider);
      ref.invalidate(expertStatsProvider);
      if (!mounted) return;
      showToast(context, d.isRetake ? tr("Dehqonga qayta surat so'rovi yuborildi") : tr('Xulosa dehqonga yuborildi'));
      // Tekshirish sahifasini ham yopamiz: navbatdagi keyingi ish yoki navbat
      final router = GoRouter.of(context);
      router.go('/expert');
      if (next != null) router.push('/expert/review/${next.id}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = ref.watch(reviewDraftsProvider)[widget.id] ?? const ReviewDraft();
    final value = ref.watch(queueItemProvider(widget.id));
    final i = value.value;
    final ok = i != null && (d.label != null || d.isRetake);
    return PopScope(
      onPopInvokedWithResult: (_, __) => _save(),
      child: PageShell(
        padBottom: false,
        maxWidth: 680,
        bottom: !ok
            ? null
            : _StickyCta(
                label: d.isRetake ? tr("Qayta surat so'rash") : tr('Dehqonga yuborish'),
                icon: Icons.send_rounded,
                busy: _busy,
                onPressed: _busy ? null : () => _send(i, d),
              ),
        child: AsyncView(
          value: value,
          onRetry: () => ref.invalidate(queueItemProvider(widget.id)),
          data: (i) {
            if (!ok) {
              return Column(
                children: [
                  TopBar(title: tr('Ekspert xulosasi')),
                  _InfoState(
                    icon: Icons.rule_rounded,
                    title: tr('Tanlov yo\'q'),
                    text: tr("Tekshirish sahifasida kasallikni yoki «Rasm yetarli emas»ni tanlang."),
                    action: PillButton(label: tr('Orqaga'), style: PillStyle.outline, onPressed: () => context.pop()),
                  ),
                ],
              );
            }
            final corrected = !d.isRetake && d.label != i.aiLabel;
            final asset = CatalogImages.disease(d.label);
            final reason = d.isRetake ? tr(retakeReasons.firstWhere((r) => r.$1 == d.retakeReason).$2) : null;
            final cErr = _tried ? _commentError : null, sErr = _sourceError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TopBar(title: tr('Ekspert xulosasi')),
                _Banner(
                  icon: d.isRetake
                      ? Icons.photo_camera_back_outlined
                      : corrected
                      ? Icons.edit_outlined
                      : Icons.verified_outlined,
                  color: d.isRetake || corrected ? c.warning : c.success,
                  bg: d.isRetake || corrected ? c.warningBg : c.successBg,
                  title: d.isRetake
                      ? tr("Qayta surat so'raladi")
                      : corrected
                      ? tr('AI taxmini tuzatildi')
                      : tr('AI taxmini tasdiqlandi'),
                  text: d.isRetake
                      ? tr("Dehqonga qayta suratga olish ko'rsatmasi yuboriladi. Davolash rejasi yuborilmaydi.")
                      : tr("Quyidagi xulosa sizning professional bilimingiz asosida tayyorlanadi."),
                ),
                const SizedBox(height: 16),
                _Label(d.isRetake ? tr('Sabab') : tr('Kasallik'), d.isRetake ? null : tr('(sizning tanlovingiz)')),
                AppCard(
                  shadow: false,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  onTap: () => context.pop(),
                  child: Row(
                    children: [
                      d.isRetake
                          ? Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.image_not_supported_outlined, color: c.warning),
                            )
                          : CatalogImage(asset: asset, url: asset == null ? AppConfig.mediaUrl(i.imageUrl) : null, width: 56, height: 56, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          d.isRetake ? reason! : (d.name ?? d.label!),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
                        ),
                      ),
                      Semantics(
                        label: tr("Tanlovni o'zgartirish"),
                        child: Icon(Icons.chevron_right_rounded, color: c.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Label(d.isRetake ? tr("Dehqonga ko'rsatma") : tr('Dehqonga maslahat'), null, required: true),
                TextField(
                  controller: _comment,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: _maxComment,
                  onChanged: (_) => setState(_save),
                  decoration: InputDecoration(
                    hintText: d.isRetake
                        ? tr("Masalan: bitta zararlangan bargni kunduzi, 20–30 sm masofadan suratga oling.")
                        : tr("Kuzatilgan belgilar va tavsiya etilgan choralar…"),
                    errorText: cErr,
                    errorMaxLines: 2,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t
                        in d.isRetake
                            ? [
                                tr('Bargni yaqinroqdan, kunduzi suratga oling'),
                                tr('Bitta bargni oq fonda suratga oling'),
                                tr("Bargning ikkala tomonini ham yuboring"),
                              ]
                            : [
                                tr('Zararlangan barglarni olib tashlang'),
                                tr('Ekin almashinuviga rioya qiling'),
                                tr("3 kundan keyin yangi rasm yuboring"),
                                tr("Sug'orishni kamaytiring"),
                              ])
                      ActionChip(
                        label: Text(t),
                        backgroundColor: c.card,
                        side: BorderSide(color: c.border),
                        shape: const StadiumBorder(),
                        onPressed: () {
                          final cur = _comment.text.trim();
                          _comment.text = cur.isEmpty ? '$t.' : '$cur\n• $t.';
                          setState(_save);
                        },
                      ),
                  ],
                ),
                if (!d.isRetake) ...[
                  const SizedBox(height: 18),
                  _Label(tr('Foydali manba'), tr('(ixtiyoriy)')),
                  TextField(
                    controller: _source,
                    keyboardType: TextInputType.url,
                    inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                    onChanged: (_) => setState(_save),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.link_rounded),
                      hintText: 'https://…',
                      errorText: sErr,
                      errorMaxLines: 2,
                      helperText: tr("Faqat o'zingiz tekshirgan manba. Havola manba haqiqiyligini tasdiqlamaydi."),
                      suffixIcon: _source.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr('Tozalash'),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _source.clear();
                                _save();
                              }),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _Label(tr("Xulosa ko'rinishi"), tr('(dehqonga shu tarzda yuboriladi)')),
                AppCard(
                  shadow: false,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CatalogImage(url: AppConfig.mediaUrl(i.imageUrl), width: 64, height: 64, radius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.plantName ?? '',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
                                ),
                                Text(d.isRetake ? tr('Agronom: rasmni qayta oling') : (d.name ?? d.label!), style: TextStyle(color: c.text, height: 1.3)),
                                const SizedBox(height: 4),
                                StatusTag(
                                  d.isRetake
                                      ? tr('Qayta surat kerak')
                                      : corrected
                                      ? tr('Agronom tuzatgan')
                                      : tr('Agronom tasdiqlagan'),
                                  kind: d.isRetake ? StatusKind.risk : StatusKind.healthy,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        [if (reason != null) '$reason.', _comment.text.trim()].where((s) => s.isNotEmpty).join(' ').isEmpty
                            ? tr('Maslahat matni shu yerda ko\'rinadi')
                            : [if (reason != null) '$reason.', _comment.text.trim()].join(' '),
                        style: TextStyle(color: _comment.text.trim().isEmpty ? c.muted : c.text, height: 1.45),
                      ),
                      if (_source.text.trim().isNotEmpty && sErr == null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.link_rounded, size: 16, color: c.muted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(Uri.parse(_source.text.trim()).host, style: TextStyle(color: c.muted, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  d.isRetake
                      ? tr("Dehqon yangi surat yuborsa, u qayta tekshiruv navbatiga tushadi.")
                      : tr("Dehqon AI natijasini ham, sizning xulosangizni ham ko'radi. Tasdiqlangan rasm AI datasetiga qo'shiladi."),
                  style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------- Umumiy bo'laklar ----------
class _StickyCta extends StatelessWidget {
  const _StickyCta({required this.label, required this.onPressed, this.icon, this.hint, this.busy = false});
  final String label;
  final String? hint;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.cream,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        hint!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: c.muted),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: c.onPrimary,
                        disabledBackgroundColor: c.border,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: onPressed,
                      child: busy
                          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.onPrimary))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                                Flexible(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                ),
                                if (icon == null) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 20)],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.hint, {this.required = false});
  final String text;
  final String? hint;
  final bool required;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text),
            ),
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: c.danger, fontWeight: FontWeight.w800),
              ),
            if (hint != null)
              TextSpan(
                text: '  $hint',
                style: TextStyle(fontSize: 13, color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.bg, required this.title, required this.text});
  final IconData icon;
  final Color color, bg;
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(color: context.c.text, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InfoState extends StatelessWidget {
  const _InfoState({required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title, text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 44, color: c.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: c.text,
          backgroundColor: active ? c.warningBg : c.card,
          side: BorderSide(color: active ? c.warning : c.lineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class _AltTile extends StatelessWidget {
  const _AltTile({required this.a, required this.selected, required this.onTap, this.mine = false});
  final Alternative a;
  final bool selected, mine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = a.confidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? c.olive : c.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  CatalogImage(asset: CatalogImages.disease(a.label), width: 56, height: 56, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.diseaseName ?? a.label,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text, height: 1.25),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mine
                              ? tr('Siz tanlagan (AI taxminida yo\'q)')
                              : pct == null
                              ? tr('Model ishonchi: mavjud emas')
                              : trf('Model ishonchi: {0}%', [pct.round()]),
                          style: TextStyle(fontSize: 13, color: selected ? c.success : c.muted, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                        ),
                        if (pct != null && !mine) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), minHeight: 6, color: c.success, backgroundColor: c.cream2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  selected
                      ? Icon(Icons.check_circle_rounded, color: c.olive)
                      : Text(
                          pct == null ? '' : '${pct.round()}%',
                          style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetakeSheet extends StatefulWidget {
  const _RetakeSheet({this.current});
  final String? current;
  @override
  State<_RetakeSheet> createState() => _RetakeSheetState();
}

class _RetakeSheetState extends State<_RetakeSheet> {
  late String? _v = widget.current;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Rasm yetarli emas'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
            ),
            const SizedBox(height: 4),
            Text(tr("Sababni tanlang — keyingi bosqichda dehqonga aniq ko'rsatma yozasiz."), style: TextStyle(color: c.muted, height: 1.4)),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _v,
              onChanged: (x) => setState(() => _v = x),
              child: Column(
                children: [for (final (k, t) in retakeReasons) RadioListTile<String>(value: k, title: Text(tr(t)), contentPadding: EdgeInsets.zero)],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _v == null ? null : () => Navigator.pop(context, _v),
                child: Text(tr('Tanlash'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// To'liq ekran rasm: zoom/pan, yopish tugmasi; asl rang o'zgartirilmaydi. Back avval shu ko'rinishni yopadi.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 6,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              tooltip: tr('Yopish'),
              style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shu ekinning boshqa kasalliklari — ma'lumotnoma rasmlari bilan solishtirib tanlash. Qidiruv bor; sog'lom alohida.
class _OtherDiseaseSheet extends ConsumerStatefulWidget {
  const _OtherDiseaseSheet({this.plantName});
  final String? plantName;
  @override
  ConsumerState<_OtherDiseaseSheet> createState() => _OtherDiseaseSheetState();
}

class _OtherDiseaseSheetState extends ConsumerState<_OtherDiseaseSheet> {
  String _q = '';
  bool _allPlants = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final all = ref.watch(diseasesProvider);
    final plantName = _allPlants ? null : widget.plantName;
    final prefix = CatalogImages.plantPrefix[widget.plantName];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => AsyncView(
        value: all,
        onRetry: () => ref.invalidate(diseasesProvider),
        data: (list) {
          final items =
              list
                  .where(
                    (d) =>
                        d.aiLabel != null && (plantName == null || d.plantName == plantName) && (_q.isEmpty || d.name.toLowerCase().contains(_q.toLowerCase())),
                  )
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Text(
                tr('Boshqa kasallik'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Kasallik nomi bo\'yicha qidirish…')),
              ),
              if (widget.plantName != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allPlants,
                  onChanged: (v) => setState(() => _allPlants = v),
                  title: Text(trf("Faqat {0} emas, barcha ekinlar", [widget.plantName])),
                ),
              const SizedBox(height: 6),
              if (prefix != null && _q.isEmpty)
                _SheetRow(
                  asset: CatalogImages.disease('${prefix}_healthy'),
                  title: tr("Sog'lom"),
                  tag: StatusTag(tr("Sog'lom"), kind: StatusKind.healthy),
                  onTap: () => Navigator.pop(ctx, Alternative(label: '${prefix}_healthy', diseaseName: tr("Sog'lom"), healthy: true)),
                ),
              for (final d in items)
                _SheetRow(
                  asset: CatalogImages.disease(d.aiLabel),
                  url: AppConfig.mediaUrl(d.imageUrl),
                  title: d.name,
                  sub: plantName == null ? d.plantName : null,
                  tag: RiskTag(d.riskLevel),
                  onTap: () => Navigator.pop(ctx, Alternative(label: d.aiLabel!, diseaseId: d.id, diseaseName: d.name)),
                ),
              if (items.isEmpty) EmptyNote(_q.isEmpty ? tr("Bu ekin uchun ma'lumotnomada kasallik yo'q") : tr('Hech narsa topilmadi')),
              const SizedBox(height: 8),
              Text(
                tr("Ro'yxatda yo'q yoki noma'lum holat bo'lsa — «Rasm yetarli emas» → «Kontekst yetarli emas» orqali aniqlashtirishni so'rang."),
                style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.title, required this.onTap, this.asset, this.url, this.sub, this.tag});
  final String title;
  final String? asset, url, sub;
  final Widget? tag;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    shadow: false,
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 10),
    onTap: onTap,
    child: Row(
      children: [
        CatalogImage(asset: asset, url: url, width: 64, height: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
              if (tag != null) Padding(padding: const EdgeInsets.only(top: 6), child: tag!),
            ],
          ),
        ),
      ],
    ),
  );
}
