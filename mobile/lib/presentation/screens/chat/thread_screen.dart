import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/blocks.dart';
import '../../../core/widgets/photos.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../community/report_sheet.dart';
import 'chat_widgets.dart';

class _Out {
  _Out(this.text, this.photos) : at = DateTime.now();
  final String text;
  final List<PickedPhoto> photos;
  final DateTime at;
  bool failed = false;
}

/// S16 Shaxsiy suhbat. Yuborish doim REST orqali — natija aniq: yuborilmoqda → yuborildi → yetkazildi → o'qildi
/// (oxirgi ikkisi faqat server event bilan) yoki xato + qayta yuborish / olib tashlash. 1 yuborishda 5 tagacha rasm (jami ≤ 25 MB).
/// WebSocket yangi xabar, "yozmoqda", "yetkazildi" va "o'qildi" hodisalarini oladi; ulanmasa ekran REST bilan ishlayveradi.
/// Suhbatdoshning onlayn holati backend'da yo'q — shuning uchun ko'rsatilmaydi. Qoralama suhbat bo'yicha saqlanadi.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ThreadScreen> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<ThreadScreen> {
  /// TZ S16: qoralama conversationId bo'yicha (ilova ochiq turgan davomida).
  static final Map<String, String> _drafts = {};
  late final _ctrl = TextEditingController(text: _drafts[widget.id]);
  final List<PickedPhoto> _pending = [];
  bool _muted = false, _newBelow = false;
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
  static const _page = 50;
  bool _hasOlder = false, _loadingOlder = false;

  String? get _myId => ref.read(currentUserProvider)?.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_newBelow && _nearBottom) setState(() => _newBelow = false);
    });
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
        _muted = conv?.muted ?? false;
        _messages
          ..clear()
          ..addAll(msgs);
        _hasOlder = msgs.length >= _page;
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
        final wasNear = _nearBottom;
        _add(m);
        if (m.senderId != _myId) {
          _ws?.sink.add(jsonEncode({'type': 'read'}));
          if (!wasNear) setState(() => _newBelow = true); // pastga avtomatik tortilmaydi — tugma ko'rsatiladi
        }
        _toBottom();
      case 'delivered':
        if (data['user_id'] != _myId) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              final m = _messages[i];
              if (!m.delivered && m.senderId == _myId) _messages[i] = m.copyWith(delivered: true);
            }
          });
        }
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
              if (!m.isRead && m.senderId == _myId) _messages[i] = m.copyWith(isRead: true, delivered: true);
            }
          });
        }
    }
  }

  /// Eski xabarlar: ro'yxat tepasiga qo'shiladi, ko'rinayotgan joy siljimaydi.
  Future<void> _loadOlder() async {
    if (_loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final older = await ref.read(communityRepoProvider).messages(widget.id, before: _messages.first.id);
      if (!mounted) return;
      final before = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      setState(() {
        _messages.insertAll(0, older.where((m) => !_messages.any((x) => x.id == m.id)));
        _hasOlder = older.length >= _page;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset + (_scroll.position.maxScrollExtent - before));
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
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
      // Rasmlar avval yuklanadi; yuklanganlari qayta urinishda qayta yuklanmaydi
      final garden = ref.read(gardenRepoProvider);
      final ok = await uploadPhotos(o.photos, (b, n) => garden.upload(b, n, folder: 'messages'), () => mounted ? setState(() {}) : null);
      if (!ok) throw StateError('upload');
      final m = await ref.read(communityRepoProvider).send(widget.id, o.text, images: [for (final p in o.photos) p.url!]);
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
    if (t.isEmpty && _pending.isEmpty) return;
    _ctrl.clear();
    _drafts.remove(widget.id);
    final o = _Out(t, [..._pending]);
    setState(() {
      _out.add(o);
      _pending.clear();
    });
    _toBottom(force: true);
    _deliver(o);
  }

  Future<void> _attach() async {
    final picked = await pickPhotos(context, current: _pending);
    if (picked.isNotEmpty && mounted) setState(() => _pending.addAll(picked));
  }

  Future<void> _toggleMute() async {
    try {
      final conv = await ref.read(communityRepoProvider).muteConversation(widget.id, !_muted);
      if (!mounted) return;
      setState(() => _muted = conv.muted);
      ref.invalidate(conversationsProvider);
      showToast(context, _muted ? tr("Suhbat ovozsiz — bildirishnoma kelmaydi") : tr('Bildirishnomalar yoqildi'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// TZ S16 menyusi: shikoyat suhbatdoshning oxirgi xabari bo'yicha (alohida xabar — uni uzoq bosib).
  Future<void> _reportLast() async {
    final last = _messages.lastWhere((m) => m.senderId != _myId, orElse: () => ChatMessage(id: '', senderId: ''));
    if (last.id.isEmpty) {
      showToast(context, tr("Shikoyat qilish uchun suhbatdoshdan xabar yo'q"));
      return;
    }
    await showReportSheet(context, ref, messageId: last.id);
  }

  /// A08: suhbatdan turib bloklash (tasdiq bilan). Blokdan chiqarish — profil yoki "Bloklanganlar".
  Future<void> _block() async {
    final other = _other;
    if (other == null) return;
    final ok = await confirm(context, trf('{0} bloklansinmi?', [other.fullName]),
        tr("Bir-biringizning postlari, izohlari va qidiruvdagi profilingiz ko'rinmaydi, yozishib bo'lmaydi, obunalar bekor qilinadi. Blokdan chiqarish: Profil → Bloklanganlar."),
        ok: tr('Bloklash'), danger: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(communityRepoProvider).block(other.id, true);
      ref.invalidate(conversationsProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(blocksProvider);
      if (!mounted) return;
      setState(() => _blocked = true);
      showToast(context, trf('{0} bloklandi', [other.fullName]));
    } catch (e) {
      if (mounted) showError(context, e);
    }
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
    final draft = _ctrl.text.trim();
    if (draft.isEmpty) {
      _drafts.remove(widget.id);
    } else {
      _drafts[widget.id] = _ctrl.text;
    }
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
          if (_hasOlder)
            Center(
              child: TextButton.icon(
                onPressed: _loadingOlder ? null : _loadOlder,
                icon: _loadingOlder ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.history_rounded),
                label: Text(tr('Oldingi xabarlar')),
              ),
            ),
          if (_messages.isEmpty && _out.isEmpty)
            EmptyNote(trf('{0} bilan suhbatni boshlang', [other?.fullName ?? tr('Suhbatdosh')]), icon: Icons.waving_hand_outlined),
          for (final m in _messages)
            _Reportable(
              enabled: m.senderId != me?.id,
              onReport: () => showReportSheet(context, ref, messageId: m.id),
              child: MessageBubble(
              text: m.content ?? '',
              images: m.imageUrls,
              onImageTap: (i) => showPhotoViewer(context, m.imageUrls, initial: i, label: other?.fullName ?? ''),
              me: m.senderId == me?.id,
              time: m.createdAt,
              state: m.senderId == me?.id ? (m.isRead ? MsgState.read : (m.delivered ? MsgState.delivered : MsgState.sent)) : null,
              ),
            ),
          for (final o in _out)
            MessageBubble(
              text: o.text,
              localImages: [for (final p in o.photos) p.bytes!],
              me: true,
              time: o.at,
              state: o.failed ? MsgState.failed : MsgState.pending,
              onRetry: () => _deliver(o),
              onRemove: () => setState(() => _out.remove(o)),
            ),
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
                  if (_muted) Tooltip(message: tr('Ovozsiz'), child: Icon(Icons.notifications_off_outlined, color: c.muted, size: 20)),
                  if (!_loading && _error == null)
                    PopupMenuButton<String>(
                      tooltip: tr('Amallar'),
                      icon: Icon(Icons.more_vert_rounded, color: c.text),
                      onSelected: (v) => switch (v) {
                        'mute' => _toggleMute(),
                        'block' => _block(),
                        'report' => _reportLast(),
                        _ => other == null ? null : context.push('/users/${other.id}'),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'mute', child: Text(_muted ? tr('Ovozni yoqish') : tr('Ovozsiz qilish'))),
                        if (other != null) PopupMenuItem(value: 'profile', child: Text(tr('Profilni ko\'rish'))),
                        if (other != null && !_blocked) PopupMenuItem(value: 'block', child: Text(tr('Bloklash'))),
                        if (other != null) PopupMenuItem(value: 'report', child: Text(tr('Shikoyat qilish'))),
                      ],
                    ),
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
              Expanded(
                child: Stack(children: [
                  Positioned.fill(child: _loading || _error != null ? body : RefreshIndicator(onRefresh: _load, child: body)),
                  if (_newBelow)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: const Size(0, 44)),
                          onPressed: () {
                            setState(() => _newBelow = false);
                            _toBottom(force: true);
                          },
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          label: Text(tr('Yangi xabar')),
                        ),
                      ),
                    ),
                ]),
              ),
              ChatInputBar(
                controller: _ctrl,
                onSend: _send,
                onChanged: _onChanged,
                maxLength: 4000,
                allowEmpty: _pending.isNotEmpty,
                top: _pending.isEmpty ? null : PhotoPickerGrid(photos: _pending, size: 64, onRemove: (i) => setState(() => _pending.removeAt(i))),
                leading: IconButton(
                  tooltip: trf("Rasm biriktirish ({0}/{1})", [_pending.length, kMaxPhotos]),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _pending.length >= kMaxPhotos ? null : _attach,
                  icon: Icon(AppIcons.image, color: _pending.length >= kMaxPhotos ? c.muted : c.primaryDark),
                ),
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


/// Kelgan xabarni uzoq bosish → "Shikoyat qilish" (ekran o'quvchisi uchun ham amal sifatida).
class _Reportable extends StatelessWidget {
  const _Reportable({required this.enabled, required this.onReport, required this.child});
  final bool enabled;
  final VoidCallback onReport;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: tr('Shikoyat qilish')): onReport},
      child: GestureDetector(
        onLongPress: () async {
          final go = await showSheet<bool>(context, title: tr('Xabar'), builder: (ctx) => ListRow(
                icon: Icons.flag_outlined,
                label: tr('Shikoyat qilish'),
                onTap: () => Navigator.pop(ctx, true),
              ));
          if (go == true) onReport();
        },
        child: child,
      ),
    );
  }
}
