import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'chat_widgets.dart';

class _Out {
  _Out(this.text) : at = DateTime.now();
  final String text;
  final DateTime at;
  bool failed = false;
}

/// S16 Shaxsiy suhbat. Yuborish doim REST orqali — natija aniq: yuborilmoqda → yuborildi / xato + qayta yuborish.
/// WebSocket faqat yangi xabar, "yozmoqda" va "o'qildi" hodisalarini oladi; ulanmasa ekran REST bilan ishlayveradi.
/// Suhbatdoshning onlayn holati backend'da yo'q — shuning uchun ko'rsatilmaydi.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ThreadScreen> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<ThreadScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<_Out> _out = [];
  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  bool _loading = true, _live = false, _typing = false;
  Object? _error;
  Timer? _typingTimer;
  AppUser? _other;
  bool _blocked = false;

  String? get _myId => ref.read(currentUserProvider)?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(communityRepoProvider);
    try {
      final convs = await repo.conversations();
      final msgs = await repo.messages(widget.id);
      if (!mounted) return;
      setState(() {
        final conv = convs.where((c) => c.id == widget.id).firstOrNull;
        _other = conv?.other;
        _blocked = conv?.blocked ?? false;
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
      _toBottom(force: true);
      if (!_live) unawaited(_connect());
      final incoming = msgs.where((m) => m.senderId != _myId);
      if (incoming.isNotEmpty && !incoming.last.isRead) await repo.markRead(incoming.last.id);
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _connect() async {
    final token = await ref.read(tokenStorageProvider).readAccess();
    try {
      final ws = WebSocketChannel.connect(Uri.parse('${AppConfig.wsUrl}/ws/chat/${widget.id}?token=$token'));
      await ws.ready;
      if (!mounted) {
        ws.sink.close();
        return;
      }
      _ws = ws;
      setState(() => _live = true);
      await _sub?.cancel();
      _sub = ws.stream.listen(_onEvent, onDone: _dropped, onError: (_) => _dropped());
    } catch (_) {
      if (mounted) setState(() => _live = false);
    }
  }

  void _dropped() {
    _ws = null;
    if (mounted) setState(() => _live = false);
  }

  void _onEvent(dynamic raw) {
    final data = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (data['event']) {
      case 'message':
        final m = ChatMessage.fromJson(Map<String, dynamic>.from(data['data']));
        _add(m);
        if (m.senderId != _myId) _ws?.sink.add(jsonEncode({'type': 'read'}));
        _toBottom();
      case 'typing':
        if (data['user_id'] != _myId) {
          setState(() => _typing = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () => mounted ? setState(() => _typing = false) : null);
        }
      case 'read':
        if (data['user_id'] != _myId) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              final m = _messages[i];
              if (!m.isRead && m.senderId == _myId) {
                _messages[i] = ChatMessage(id: m.id, senderId: m.senderId, content: m.content, imageUrl: m.imageUrl, isRead: true, createdAt: m.createdAt);
              }
            }
          });
        }
    }
  }

  void _add(ChatMessage m) {
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() {
      _messages.add(m);
      if (m.senderId != _myId) _typing = false;
    });
  }

  Future<void> _deliver(_Out o) async {
    setState(() => o.failed = false);
    try {
      final m = await ref.read(communityRepoProvider).send(widget.id, o.text);
      if (!mounted) return;
      setState(() => _out.remove(o));
      _add(m); // WS orqali avvalroq kelgan bo'lsa takrorlanmaydi
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => o.failed = true);
      final err = ApiException.from(e);
      if (err.isPaymentRequired) showError(context, e);
    }
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    final o = _Out(t);
    setState(() => _out.add(o));
    _toBottom(force: true);
    _deliver(o);
  }

  DateTime _lastTyping = DateTime(2000);
  void _onChanged(String _) {
    if (_live && DateTime.now().difference(_lastTyping).inMilliseconds > 1500) {
      _lastTyping = DateTime.now();
      _ws?.sink.add(jsonEncode({'type': 'typing'}));
    }
  }

  bool get _nearBottom => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 160;

  /// Foydalanuvchi eski xabarlarni o'qiyotgan bo'lsa, yangi xabar uni pastga tortib ketmaydi.
  void _toBottom({bool force = false}) {
    if (!force && !_nearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ws?.sink.close();
    _typingTimer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    final other = _other;
    final notFound = _error != null && ApiException.from(_error!).statusCode == 404;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (notFound) {
      body = Padding(padding: const EdgeInsets.all(16), child: EmptyNote(tr('Suhbat topilmadi'), icon: Icons.search_off_rounded));
    } else if (_error != null) {
      body = Padding(padding: const EdgeInsets.all(16), child: BlockError(error: _error!, what: tr('Xabarlar'), onRetry: _load));
    } else {
      body = ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (_messages.isEmpty && _out.isEmpty)
            EmptyNote(trf('{0} bilan suhbatni boshlang', [other?.fullName ?? tr('Suhbatdosh')]), icon: Icons.waving_hand_outlined),
          for (final m in _messages)
            MessageBubble(
              text: (m.content ?? '').isNotEmpty ? m.content! : tr('Rasm'),
              me: m.senderId == me?.id,
              time: m.createdAt,
              state: m.senderId == me?.id ? (m.isRead ? MsgState.read : MsgState.sent) : null,
            ),
          for (final o in _out)
            MessageBubble(text: o.text, me: true, time: o.at, state: o.failed ? MsgState.failed : MsgState.pending, onRetry: () => _deliver(o)),
        ],
      );
    }

    final header = Semantics(
      button: other != null,
      label: other == null ? null : trf('{0} profili', [other.fullName]),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: other == null ? null : () => context.push('/users/${other.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            if (other != null) ...[Avatar(name: other.fullName, url: other.avatarUrl, size: 40, color: c.olive, textColor: c.onOlive), const SizedBox(width: 10)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(other?.fullName ?? tr('Suhbat'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                if (_typing)
                  Text(tr('yozmoqda...'), style: TextStyle(fontSize: 13.5, color: c.primary, fontWeight: FontWeight.w700))
                else if (other != null)
                  Text('@${other.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: c.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(children: [
                  IconButton(
                    tooltip: tr('Orqaga'),
                    onPressed: () async {
                      if (!await Navigator.of(context).maybePop() && context.mounted) context.go('/messages');
                    },
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                  ),
                  Expanded(child: header),
                ]),
              ),
              if (!_loading && _error == null && !_live)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: c.cream2,
                  child: Text(tr("Jonli yangilanish o'chiq — yangi xabarlar uchun pastga torting yoki qayta oching"),
                      style: TextStyle(fontSize: 13, color: c.muted)),
                ),
              Expanded(child: _loading || _error != null ? body : RefreshIndicator(onRefresh: _load, child: body)),
              ChatInputBar(
                controller: _ctrl,
                onSend: _send,
                onChanged: _onChanged,
                maxLength: 4000,
                enabled: !_loading && _error == null && !_blocked,
                disabledText: notFound
                    ? tr("Suhbat mavjud emas — xabar yozib bo'lmaydi")
                    : _blocked
                        ? tr("Bloklash sababli bu suhbatda yozib bo'lmaydi")
                        : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
