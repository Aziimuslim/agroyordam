import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

void showToast(BuildContext context, String msg) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center), duration: const Duration(milliseconds: 2200)));
}

/// Xatoni foydalanuvchiga ko'rsatadi; 402 bo'lsa Premium'ga yo'naltiradi.
void showError(BuildContext context, Object e) {
  final err = ApiException.from(e);
  showToast(context, err.message);
  if (err.isPaymentRequired) context.push('/premium');
}

List<BoxShadow> softShadow(BuildContext context, [double blur = 10, double y = 3]) =>
    [BoxShadow(color: context.c.shadow, blurRadius: blur, offset: Offset(0, y))];

/// Ekran qobig'i: krem fon, mobil kenglikda markazlashgan kontent (web'da ham telefon ko'rinishi).
class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.child, this.bottom, this.maxWidth = 480, this.padBottom = true, this.scroll = true, this.onRefresh});
  final Widget child;
  final Widget? bottom;
  final double maxWidth;
  final bool padBottom, scroll;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(20, 16, 20, padBottom ? 110 : 24);
    Widget body = scroll
        ? SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: pad, child: child)
        : Padding(padding: pad, child: child);
    if (onRefresh != null && scroll) {
      body = RefreshIndicator(color: context.c.primary, onRefresh: onRefresh!, child: body);
    }
    return Scaffold(
      backgroundColor: context.c.cream,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: body),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.subtitle, this.leading, this.actions = const [], this.showBack = true});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        if (showBack) ...[CircleIconButton(icon: AppIcons.back, onTap: () => context.canPop() ? context.pop() : context.go('/home'), tooltip: 'Orqaga'), const SizedBox(width: 12)],
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(fontSize: 12.5, color: context.c.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
        ...actions,
      ]),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.onTap, this.badge = false, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final bool badge;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final w = Material(
      color: context.c.card,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: softShadow(context, 6, 2)),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: 22, color: color ?? context.c.text),
            if (badge)
              Positioned(top: 7, right: 8, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: context.c.danger, shape: BoxShape.circle))),
          ]),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color, this.margin = const EdgeInsets.only(bottom: 14), this.radius = AppRadius.md, this.shadow = true, this.expand = true});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding, margin;
  final Color? color;
  final double radius;
  final bool shadow, expand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        width: expand ? double.infinity : null,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: shadow ? softShadow(context) : null),
        child: Material(
          color: color ?? context.c.card,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}

class ThumbIcon extends StatelessWidget {
  const ThumbIcon({super.key, required this.icon, this.size = 52, this.bg, this.fg, this.radius = 14, this.imageUrl});
  final IconData icon;
  final double size, radius;
  final Color? bg, fg;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.mediaUrl(imageUrl);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? context.c.tan, borderRadius: BorderRadius.circular(radius)),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(icon, color: fg ?? context.c.primaryDark))
          : Icon(icon, size: size * 0.46, color: fg ?? context.c.primaryDark),
    );
  }
}

class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.dark = false});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: onTap,
      color: dark ? c.dark : null,
      child: Row(children: [
        leading,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? c.card : c.text), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(fontSize: 12.5, color: dark ? c.onDarkMuted : c.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

enum PillStyle { light, dark, primary, outline, soft }

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.onPressed, this.icon, this.style = PillStyle.dark, this.block = false, this.loading = false, this.fg});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PillStyle style;
  final bool block, loading;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, color, border) = switch (style) {
      PillStyle.light => (c.card, c.primaryDark, null),
      PillStyle.dark => (c.dark, c.card, null),
      PillStyle.primary => (c.primary, c.card, null),
      PillStyle.outline => (Colors.transparent, fg ?? c.text, BorderSide(color: c.border, width: 1.5)),
      PillStyle.soft => (c.primaryLight, c.primaryDark, null),
    };
    final child = Row(
      mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
        else if (icon != null)
          Icon(icon, size: 20, color: fg ?? color),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: fg ?? color), overflow: TextOverflow.ellipsis)),
      ],
    );
    return SizedBox(
      width: block ? double.infinity : null,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: StadiumBorder(side: border ?? BorderSide.none),
        ),
        child: child,
      ),
    );
  }
}

