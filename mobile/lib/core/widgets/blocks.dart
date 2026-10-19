import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'widgets.dart';

/// Tabiiy Agro bloklari: sarlavha + "Barchasini ko'rish", blok ichidagi xato (qisman API xatosi
/// faqat o'z blokida — TZ S01), skeleton.
class BlockTitle extends StatelessWidget {
  const BlockTitle(this.title, {super.key, this.trailing, this.action, this.onAction});
  final String title;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Sig'masa amal keyingi qatorga o'tadi — sarlavha harfma-harf bo'linmaydi (QA14: 200% matn)
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
          Semantics(header: true, child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text))),
          if (trailing != null) trailing!,
        ]),
        if (action != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 8)),
            onPressed: onAction,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Icon(AppIcons.chevron, size: 20),
            ]),
          ),
      ]),
    );
  }
}

class BlockError extends StatelessWidget {
  const BlockError({super.key, required this.error, required this.onRetry, required this.what});
  final Object error;
  final VoidCallback onRetry;
  final String what;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, color: c.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trf("{0} yuklanmadi", [what]), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
            Text(ApiException.from(error).message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 14)),
          ]),
        ),
        TextButton(onPressed: onRetry, child: Text(tr('Qayta urinish'))),
      ]),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: context.c.cream2, borderRadius: BorderRadius.circular(16)),
      );
}

