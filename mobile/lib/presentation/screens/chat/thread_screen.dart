import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import 'chat_widgets.dart';

/// Real-time chat: WebSocket /ws/chat/{id}; ulanish bo'lmasa REST'ga qaytadi.
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
  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  bool _loading = true, _online = false, _typing = false;
  Timer? _typingTimer;
  AppUser? _other;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(communityRepoProvider);
    try {
      final convs = await repo.conversations();
      _other = convs.where((c) => c.id == widget.id).firstOrNull?.other;
      final msgs = await repo.messages(widget.id);
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
      _toBottom();
      await _connect();
      final lastIncoming = msgs.lastWhere((m) => m.senderId != ref.read(currentUserProvider)?.id, orElse: () => ChatMessage(id: '', senderId: ''));
      if (lastIncoming.id.isNotEmpty) await repo.markRead(lastIncoming.id);
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _connect() async {
    final token = await ref.read(tokenStorageProvider).readAccess();
    try {
      final ws = WebSocketChannel.connect(Uri.parse('${AppConfig.wsUrl}/ws/chat/${widget.id}?token=$token'));
      await ws.ready;
      _ws = ws;
      setState(() => _online = true);
      _sub = ws.stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        switch (data['event']) {
          case 'message':
            final m = ChatMessage.fromJson(Map<String, dynamic>.from(data['data']));
            if (!_messages.any((x) => x.id == m.id)) setState(() => _messages.add(m));
            if (m.senderId != ref.read(currentUserProvider)?.id) ws.sink.add(jsonEncode({'type': 'read'}));
            _toBottom();
          case 'typing':
            if (data['user_id'] != ref.read(currentUserProvider)?.id) {
              setState(() => _typing = true);
              _typingTimer?.cancel();
              _typingTimer = Timer(const Duration(seconds: 2), () => mounted ? setState(() => _typing = false) : null);
            }
          case 'read':
            if (data['user_id'] != ref.read(currentUserProvider)?.id) {
              setState(() {
                for (var i = 0; i < _messages.length; i++) {
                  final m = _messages[i];
                  if (!m.isRead) _messages[i] = ChatMessage(id: m.id, senderId: m.senderId, content: m.content, imageUrl: m.imageUrl, isRead: true, createdAt: m.createdAt);
                }
              });
            }
        }
      }, onDone: () => mounted ? setState(() => _online = false) : null, onError: (_) => mounted ? setState(() => _online = false) : null);
    } catch (_) {
      setState(() => _online = false);
    }
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    if (_online && _ws != null) {
      _ws!.sink.add(jsonEncode({'type': 'message', 'content': t}));
    } else {
      try {
        final m = await ref.read(communityRepoProvider).send(widget.id, t);
        setState(() => _messages.add(m));
        _toBottom();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  DateTime _lastTyping = DateTime(2000);
  void _onChanged(String _) {
    if (_online && DateTime.now().difference(_lastTyping).inMilliseconds > 1200) {
      _lastTyping = DateTime.now();
      _ws?.sink.add(jsonEncode({'type': 'typing'}));
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  @override
  void dispose() {
    _sub?.cancel();
    _ws?.sink.close();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TopBar(
                  title: _other?.fullName ?? 'Suhbat',
                  subtitle: _typing ? 'yozmoqda...' : (_online ? 'Onlayn' : 'Oflayn'),
                  leading: _other == null ? null : Avatar(name: _other!.fullName, url: _other!.avatarUrl, size: 34),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        children: [
                          if (_messages.isEmpty) const EmptyNote('Suhbatni boshlang'),
                          for (final m in _messages)
                            MessageBubble(text: m.content ?? '', me: m.senderId == me?.id, time: m.createdAt, read: m.senderId == me?.id ? m.isRead : null),
                        ],
                      ),
              ),
              ChatInputBar(controller: _ctrl, onSend: _send, onChanged: _onChanged),
            ]),
          ),
        ),
      ),
    );
  }
}
