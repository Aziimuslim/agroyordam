import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/lang.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/lang_sheet.dart';
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
                Positioned(right: -18, top: 40, child: Opacity(opacity: 0.12, child: const BrandLogo(size: 150))),
                // Til tanlash — ro'yxatdan o'tishdan oldin ham
                Positioned(
                  right: 0,
                  top: 0,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => showLanguageSheet(context, ref),

                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          FlagIcon(ref.watch(langProvider), size: 24),
                          const SizedBox(width: 8),
                          Text(ref.watch(langProvider).short,
                              semanticsLabel: tr('Til'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        ]),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandWordmark(size: 46, onDark: true, slogan: true),
                    const SizedBox(height: 28),
                const Spacer(),
                    Text(
                      tr("Ekinlaringiz sog'lig'i — cho'ntagingizda"),
                      style: TextStyle(color: Colors.white, fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    for (final (icon, text) in [
                      (Icons.center_focus_strong_rounded, tr('AI bir necha soniyada kasallikni aniqlaydi')),
                      (Icons.event_available_outlined, tr("Kunlik parvarish va davolash rejasi")),
                      (Icons.people_outline_rounded, tr('Fermerlar jamoasi va tajriba almashish')),
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
          label: tr('Telefon raqami bilan davom etish'),
          icon: AppIcons.phone,
          style: PillStyle.primary,
          block: true,
          onPressed: () => context.push('/login?via=phone'),
        ),
        const _OrDivider(),
        PillButton(
          label: tr('Email bilan davom etish'),
          icon: AppIcons.mail,
          style: PillStyle.outline,
          block: true,
          onPressed: () => context.push('/login?via=email'),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            tr("Hisobingiz yo'qmi? Ro'yxatdan o'ting"),
            style: TextStyle(color: c.primary, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          tr('Davom etish orqali siz Foydalanish shartlari va Maxfiylik siyosatiga rozilik bildirasiz'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
        ),
        TextButton.icon(
          onPressed: () => showServerSettings(context, ref),
          icon: Icon(Icons.dns_outlined, size: 16, color: c.muted),
          label: Text(trf('Server: {0}', [AppConfig.apiUrl]), style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        Text(trf('Versiya {0}', [AppConfig.version]), style: TextStyle(color: c.muted, fontSize: 11)),
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
          child: Text(tr('yoki'), style: TextStyle(color: context.c.muted, fontSize: 12.5)),
        ),
        Expanded(child: Divider(color: context.c.border)),
      ],
    ),
  );
}
