import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_icons.dart';
import '../../../domain/entities/entities.dart';

/// Ekin surati: oxirgi tashxis rasmi, bo'lmasa — yashil gradient (Figma: "photo/…" o'rinbosari).
class CropPhoto extends StatelessWidget {
  const CropPhoto({super.key, required this.crop, this.iconSize = 36});
  final Crop crop;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.mediaUrl(crop.imageUrl);
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF3B5B24), Color(0xFF6E8B3D), Color(0xFF9DB35A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(child: Icon(AppIcons.leaf, color: Colors.white.withValues(alpha: 0.7), size: iconSize)),
    );
    if (url == null) return SizedBox.expand(child: placeholder);
    return SizedBox.expand(child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder));
  }
}
