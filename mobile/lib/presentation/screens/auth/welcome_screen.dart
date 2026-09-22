import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
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
          // Kichik ekranlarda ham sig'adi: kamida 700px balandlik, ortig'i scroll bo'ladi
          child: SizedBox(height: box.maxHeight < 700 ? 700 : box.maxHeight, child: _content(context, ref, c)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, AppColors c) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: Icon(AppIcons.leaf, color: c.card, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AGROYORDAM',
                    style: TextStyle(fontSize: 15, letterSpacing: 2.1, color: c.primary, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 22),
                  const Text('Xush kelibsiz!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      'Ekinlaringiz salomatligini bir necha soniyada bilib oling',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted, fontSize: 14.5, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        PillButton(
          label: 'Email bilan davom etish',
          icon: AppIcons.mail,
          style: PillStyle.outline,
          block: true,
          onPressed: () => context.push('/login?via=email'),
        ),
        const _OrDivider(),
        PillButton(
          label: 'Telefon raqami bilan davom etish',
          icon: AppIcons.phone,
          block: true,
          onPressed: () => context.push('/login?via=phone'),
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
