import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

/// A02 "Saqlash" tugmasi: bosilganda darhol o'zgaradi (optimistik), server xato bersa avvalgi holatga qaytadi.
class BookmarkButton extends ConsumerStatefulWidget {
  const BookmarkButton({super.key, required this.kind, required this.targetId, this.color});
  final String kind, targetId;
  final Color? color;
  @override
  ConsumerState<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<BookmarkButton> {
  bool? _local;
  bool _busy = false;

  Future<void> _toggle(bool current) async {
    if (_busy) return;
    final next = !current;
    setState(() {
      _local = next;
      _busy = true;
    });
    try {
      final repo = ref.read(communityRepoProvider);
      next ? await repo.addBookmark(widget.kind, widget.targetId) : await repo.removeBookmark(widget.kind, widget.targetId);
      ref.invalidate(bookmarksProvider);
      if (mounted) showToast(context, next ? tr('Saqlanganlarga qo\'shildi') : tr('Saqlanganlardan olib tashlandi'));
    } catch (e) {
      if (mounted) {
        setState(() => _local = current);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(bookmarksProvider).value;
    final server = list?.any((b) => b.kind == widget.kind && b.targetId == widget.targetId) ?? false;
    final saved = _local ?? server;
    if (!_busy && _local != null && list != null && _local == server) _local = null;
    return IconButton(
      tooltip: saved ? tr('Saqlanganlardan olib tashlash') : tr('Saqlash'),
      isSelected: saved,
      onPressed: list == null ? null : () => _toggle(saved),
      icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: saved ? context.c.olive : (widget.color ?? context.c.text)),
    );
  }
}
