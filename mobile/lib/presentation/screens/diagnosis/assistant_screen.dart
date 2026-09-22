import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../chat/chat_widgets.dart';

final _aiHistoryProvider = FutureProvider.autoDispose<List<AIMessage>>((ref) => ref.watch(communityRepoProvider).aiHistory());

/// AI Yordamchi — erkin savol-javob (kunlik limit bilan).
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<AIMessage> _local = [];
  bool _sending = false;

  static const _suggestions = [
    "Pomidor bargida qo'ng'ir dog'lar paydo bo'ldi",
    "Bodring bargida oq g'ubor bor",
    "Qachon sug'orish kerak?",
    'Bordo suyuqligini qanday ishlatish kerak?',
  ];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _local.add(AIMessage(role: 'user', content: text, createdAt: DateTime.now()));
      _sending = true;
    });
    _toBottom();
    try {
      final reply = await ref.read(communityRepoProvider).aiAsk(text);
      setState(() => _local.add(reply));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final history = ref.watch(_aiHistoryProvider);
    return Scaffold(
      backgroundColor: c.cream,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TopBar(title: 'AI yordamchi', subtitle: 'Onlayn — darhol javob beradi'),
              ),
              Expanded(
                child: history.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (old) {
                    final all = [...old, ..._local];
                    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
                      const MessageBubble(text: "Salom! Men AgroYordam AI yordamchisiman. Ekin kasalliklari, dorilar va parvarish haqida so'rang."),
                      if (all.isEmpty)
                        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in _suggestions) MiniButton(label: s, onTap: () => _send(s))]),
                      for (final m in all) MessageBubble(text: m.content, me: m.isUser, time: m.createdAt),
                      if (_sending) MessageBubble(text: 'Yozmoqda...', muted: true),
                    ]);
                  },
                ),
              ),
              ChatInputBar(controller: _ctrl, onSend: () => _send(), hint: 'Savolingizni yozing...', icon: AppIcons.send),
            ]),
          ),
        ),
      ),
    );
  }
}
