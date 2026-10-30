import 'package:agroyordam/core/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0.8.20: versiyalarni solishtirish va release JSON', () {
    expect(isNewerVersion('0.8.20', '0.8.19'), isTrue);
    expect(isNewerVersion('0.10.0', '0.9.9'), isTrue);
    expect(isNewerVersion('0.8.19', '0.8.19'), isFalse);
    expect(isNewerVersion('0.8.18', '0.8.19'), isFalse);
    expect(isNewerVersion('1.0.0+40', '0.9.0'), isTrue);

    final r = AppRelease.fromJson({'version': '0.8.20', 'apk_url': 'https://x/a.apk', 'size': 63470135, 'notes': '- yangi'})!;
    expect(r.size, 63470135);
    expect(formatMb(r.size!), '60,5 MB');
    expect(AppRelease.fromJson({'version': '0.8.20'}), isNull);
  });
}
