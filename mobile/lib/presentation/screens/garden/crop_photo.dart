import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';

/// Ekin surati: foydalanuvchi yuklagan rasm → oxirgi tashxis rasmi → mavzu rangidagi o'rinbosar.
/// Rasm yuklanmasa ham o'rinbosar ko'rinadi (bo'sh joy qolmaydi).
class CropPhoto extends StatelessWidget {
  const CropPhoto({super.key, required this.crop, this.iconSize = 36});
  final Crop crop;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = AppConfig.mediaUrl(crop.photoUrl ?? crop.imageUrl);
    final placeholder = ColoredBox(
      color: c.oliveSoft,
      child: Center(child: Icon(Icons.eco_outlined, color: c.onOliveSoft, size: iconSize)),
    );
    if (url == null) return SizedBox.expand(child: placeholder);
    return SizedBox.expand(
      child: Image.network(
        url,
        fit: BoxFit.cover,
        semanticLabel: crop.name,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (_, child, p) => p == null ? child : placeholder,
      ),
    );
  }
}
