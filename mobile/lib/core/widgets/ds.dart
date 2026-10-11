import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// Yashil dala 2.0 komponentlari (docs/redesign). Holat hech qachon faqat rang bilan berilmaydi: ikonka + so'z.
enum StatusKind { healthy, risk, disease, info, expert, neutral, premium }

class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, required this.kind, this.icon});
  final String label;
  final StatusKind kind;
  final IconData? icon;

  static IconData _defaultIcon(StatusKind k) => switch (k) {
        StatusKind.healthy => Icons.check_rounded,
        StatusKind.risk => Icons.warning_amber_rounded,
        StatusKind.disease => Icons.cancel_outlined,
        StatusKind.info => Icons.info_outline_rounded,
        StatusKind.expert => Icons.verified_user_outlined,
        StatusKind.neutral => Icons.circle_outlined,
        StatusKind.premium => Icons.workspace_premium_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg) = switch (kind) {
      StatusKind.healthy => (c.successBg, c.success),
      StatusKind.risk => (c.warningBg, c.warning),
      StatusKind.disease => (c.dangerBg, c.danger),
      StatusKind.info => (c.infoBg, c.info),
      StatusKind.expert => (c.expertBg, c.expert),
      StatusKind.neutral => (c.cream2, c.muted),
      StatusKind.premium => (c.gold, c.onGold),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (kind != StatusKind.neutral || icon != null) ...[Icon(icon ?? _defaultIcon(kind), size: 15, color: fg), const SizedBox(width: 5)],
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg, height: 1)),
      ]),
    );
  }
}

/// Kasallik xavf darajasi belgisi.
class RiskTag extends StatelessWidget {
  const RiskTag(this.risk, {super.key});
  final String? risk;
  @override
  Widget build(BuildContext context) => switch (risk) {
        'high' => const StatusTag('Yuqori xavf', kind: StatusKind.disease),
        'low' => const StatusTag('Past xavf', kind: StatusKind.info),
        _ => const StatusTag("O'rta xavf", kind: StatusKind.risk),
      };
}

/// Rasm: ilova ichidagi asset (katalog), tarmoq URL yoki "rasm hali yo'q" o'rni.
class CatalogImage extends StatelessWidget {
  const CatalogImage({super.key, this.asset, this.url, this.width, this.height, this.radius = AppRadius.md, this.placeholderText});
  final String? asset, url;
  final double? width, height;
  final double radius;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final placeholder = Container(
      width: width,
      height: height,
      color: c.cream2,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.image_outlined, color: c.subtle, size: 22),
        if (placeholderText != null) ...[
          const SizedBox(height: 4),
          Text(placeholderText!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.subtle)),
        ],
      ]),
    );
    final Widget img = asset != null
        ? Image.asset(asset!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
        : url != null
            ? Image.network(url!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder)
            : placeholder;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: width, height: height, child: img));
  }
}

/// Segment tanlagich: bo'lim ichida ko'rinishni almashtirish (2–4 ta teng bo'lim).
class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.tabs, required this.selected, required this.onSelect, this.expert = false});
  final List<(String, String)> tabs;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool expert;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        for (final (id, label) in tabs)
          Expanded(
            child: Semantics(
              selected: selected == id,
              button: true,
              child: GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.standard,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == id ? c.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: selected == id ? [BoxShadow(color: c.shadow, blurRadius: 3, offset: const Offset(0, 1))] : null,
                  ),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected == id ? (expert ? c.expert : c.text) : c.muted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

enum NoteKind { info, risk, danger, expert }

/// Ekran ichidagi tushuntirish qutisi: ikonka, qalin sarlavha, oddiy matn.
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.title, this.text, this.kind = NoteKind.info, this.icon});
  final String title;
  final String? text;
  final NoteKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, ic) = switch (kind) {
      NoteKind.info => (c.infoBg, c.info, Icons.info_outline_rounded),
      NoteKind.risk => (c.warningBg, c.warning, Icons.warning_amber_rounded),
      NoteKind.danger => (c.dangerBg, c.danger, Icons.error_outline_rounded),
      NoteKind.expert => (c.expertBg, c.expert, Icons.verified_user_outlined),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? ic, color: fg, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15, height: 1.35)),
            if (text != null) ...[
              const SizedBox(height: 2),
              Text(text!, style: TextStyle(color: c.text, fontSize: 15, height: 1.45)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Matn bloki: sarlavha + o'qiladigan matn (body-lg).
class TextBlock extends StatelessWidget {
  const TextBlock(this.title, this.text, {super.key});
  final String title;
  final String? text;
  @override
  Widget build(BuildContext context) => text == null || text!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text!, style: const TextStyle(fontSize: 16.5, height: 1.55)),
          ]),
        );
}
