import 'package:flutter/material.dart';

/// Chiziqli (outlined) ikonlar. Emoji UI elementi sifatida ishlatilmaydi.
class AppIcons {
  static const home = Icons.home_outlined;
  static const leaf = Icons.eco_outlined;
  static const bell = Icons.notifications_none_rounded;
  static const sliders = Icons.tune_rounded;
  static const camera = Icons.photo_camera_outlined;
  static const back = Icons.chevron_left_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const check = Icons.check_rounded;
  static const chat = Icons.chat_bubble_outline_rounded;
  static const heart = Icons.favorite_border_rounded;
  static const heartFill = Icons.favorite_rounded;
  static const eye = Icons.visibility_outlined;
  static const clock = Icons.schedule_rounded;
  static const plus = Icons.add_rounded;
  static const send = Icons.send_rounded;
  static const star = Icons.star_rounded;
  static const card = Icons.credit_card_rounded;
  static const globe = Icons.language_rounded;
  static const logout = Icons.logout_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const bug = Icons.bug_report_outlined;
  static const pill = Icons.medication_outlined;
  static const mail = Icons.mail_outline_rounded;
  static const phone = Icons.phone_outlined;
  static const sparkle = Icons.auto_awesome_rounded;
  static const plant = Icons.spa_outlined;
  static const virus = Icons.coronavirus_outlined;
  static const image = Icons.image_outlined;
  static const water = Icons.water_drop_outlined;
  static const shield = Icons.admin_panel_settings_outlined;
  static const user = Icons.person_outline_rounded;
  static const chart = Icons.insights_rounded;
  static const flag = Icons.outlined_flag_rounded;
  static const edit = Icons.edit_outlined;
  static const book = Icons.menu_book_outlined;
  static const history = Icons.history_rounded;
  static const lock = Icons.lock_outline_rounded;
  static const bot = Icons.smart_toy_outlined;

  /// Ekin turi bo'yicha ikon.
  static IconData forPlant(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('uzum')) return Icons.bubble_chart_outlined;
    if (n.contains('olma')) return Icons.apple;
    if (n.contains('kartoshka')) return Icons.circle_outlined;
    if (n.contains('bodring')) return Icons.grass_rounded;
    if (n.contains('qalampir')) return Icons.local_fire_department_outlined;
    if (n.contains('pomidor')) return Icons.brightness_1_outlined;
    if (n.contains('makkajo')) return Icons.grain_rounded;
    if (n.contains('shaftoli') || n.contains('olcha')) return Icons.park_outlined;
    if (n.contains('qulupnay')) return Icons.favorite_outline_rounded;
    if (n.contains('qovoq')) return Icons.circle_outlined;
    return Icons.spa_outlined;
  }

  static IconData forReminder(String? type) => switch (type) {
        'watering' => water,
        'treatment' => pill,
        'fertilizing' => Icons.science_outlined,
        'recheck' => camera,
        _ => leaf,
      };
}
