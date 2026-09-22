import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, this.me = false, this.time, this.muted = false, this.read});
  final String text;
  final bool me, muted;
  final DateTime? time;
  final bool? read;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width.clamp(0, 480) * 0.8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            SelectableText(text, style: TextStyle(fontSize: 14, height: 1.45, color: me ? c.card : (muted ? c.muted : c.text))),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(timeAgo(time), style: TextStyle(fontSize: 11, color: me ? c.card.withValues(alpha: 0.75) : c.muted)),
                  if (me && read != null) ...[
                    const SizedBox(width: 4),
                    Icon(read! ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: c.card.withValues(alpha: 0.8)),
                  ],
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({super.key, required this.controller, required this.onSend, this.hint = 'Xabar yozing...', this.icon = AppIcons.send, this.onChanged});
  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(color: c.card, boxShadow: [BoxShadow(color: c.shadow, blurRadius: 14, offset: const Offset(0, -4))]),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: c.primary)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: c.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSend,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, color: c.card, size: 20)),
          ),
        ),
      ]),
    );
  }
}
