import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';

class DiagnosesHistoryScreen extends ConsumerWidget {
  const DiagnosesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      onRefresh: () async => ref.invalidate(diagnosesProvider),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TopBar(title: 'Tashxislar tarixi'),
        AsyncView(
          value: ref.watch(diagnosesProvider),
          onRetry: () => ref.invalidate(diagnosesProvider),
          data: (list) => list.isEmpty
              ? const EmptyNote("Hali tashxis qilinmagan", icon: AppIcons.camera)
              : Column(children: [
                  for (final d in list)
                    RowCard(
                      leading: ThumbIcon(icon: AppIcons.image, imageUrl: d.imageUrl),
                      title: d.title,
                      subtitle: '${d.plantName ?? ''}${d.plantName != null ? ' · ' : ''}${d.confidence.toStringAsFixed(0)}% · ${timeAgo(d.diagnosedAt)}',
                      trailing: Icon(AppIcons.chevron, color: c.muted),
                      onTap: () => context.push('/diagnosis/${d.id}'),
                    ),
                ]),
        ),
      ]),
    );
  }
}
