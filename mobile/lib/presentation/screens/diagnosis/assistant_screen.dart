import 'package:dio/dio.dart';
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

/// Yuborilmagan matn ekrandan chiqib qaytganda saqlanadi (TZ S10: draft) — suhbat bo'yicha, boshqa hisobga o'tmaydi.
final Map<String, String> _drafts = {};
String? _draftOwner;

/// Server eski tarixni "Oldingi suhbat" nomi bilan ko'chiradi — u tanlangan tilda ko'rsatiladi; qolgan nomlar foydalanuvchiniki.
String aiTitle(String title) => title == 'Oldingi suhbat' ? tr('Oldingi suhbat') : title;

/// AI suhbatini qayta nomlash (S09 ro'yxati va S10 menyusi uchun umumiy).
Future<String?> renameAiConversation(BuildContext context, WidgetRef ref, String id, String current) async {
  final ctrl = TextEditingController(text: current);
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Suhbat nomi')),
      content: SizedBox(width: 420, child: TextField(controller: ctrl, autofocus: true, maxLength: 100, style: const TextStyle(fontSize: 16))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(tr('Saqlash'))),
      ],
    ),
  );
  ctrl.dispose();
  if (title == null || title.isEmpty || title == current || !context.mounted) return null;
  try {
    await ref.read(communityRepoProvider).aiRename(id, title);
    ref.invalidate(aiConversationsProvider);
    return title;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

/// AI suhbatini o'chirish (tasdiq bilan). true — o'chirildi.
Future<bool> deleteAiConversation(BuildContext context, WidgetRef ref, String id, String title) async {
  final ok = await confirm(context, tr("Suhbatni o'chirasizmi?"), trf("«{0}» va undagi barcha xabarlar o'chiriladi.", [title]), ok: tr("O'chirish"), danger: true);
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(communityRepoProvider).aiDelete(id);
    ref.invalidate(aiConversationsProvider);
    if (context.mounted) showToast(context, tr("Suhbat o'chirildi"));
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

enum _TurnState { sending, streaming, failed }

/// Hozirgi savol-javob: savol serverda tasdiqlanguncha [user] yo'q; javob bo'laklari [buffer]ga yig'iladi.
class _Turn {
  _Turn(this.text, {this.user}) : at = DateTime.now();
  final String text;
  final DateTime at;
  AIMessage? user;
  final buffer = StringBuffer();
  _TurnState state = _TurnState.sending;
  String? error;
  CancelToken? cancel;
}

/// S10 AI bilan suhbat. Savol yuborilmoqda → tasdiqlandi → javob oqim bilan (bo'lib-bo'lib) keladi; "To'xtatish"
/// oqimni to'xtatadi — qisman javob "to'xtatildi" deb belgilanadi va tugallangan hisoblanmaydi. "Qayta javob" aynan
/// shu savolga bog'langan javobni almashtiradi. Tayyor savol faqat yozish maydoniga qo'yiladi. Menyu: nomlash, o'chirish.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.prefill, this.conversationId});
  final String? prefill;
  final String? conversationId;
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<AssistantScreen> {
  late String? _convId = widget.conversationId;
  String? _title;
  late final _ctrl = TextEditingController(text: widget.prefill ?? _savedDraft);
  final _scroll = ScrollController();
  final List<AIMessage> _messages = [];
  _Turn? _turn;
  bool _loading = false;
  Object? _loadError;

  String get _draftKey => _convId ?? '_new';
  String get _savedDraft => _draftOwner == ref.read(currentUserProvider)?.id ? (_drafts[_draftKey] ?? '') : '';
  bool get _streaming => _turn != null && _turn!.state != _TurnState.failed;

  static List<String> get _suggestions => [
        tr("Pomidor bargida qo'ng'ir dog'lar paydo bo'ldi"),
        tr("Bodring bargida oq g'ubor bor"),
        tr("Qachon sug'orish kerak?"),
        tr('Bordo suyuqligini qanday ishlatish kerak?'),
      ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _drafts[_draftKey] = _ctrl.text;
      _draftOwner = ref.read(currentUserProvider)?.id;
    });
    if (_convId != null) _load();
  }

  @override
  void dispose() {
    _turn?.cancel?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(communityRepoProvider);
      final msgs = await repo.aiMessages(_convId!);
      final convs = await repo.aiConversations();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _title = convs.where((c) => c.id == _convId).firstOrNull?.title;
        _loading = false;
      });
      _toBottom(force: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  bool get _nearBottom => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 160;

  void _toBottom({bool force = false}) {
    if (!force && !_nearBottom) return; // auto-scroll faqat foydalanuvchi pastda bo'lsa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Oqimni o'qiydi. [retryOf] berilsa — qayta javob (savol allaqachon tasdiqlangan).
  Future<void> _run(_Turn t, {String? retryOf}) async {
    final repo = ref.read(communityRepoProvider);
    final cancel = CancelToken();
    setState(() {
      t
        ..cancel = cancel
        ..state = retryOf == null ? _TurnState.sending : _TurnState.streaming
        ..error = null
        ..buffer.clear();
      _turn = t;
    });
    _toBottom(force: true);
    final stream = retryOf == null ? repo.aiSend(t.text, conversationId: _convId, cancel: cancel) : repo.aiRetry(retryOf, cancel: cancel);
    try {
      await for (final ev in stream) {
        if (!mounted) return;
        switch (ev.type) {
          case 'user':
            final u = AIMessage.fromJson(Map<String, dynamic>.from(ev.data['message']));
            setState(() {
              t
                ..user = u
                ..state = _TurnState.streaming;
              if (_convId == null) {
                _drafts.remove(_draftKey);
                _convId = u.conversationId;
                _title = ev.data['conversation_title'] as String?;
              }
            });
            ref.invalidate(mySubscriptionProvider);
          case 'delta':
            setState(() => t.buffer.write(ev.data['text'] ?? ''));
            _toBottom();
          case 'done':
            final reply = AIMessage.fromJson(Map<String, dynamic>.from(ev.data['reply']));
            setState(() {
              _messages.addAll([if (t.user != null && retryOf == null) t.user!, reply]);
              _turn = null;
            });
            ref.invalidate(aiConversationsProvider);
            _toBottom();
            return;
          case 'error':
            setState(() {
              t
                ..state = _TurnState.failed
                ..error = ev.data['detail'] is String ? tr(ev.data['detail'] as String) : tr("AI javob bera olmadi. Qayta urinib ko'ring.");
            });
            return;
        }
      }
      // oqim "done"siz tugadi — javob to'liq emas
      if (mounted && _turn == t) _interrupted(t, retryOf, tr('Javob uzildi. Qayta urinib ko\'ring.'));
    } catch (e) {
      if (!mounted) return;
      if (cancel.isCancelled) {
        _stopped(t, retryOf);
        return;
      }
      final err = ApiException.from(e);
      if (err.isPaymentRequired) showError(context, e);
      _interrupted(t, retryOf, err.message);
    }
  }

  /// Foydalanuvchi to'xtatdi: savol tasdiqlangan bo'lsa qisman javob (serverda ham "partial") ko'rsatiladi.
  void _stopped(_Turn t, String? retryOf) {
    setState(() {
      _turn = null;
      if (t.user == null && retryOf == null) {
        if (_ctrl.text.isEmpty) _ctrl.text = t.text; // savol qabul qilinmagan — matn yo'qolmaydi
        return;
      }
      if (retryOf == null) _messages.add(t.user!);
      final partial = t.buffer.toString().trim();
      if (partial.isNotEmpty) {
        _messages.add(AIMessage(role: 'assistant', content: partial, status: 'partial', replyToId: retryOf ?? t.user!.id, createdAt: DateTime.now()));
      }
    });
    ref.invalidate(aiConversationsProvider);
  }

  void _interrupted(_Turn t, String? retryOf, String message) {
    setState(() {
      if (t.user == null && retryOf == null) {
        // savol serverga yetmadi — "Qayta yuborish" shu savolni yana yuboradi
        t
          ..state = _TurnState.failed
          ..error = message;
        return;
      }
      _turn = null;
      if (retryOf == null) _messages.add(t.user!);
      final partial = t.buffer.toString().trim();
      if (partial.isNotEmpty) {
        _messages.add(AIMessage(role: 'assistant', content: partial, status: 'partial', replyToId: retryOf ?? t.user!.id, createdAt: DateTime.now()));
      }
    });
    showToast(context, message);
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _turn != null) return; // bitta vaqtda bitta savol
    _ctrl.clear();
    _run(_Turn(text));
  }

  void _stop() => _turn?.cancel?.cancel();

  /// Qayta javob: shu savolga bog'langan javob(lar) ro'yxatdan olinadi, yangisi oqim bilan keladi.
  void _retry(AIMessage question) {
    if (_turn != null || question.id == null) return;
    setState(() => _messages.removeWhere((m) => !m.isUser && m.replyToId == question.id));
    _run(_Turn(question.content, user: question), retryOf: question.id);
  }

  Future<void> _menu(String v) async {
    final id = _convId;
    switch (v) {
      case 'new':
        context.pushReplacement('/assistant');
      case 'rename':
        if (id == null) return;
        final t = await renameAiConversation(context, ref, id, _title ?? '');
        if (t != null && mounted) setState(() => _title = t);
      case 'delete':
        if (id == null) return;
        if (await deleteAiConversation(context, ref, id, _title ?? tr('Suhbat')) && mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/help?tab=ai');
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ApiException.from(_loadError!).statusCode == 404
            ? EmptyNote(tr('Suhbat topilmadi'), icon: Icons.search_off_rounded)
            : BlockError(error: _loadError!, what: tr('Suhbat tarixi'), onRetry: _load),
      );
    } else {
      final t = _turn;
      final empty = _messages.isEmpty && t == null;
      final lastQuestion = _messages.lastWhere((m) => m.isUser, orElse: () => AIMessage(role: 'none', content: ''));
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
        for (var i = 0; i < _messages.length; i++) ..._messageWidgets(_messages[i], i, lastQuestion),
        if (t != null) ...[
          MessageBubble(
            text: t.user?.content ?? t.text,
            me: true,
            time: t.at,
            state: t.user != null ? MsgState.sent : (t.state == _TurnState.failed ? MsgState.failed : MsgState.pending),
            onRetry: t.state == _TurnState.failed && t.user == null ? () => _run(t) : null,
            onRemove: t.state == _TurnState.failed && t.user == null
                ? () => setState(() {
                      _turn = null;
                      if (_ctrl.text.isEmpty) _ctrl.text = t.text;
                    })
                : null,
          ),
          if (t.state == _TurnState.failed && t.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(t.error!, textAlign: TextAlign.end, style: TextStyle(color: c.danger, fontSize: 14)),
            ),
          if (t.state == _TurnState.streaming)
            Semantics(
              liveRegion: true,
              child: MessageBubble(
                text: t.buffer.isEmpty ? tr('Javob tayyorlanmoqda...') : t.buffer.toString(),
                muted: t.buffer.isEmpty,
                label: tr('AI yordamchi'),
              ),
            ),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                child: TopBar(title: _title == null ? tr('AI yordamchi') : aiTitle(_title!), actions: [
                  Tooltip(
                    message: tr('Ekinni tekshirish'),
                    child: IconButton(onPressed: () => context.push('/diagnose'), icon: Icon(AppIcons.scan, color: c.text)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('Amallar'),
                    icon: Icon(Icons.more_vert_rounded, color: c.text),
                    onSelected: _menu,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'new', child: Text(tr('Yangi suhbat'))),
                      if (_convId != null && !_streaming) ...[
                        PopupMenuItem(value: 'rename', child: Text(tr('Nomini o\'zgartirish'))),
                        PopupMenuItem(value: 'delete', child: Text(tr("Suhbatni o'chirish"))),
                      ],
                    ],
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(tr("Rasm bo'yicha tekshiruv uchun «Ekinni tekshirish»dan foydalaning."), style: TextStyle(color: c.muted, fontSize: 14)),
              ),
              Expanded(child: body),
              ChatInputBar(
                controller: _ctrl,
                onSend: _streaming ? _stop : _send,
                icon: _streaming ? Icons.stop_rounded : AppIcons.send,
                sendTooltip: _streaming ? tr("To'xtatish") : null,
                allowEmpty: _streaming,
                hint: tr('Savolingizni yozing...'),
                maxLength: 4000,
                enabled: !_loading && _loadError == null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _messageWidgets(AIMessage m, int i, AIMessage lastQuestion) {
    final c = context.c;
    if (m.isUser) {
      final answered = _messages.skip(i + 1).any((x) => !x.isUser && x.replyToId == m.id);
      return [
        MessageBubble(text: m.content, me: true, time: m.createdAt, state: MsgState.sent),
        // javobsiz qolgan savol (oqim uzilgan) — shu savolga javob so'rash
        if (!answered && _turn == null && m.id != null)
          Align(alignment: Alignment.centerRight, child: _RetryButton(onPressed: () => _retry(m), label: tr('Javob olish'))),
      ];
    }
    final question = m.replyToId == null ? null : _messages.where((x) => x.isUser && x.id == m.replyToId).firstOrNull;
    final canRetry = question != null && _turn == null && (m.isPartial || question.id == lastQuestion.id);
    return [
      MessageBubble(text: m.content, time: m.createdAt, label: tr('AI yordamchi')),
      if (m.isPartial)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.stop_circle_outlined, size: 16, color: c.warning),
            const SizedBox(width: 6),
            Flexible(child: Text(tr("To'xtatildi — javob to'liq emas"), style: TextStyle(fontSize: 13.5, color: c.warning, fontWeight: FontWeight.w600))),
          ]),
        ),
      if (canRetry) Align(alignment: Alignment.centerLeft, child: _RetryButton(onPressed: () => _retry(question), label: tr('Qayta javob'))),
    ];
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: context.c.primaryDark),
          onPressed: onPressed,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}
