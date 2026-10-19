import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../chat/chat_widgets.dart';

final _aiHistoryProvider = FutureProvider.autoDispose<List<AIMessage>>((ref) => ref.watch(communityRepoProvider).aiHistory());

/// Yuborilmagan matn ekrandan chiqib qaytganda saqlanadi (TZ S10: draft).
String _draft = '';

class _Local {
  _Local(this.text) : at = DateTime.now();
  final String text;
  final DateTime at;
  MsgState state = MsgState.pending;
  AIMessage? reply;
  String? error;
}

/// S10 AI bilan suhbat. Tayyor savol faqat yozish maydoniga qo'yiladi — foydalanuvchi o'zi yuboradi
/// (yashirin so'rov va limit sarfi yo'q). Xabar: yuborilmoqda → javob yoki xato + qayta urinish.
/// Backend bitta suhbat tarixini saqlaydi va javobni oqim (streaming) bilan bermaydi.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.prefill});
  final String? prefill;
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<AssistantScreen> {
  late final _ctrl = TextEditingController(text: widget.prefill ?? _draft);
  final _scroll = ScrollController();
  final List<_Local> _local = [];

  bool get _busy => _local.any((m) => m.state == MsgState.pending);

  static List<String> get _suggestions => [
        tr("Pomidor bargida qo'ng'ir dog'lar paydo bo'ldi"),
        tr("Bodring bargida oq g'ubor bor"),
        tr("Qachon sug'orish kerak?"),
        tr('Bordo suyuqligini qanday ishlatish kerak?'),
      ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => _draft = _ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _nearBottom => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 160;

  void _toBottom({bool force = false}) {
    if (!force && !_nearBottom) return; // auto-scroll faqat foydalanuvchi pastda bo'lsa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _ask(_Local m) async {
    setState(() {
      m.state = MsgState.pending;
      m.error = null;
    });
    _toBottom(force: true);
    try {
      final reply = await ref.read(communityRepoProvider).aiAsk(m.text);
      if (!mounted) return;
      setState(() {
        m.reply = reply;
        m.state = MsgState.sent;
      });
      ref.invalidate(mySubscriptionProvider);
      _toBottom();
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.from(e);
      setState(() {
        m.state = MsgState.failed;
        m.error = err.message;
      });
      if (err.isPaymentRequired) showError(context, e);
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return; // bitta yuborishda bitta xabar
    _ctrl.clear();
    final m = _Local(text);
    _local.add(m);
    _ask(m);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final history = ref.watch(_aiHistoryProvider);
    final old = history.value;
    Widget body;
    if (old == null && history.hasError) {
      body = Padding(padding: const EdgeInsets.all(16), child: BlockError(error: history.error!, what: tr('Suhbat tarixi'), onRetry: () => ref.invalidate(_aiHistoryProvider)));
    } else if (old == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final empty = old.isEmpty && _local.isEmpty;
      body = ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
        MessageBubble(
          label: tr('AI yordamchi'),
          text: tr("Salom! Ekin kasalliklari, dorilar va parvarish haqida so'rang. Javoblarim agronom tavsiyasi emas — muhim qarorda mutaxassis bilan maslahatlashing."),
        ),
        if (empty) ...[
          Text(tr('Masalan, shunday so\'rashingiz mumkin:'), style: TextStyle(color: c.muted, fontSize: 14)),
          const SizedBox(height: 8),
          for (final s in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: c.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // Faqat yozish maydoniga qo'yiladi; yuborish — foydalanuvchida
                  onTap: () => setState(() {
                    _ctrl.text = s;
                    _ctrl.selection = TextSelection.collapsed(offset: s.length);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Icon(Icons.edit_note_rounded, color: c.olive),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s, style: TextStyle(fontSize: 15, color: c.text))),
                    ]),
                  ),
                ),
              ),
            ),
        ],
        for (final m in old) MessageBubble(text: m.content, me: m.isUser, time: m.createdAt, label: m.isUser ? null : tr('AI yordamchi')),
        for (final m in _local) ...[
          MessageBubble(text: m.text, me: true, time: m.at, state: m.state, onRetry: () => _ask(m)),
          if (m.state == MsgState.failed && m.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(m.error!, textAlign: TextAlign.end, style: TextStyle(color: c.danger, fontSize: 14)),
            ),
          if (m.state == MsgState.pending) MessageBubble(text: tr('Javob tayyorlanmoqda...'), muted: true, label: tr('AI yordamchi')),
          if (m.reply != null) MessageBubble(text: m.reply!.content, time: m.reply!.createdAt, label: tr('AI yordamchi')),
        ],
      ]);
    }

    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TopBar(title: tr('AI yordamchi'), actions: [
                  Tooltip(
                    message: tr('Ekinni tekshirish'),
                    child: IconButton(onPressed: () => context.push('/diagnose'), icon: Icon(AppIcons.scan, color: c.text)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(tr("Rasm bo'yicha tekshiruv uchun «Ekinni tekshirish»dan foydalaning."), style: TextStyle(color: c.muted, fontSize: 14)),
              ),
              Expanded(child: body),
              ChatInputBar(controller: _ctrl, onSend: _send, hint: tr('Savolingizni yozing...'), busy: _busy, maxLength: 4000),
            ]),
          ),
        ),
      ),
    );
  }
}
