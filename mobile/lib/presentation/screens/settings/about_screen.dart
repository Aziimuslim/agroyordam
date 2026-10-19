import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers.dart';
import '../../../core/config.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/widgets.dart';
import '../auth/server_settings.dart';
import 'settings_widgets.dart';

/// A05 Ilova haqida: versiya, yordam, ma'lumot manbalari, maxfiylik bo'yicha qisqa qoidalar.
/// Rasmiy "Foydalanish shartlari" va "Maxfiylik siyosati" hujjatlari hali tasdiqlanmagan — shuni ochiq aytamiz.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    Widget para(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c.olive, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(t, style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
          ),
        ],
      ),
    );
    return PageShell(
      maxWidth: 640,
      padBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBar(title: tr('Ilova haqida')),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: c.oliveSoft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(AppIcons.leaf, color: c.olive),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text),
                      ),
                      Text(trf('Versiya {0}', [AppConfig.version]), style: TextStyle(fontSize: 14, color: c.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SettingsSection(tr('Yordam')),
          if (ref.watch(currentUserProvider) != null)
          ListRow(icon: Icons.support_agent_rounded, label: tr('Agronomga savol berish'), onTap: () => context.push('/help/ask')),
          ListRow(icon: AppIcons.book, label: tr("Ma'lumotnoma"), value: tr("O'simlik, kasallik, dori"), onTap: () => context.push('/catalog')),
          SettingsSection(tr("Ma'lumot manbalari")),
          para(tr("AI tashxis — taxmin. Muhim qarordan oldin agronom bilan maslahatlashing.")),
          para(tr("Kasallik va dori ma'lumotlarini agronomlar tekshiradi. Dori me'yori faqat yorliq bo'yicha tasdiqlangan bo'lsa ko'rsatiladi.")),
          para(tr("Ob-havo: Open-Meteo (open-meteo.com) ma'lumotlari, serverda qisqa muddat saqlanadi.")),
          SettingsSection(tr('Maxfiylik')),
          para(tr("Ommaviy profilda faqat ism, foydalanuvchi nomi, hudud va o'zingiz haqida yozganingiz ko'rinadi. Telefon, email va aniq manzil ko'rsatilmaydi.")),
          para(tr("Siz yuborgan ekin rasmlari tashxis va tarix uchun serverda saqlanadi. Agronom tasdiqlagan rasmlar AI modelini yaxshilash uchun o'quv to'plamiga qo'shilishi mumkin.")),
          para(tr("Hisobdan chiqqanda shu qurilmadagi shaxsiy ma'lumotlar tozalanadi; mavzu va til tanlovi qoladi.")),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.cream2, borderRadius: BorderRadius.circular(12)),
            child: Text(
              tr("Rasmiy «Foydalanish shartlari» va «Maxfiylik siyosati» hujjatlari tayyorlanmoqda. Ular e'lon qilinganda shu yerda versiya va sana bilan chiqadi."),
              style: TextStyle(fontSize: 14, color: c.muted, height: 1.4),
            ),
          ),
          if (AppConfig.showServerSettings) ...[
            SettingsSection(tr('Ishlab chiquvchi uchun')),
            ListRow(icon: Icons.dns_outlined, label: tr('Server manzili'), value: AppConfig.apiUrl, onTap: () => showServerSettings(context, ref)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
