import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../i18n/i18n.dart';
import 'widgets.dart';

/// Telefon "Orqaga" tugmasi bo'lim ildizida: boshqa bo'limda — bosh bo'limga; bosh bo'limda — 2 soniya ichida ikkinchi
/// bosishda ilovadan chiqish (tasodifan yopilmasin). Web'da brauzer tarixi o'zgarishsiz ishlaydi.
class TabBackGuard extends StatefulWidget {
  const TabBackGuard({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _homes = {'/home', '/expert'};

  @override
  State<TabBackGuard> createState() => _TabBackGuardState();
}

class _TabBackGuardState extends State<TabBackGuard> {
  DateTime? _lastBack;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!TabBackGuard._homes.contains(widget.location)) {
          context.go(widget.location.startsWith('/expert') ? '/expert' : '/home');
          return;
        }
        final now = DateTime.now();
        if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        showToast(context, tr('Chiqish uchun yana bir marta bosing'));
      },
      child: widget.child,
    );
  }
}
