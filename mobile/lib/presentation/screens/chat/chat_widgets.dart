import 'package:flutter/material.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';

/// Xabar holati (TZ S16): navbatda → yuborildi → o'qildi (faqat server event bilan) yoki xato.
enum MsgState { pending, sent, read, failed }

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.text,
    this.me = false,
    this.time,
    this.muted = false,
    this.read,
    this.state,
    this.onRetry,
    this.label,
  });
  final String text;
  final bool me, muted;
  final DateTime? time;

  /// Eski chaqiruvlar uchun: true — o'qildi, false — yuborildi.
  final bool? read;
  final MsgState? state;
  final VoidCallback? onRetry;

  /// Yuboruvchi belgisi (masalan, "AI yordamchi") — foydalanuvchi xabaridan ajratish uchun.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = state ?? (read == null ? null : (read! ? MsgState.read : MsgState.sent));
    final fg = me ? c.onPrimary : (muted ? c.muted : c.text);
    final (statusIcon, statusText) = switch (st) {
      MsgState.pending => (Icons.schedule_rounded, tr('Yuborilmoqda')),
      MsgState.sent => (Icons.done_rounded, tr('Yuborildi')),
      MsgState.read => (Icons.done_all_rounded, tr("O'qildi")),
      MsgState.failed => (Icons.error_outline_rounded, tr('Yuborilmadi')),
      null => (null, null),
    };
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: st == MsgState.failed ? c.dangerBg : (me ? c.primary : c.card),
        border: me ? null : Border.all(color: c.border),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(me ? 16 : 4),
          bottomRight: Radius.circular(me ? 4 : 16),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.olive)),
          ),
        SelectableText(text, style: TextStyle(fontSize: 16, height: 1.45, color: st == MsgState.failed ? c.danger : fg)),
      ]),
    );
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width.clamp(0, 640) * 0.82),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            bubble,
            // Katta matnda toshib ketmasin — kerak bo'lsa keyingi qatorga o'tadi
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, alignment: me ? WrapAlignment.end : WrapAlignment.start, children: [
              if (time != null) Text(timeAgo(time), style: TextStyle(fontSize: 12.5, color: c.muted)),
              if (statusText != null) ...[
                const SizedBox(width: 6),
                Icon(statusIcon, size: 15, color: st == MsgState.failed ? c.danger : c.muted),
                const SizedBox(width: 3),
                Text(statusText, style: TextStyle(fontSize: 12.5, color: st == MsgState.failed ? c.danger : c.muted)),
              ],
              if (st == MsgState.failed && onRetry != null)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: onRetry,
                  child: Text(tr('Qayta yuborish')),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Yozish paneli: bo'sh/bo'sh joydan iborat matn yuborilmaydi, uzunlik chegarasi, 48 px tugma.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hint,
    this.icon = AppIcons.send,
    this.onChanged,
    this.maxLength = 4000,
    this.enabled = true,
    this.busy = false,
    this.disabledText,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final String? hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final int maxLength;
  final bool enabled, busy;

  /// Yozib bo'lmaganda (post o'chirilgan, bloklangan) — tushuntirish.
  final String? disabledText;
  final bool autofocus;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final len = widget.controller.text.characters.length;
    final canSend = widget.enabled && !widget.busy && widget.controller.text.trim().isNotEmpty && len <= widget.maxLength;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.viewPaddingOf(context).bottom),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: !widget.enabled && widget.disabledText != null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(widget.disabledText!, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15)),
            )
          : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => canSend ? widget.onSend() : null,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: widget.hint ?? tr('Xabar yozing...'),
                    counterText: len > widget.maxLength * 0.85 ? '$len/${widget.maxLength}' : null,
                    errorText: len > widget.maxLength ? trf('Ko\'pi bilan {0} belgi', [widget.maxLength]) : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: tr('Yuborish'),
                child: Material(
                  color: canSend ? c.primary : c.cream2,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? widget.onSend : null,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: widget.busy
                          ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: c.muted))
                          : Icon(widget.icon, color: canSend ? c.onPrimary : c.muted, size: 22),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }
}
