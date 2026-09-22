import 'package:agroyordam/app.dart';
import 'package:agroyordam/application/providers.dart';
import 'package:agroyordam/core/storage/token_storage.dart';
import 'package:agroyordam/core/theme/app_colors.dart';
import 'package:agroyordam/core/utils/format.dart';
import 'package:agroyordam/domain/entities/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app() => ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(MemoryTokenStorage())],
      retry: (_, __) => null,
      child: const AgroYordamApp(),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('format', () {
    test('initials', () {
      expect(initials('Aziz Karimov'), 'AK');
      expect(initials('dilnoza'), 'DI');
      expect(initials(''), '?');
    });
    test('greeting', () {
      expect(greeting(DateTime(2026, 1, 1, 8)), 'Xayrli tong!');
      expect(greeting(DateTime(2026, 1, 1, 13)), 'Xayrli kun!');
      expect(greeting(DateTime(2026, 1, 1, 21)), 'Xayrli kech!');
    });
    test('money', () => expect(formatMoney(25000), "25 000 so'm"));
    test('backend UTC vaqti', () => expect(parseDate('2026-09-22T10:00:00')!.isUtc, isTrue));
  });

  test('Diagnosis.fromJson', () {
    final d = Diagnosis.fromJson({
      'id': '1',
      'image_url': '/media/x.jpg',
      'disease_name': 'Fitoftoroz',
      'confidence': '91.50',
      'risk_level': 'high',
      'medicines': [
        {'id': 'm', 'name': 'Mis oksixlorid', 'recommendation': '40 g / 10 l'}
      ],
    });
    expect(d.confidence, 91.5);
    expect(d.title, 'Fitoftoroz');
    expect(d.medicines.single.recommendation, '40 g / 10 l');
  });

  test("sog'liq ranglari semantik", () {
    const c = AppColors.light;
    expect(c.health(90), c.success);
    expect(c.health(50), c.gold);
    expect(c.health(20), c.danger);
  });

  testWidgets('tizimga kirmagan foydalanuvchi Welcome ekranini ko\'radi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Xush kelibsiz!'), findsOneWidget);
    expect(find.text('Email bilan davom etish'), findsOneWidget);
  });

  testWidgets('login formasi validatsiyasi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email bilan davom etish'));
    await tester.pumpAndSettle();
    expect(find.text('Hisobingizga kiring'), findsOneWidget);
    await tester.tap(find.text('Kirish'));
    await tester.pumpAndSettle();
    expect(find.text("Maydonni to'ldiring"), findsOneWidget);
    expect(find.text('Parolni kiriting'), findsOneWidget);
  });
}
