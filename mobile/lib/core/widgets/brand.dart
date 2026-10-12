import 'package:flutter/material.dart';

/// AgroYordam belgisi (assets/brand/logo-mark.png; manba — logo-mark.svg).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/brand/logo-mark.png', width: size, height: size, filterQuality: FilterQuality.medium, semanticLabel: 'AgroYordam');
}

/// Belgi + "AgroYordam" yozuvi (+ ixtiyoriy shior). Qorong'i fonda — oq "Agro", yashil "Yordam".
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 40, this.onDark = false, this.slogan = false});
  final double size;
  final bool onDark, slogan;
  @override
  Widget build(BuildContext context) {
    final agro = onDark ? Colors.white : const Color(0xFF0F2419);
    final yordam = onDark ? const Color(0xFFA3E553) : const Color(0xFF2E8B3A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: size),
        SizedBox(width: size * 0.25),
        // Tor ekranda (shior uzun) — sig'maganda kichrayadi, chetga chiqmaydi
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Agro',
                        style: TextStyle(color: agro),
                      ),
                      TextSpan(
                        text: 'Yordam',
                        style: TextStyle(color: yordam),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.1),
                ),
                if (slogan)
                  Text(
                    "QISHLOQ XO'JALIGI UCHUN AQLLI YECHIM",
                    style: TextStyle(
                      fontSize: size * 0.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: onDark ? Colors.white70 : const Color(0xFF55685D),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
