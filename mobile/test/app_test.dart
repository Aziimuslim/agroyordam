import 'package:agroyordam/app.dart';
import 'package:agroyordam/application/providers.dart';
import 'package:agroyordam/core/storage/token_storage.dart';
import 'package:agroyordam/core/theme/app_colors.dart';
import 'package:agroyordam/core/utils/format.dart';
import 'package:agroyordam/domain/entities/entities.dart';
import 'package:agroyordam/presentation/screens/reminders/today_tasks.dart';
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

  test("to'q sirtlardagi matn ikkala mavzuda ham o'qiladi (WCAG kontrast ≥ 4.5)", () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final c in [AppColors.light, AppColors.darkTheme]) {
      expect(contrast(c.dark, c.onDark), greaterThanOrEqualTo(4.5));
      expect(contrast(c.dark, c.onDarkMuted), greaterThanOrEqualTo(3));
      // to'q tugma sahifa fonidan ajralib turishi kerak
      expect(contrast(c.dark, c.cream), greaterThanOrEqualTo(1.4));
    }
  });

  test('CarePlan.fromJson va bugungi vazifalar', () {
    final plan = CarePlan.fromJson({
      'diagnosis_id': 'd1',
      'plant_name': 'Pomidor',
      'disease_name': 'Fitoftoroz',
      'confidence': '61.70',
      'duration_days': 21,
      'tasks': [
        {'day': 0, 'date': '2026-09-24', 'time': '08:00:00', 'title': 'Barglarni olib tashlang', 'reminder_type': 'treatment'},
      ],
    });
    expect(plan.confidence, 61.7);
    expect(plan.tasks.single.title, 'Barglarni olib tashlang');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Reminder r(String id, DateTime d, {bool done = false, String? crop}) =>
        Reminder(id: id, title: id, date: d, isCompleted: done, cropId: crop);
    final due = dueTasks([
      r('ertaga', today.add(const Duration(days: 1))),
      r('bugun', today, crop: 'c1'),
      r('kecha', today.subtract(const Duration(days: 1))),
      r('bajarilgan', today, done: true),
    ]);
    expect(due.map((e) => e.id), ['kecha', 'bugun']);
    expect(dueTasks([r('bugun', today, crop: 'c1'), r('x', today, crop: 'c2')], cropId: 'c1').single.id, 'bugun');
  });

  test('DatasetItem.fromJson', () {
    final it = DatasetItem.fromJson({
      'id': 'x',
      'image_url': '/media/diagnoses/a.jpg',
      'review_status': 'pending',
      'ai_label': 'Tomato_Late_blight',
      'confidence': 61.7,
      'user_feedback': false,
      'diagnosed_at': '2026-09-24T08:00:00',
    });
    expect(it.confidence, 61.7);
    expect(it.userFeedback, false);
    expect(it.verifiedLabel, isNull);
  });
}