class MiniButton extends StatelessWidget {
  const MiniButton({super.key, required this.label, this.onTap, this.filled = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: filled ? c.primary : c.primaryLight,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: filled ? c.card : c.primaryDark), const SizedBox(width: 5)],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: filled ? c.card : c.primaryDark)),
          ]),
        ),
      ),
    );
  }
}

class PctBadge extends StatelessWidget {
  const PctBadge(this.pct, {super.key, this.suffix = '', this.fontSize = 12.5});
  final int pct;
  final String suffix;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: c.healthBg(pct), borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text('$pct%$suffix', style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize, color: pct >= 45 && pct < 70 ? c.primaryDark : c.health(pct))),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.bg, this.fg});
  final String label;
  final Color? bg, fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg ?? context.c.primaryLight, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg ?? context.c.primaryDark)),
      );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44, this.color});
  final String name;
  final String? url;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final u = AppConfig.mediaUrl(url);
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final ini = parts.isEmpty ? '?' : (parts.length == 1 ? parts[0].substring(0, math.min(2, parts[0].length)) : parts[0][0] + parts[1][0]).toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color ?? context.c.avatarFor(name), shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: u != null
          ? Image.network(u, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, __, ___) => _ini(context, ini))
          : _ini(context, ini),
    );
  }

  Widget _ini(BuildContext context, String ini) =>
      Text(ini, style: TextStyle(color: context.c.card, fontWeight: FontWeight.w800, fontSize: size * 0.34));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (action != null)
            InkWell(
              onTap: onAction,
              child: Text(action!, style: TextStyle(fontSize: 12.5, color: context.c.primary, fontWeight: FontWeight.w700)),
            ),
        ]),
      );
}

class ChipTabs extends StatelessWidget {
  const ChipTabs({super.key, required this.tabs, required this.selected, required this.onSelect});
  final List<(String, String)> tabs; // (id, label)
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (id, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: selected == id ? c.primary : c.card,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelect(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected == id ? c.card : c.text)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
        child: Column(children: [
          if (icon != null) ...[Icon(icon, size: 36, color: context.c.muted), const SizedBox(height: 10)],
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.c.muted, fontSize: 13.5)),
        ]),
      );
}

/// AsyncValue uchun yagona yuklanish/xato ko'rinishi.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: context.c.muted),
          const SizedBox(height: 10),
          Text(ApiException.from(e).message, textAlign: TextAlign.center, style: TextStyle(color: context.c.muted)),
          if (onRetry != null) ...[const SizedBox(height: 12), PillButton(label: 'Qayta urinish', style: PillStyle.soft, onPressed: onRetry)],
        ]),
      ),
    );
  }
}

class HealthRing extends StatelessWidget {
  const HealthRing(this.pct, {super.key, this.size = 76});
  final int pct;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: pct / 100,
            strokeWidth: size * 0.12,
            backgroundColor: c.cream2,
            color: c.health(pct),
            strokeCap: StrokeCap.round,
          ),
        ),
        Text('$pct%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.24, color: c.primaryDark)),
      ]),
    );
  }
}

class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.icon, required this.label, this.value, this.onTap, this.danger = false, this.chevron = true});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger, chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      radius: 14,
      child: Row(children: [
        SizedBox(width: 36, child: Icon(icon, color: danger ? c.danger : c.primaryDark)),
        Expanded(child: Text(label, style: TextStyle(fontWeight: danger ? FontWeight.w800 : FontWeight.w700, fontSize: 14.5, color: danger ? c.danger : c.text))),
        if (value != null) Text(value!, style: TextStyle(color: c.muted, fontSize: 13)),
        if (chevron && !danger) Icon(AppIcons.chevron, color: c.muted),
      ]),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.c.muted)),
      );
}

class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: context.c.cream2, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: context.c.muted, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );
}

/// Pastki varaq (bottom sheet) sarlavhasi bilan.
Future<T?> showSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 28 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          builder(ctx),
        ]),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Ha', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Bekor qilish', style: TextStyle(color: context.c.muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: TextStyle(color: danger ? context.c.danger : context.c.primary, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return r ?? false;
}
