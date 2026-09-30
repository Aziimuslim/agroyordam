import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config.dart';
import '../../../core/widgets/widgets.dart';
import 'server_settings.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return PageShell(
      padBottom: false,
      scroll: false,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          // Ekran balandligini to'ldiradi; kontent sig'masa (kichik ekran, katta shrift) — scroll bo'ladi
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(child: _content(context, ref, c)),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, AppColors c) {
    return Column(
      children: [
        // Figma "Yashil dala": yashil gradient panel, belgi, sarlavha va 3 ta asosiy imkoniyat
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F3D27), Color(0xFF2E8B57)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Stack(
              children: [
                Positioned(right: -6, top: 44, child: Icon(AppIcons.scan, size: 120, color: Colors.white.withValues(alpha: 0.14))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(12)),
                          child: Icon(AppIcons.leaf, color: c.onGold, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AgroYordam',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                const Spacer(),
                    const Text(
                      "Ekinlaringiz sog'lig'i — cho'ntagingizda",
                      style: TextStyle(color: Colors.white, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    for (final (icon, text) in const [
                      (Icons.center_focus_strong_rounded, 'AI bir necha soniyada kasallikni aniqlaydi'),
                      (Icons.event_available_outlined, "Kunlik parvarish va davolash rejasi"),
                      (Icons.people_outline_rounded, 'Fermerlar jamoasi va tajriba almashish'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
                              child: Icon(icon, color: Colors.white, size: 17),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        PillButton(
          label: 'Telefon raqami bilan davom etish',
          icon: AppIcons.phone,
          style: PillStyle.primary,
          block: true,
          onPressed: () => context.push('/login?via=phone'),
        ),
        const _OrDivider(),
        PillButton(
          label: 'Email bilan davom etish',
          icon: AppIcons.mail,
          style: PillStyle.outline,
          block: true,
          onPressed: () => context.push('/login?via=email'),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            "Hisobingiz yo'qmi? Ro'yxatdan o'ting",
            style: TextStyle(color: c.primary, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          'Davom etish orqali siz Foydalanish shartlari va Maxfiylik siyosatiga rozilik bildirasiz',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
        ),
        TextButton.icon(
          onPressed: () => showServerSettings(context, ref),
          icon: Icon(Icons.dns_outlined, size: 16, color: c.muted),
          label: Text('Server: ${AppConfig.apiUrl}', style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        Text('Versiya ${AppConfig.version}', style: TextStyle(color: c.muted, fontSize: 11)),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        Expanded(child: Divider(color: context.c.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('yoki', style: TextStyle(color: context.c.muted, fontSize: 12.5)),
        ),
        Expanded(child: Divider(color: context.c.border)),
      ],
    ),
  );
}
