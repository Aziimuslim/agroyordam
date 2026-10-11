import 'package:agroyordam/app.dart';
import 'package:agroyordam/application/providers.dart';
import 'package:agroyordam/core/catalog_images.dart';
import 'package:agroyordam/core/storage/token_storage.dart';
import 'package:agroyordam/core/theme/app_colors.dart';
import 'package:agroyordam/core/utils/format.dart';
import 'package:agroyordam/domain/entities/entities.dart';
import 'package:agroyordam/presentation/screens/expert/expert_shell.dart';
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
    expect(c.health(50), c.warning); // oq fonda o'qilishi uchun sariq emas, to'q sariq
    expect(c.health(20), c.danger);
  });

  testWidgets('tizimga kirmagan foydalanuvchi Welcome ekranini ko\'radi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text("Ekinlaringiz sog'lig'i — cho'ntagingizda"), findsOneWidget);
    expect(find.text('Email bilan davom etish'), findsOneWidget);
  });

  testWidgets('login formasi validatsiyasi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Email bilan davom etish')); // kichik ekranda pastda — scroll
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
      // Yashil dala 2.0: agronom rangi va holat ranglari o'z fonlarida o'qiladi
      expect(contrast(c.expert, c.onExpert), greaterThanOrEqualTo(4.5));
      expect(contrast(c.expert, c.expertBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.warning, c.warningBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.danger, c.dangerBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.success, c.successBg), greaterThanOrEqualTo(4.5));
      expect(contrast(c.text, c.card), greaterThanOrEqualTo(4.5));
      expect(contrast(c.muted, c.cream), greaterThanOrEqualTo(4.5));
      // asosiy tugma: c.card yozuvi c.primary ustida
      expect(contrast(c.primary, c.card), greaterThanOrEqualTo(4.5));
      // kiritish maydoni chegarasi sirtda 3:1
      expect(contrast(c.lineStrong, c.card), greaterThanOrEqualTo(3));
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

  test('Katalog rasmlari: kasallik va ekin', () {
    expect(CatalogImages.disease('Tomato_Late_blight'), 'assets/catalog/Tomato_Late_blight.jpg');
    expect(CatalogImages.disease('Cucumber_Powdery_mildew'), isNull); // datasetda yo'q
    expect(CatalogImages.disease(null), isNull);
    expect(CatalogImages.plant('Pomidor'), 'assets/catalog/Tomato_healthy.jpg');
    expect(CatalogImages.plant("Makkajo'xori"), 'assets/catalog/Corn_healthy.jpg');
    expect(CatalogImages.plant('Bodring'), isNull);
  });

  test('Savol, agronom va ariza JSON', () {
    final author = {'id': 'u1', 'full_name': 'Akmal To\'xtayev', 'username': 'akmal', 'role': 'user'};
    final expert = {'id': 'e1', 'full_name': 'Dilnoza Karimova', 'username': 'dilnoza', 'role': 'agronomist'};
    final q = Question.fromJson({
      'id': 'q1', 'author': author, 'expert': expert, 'title': "Barglarda dog'lar", 'status': 'answered',
      'diagnosis_id': 'd1', 'diagnosis_name': 'Fitoftoroz', 'diagnosis_confidence': 64.0, 'messages_count': 1,
      'messages': [
        {'id': 'm1', 'sender': expert, 'body': 'Fitoftoroz.', 'medicine': {'id': 'x', 'name': 'Mis oksixlorid', 'usage': '40 g / 10 l'}},
      ],
    });
    expect(q.expert!.isExpert, isTrue);
    expect(q.author.isExpert, isFalse);
    expect(q.messages.single.medicineName, 'Mis oksixlorid');
    expect(q.diagnosisConfidence, 64);

    final quota = QuestionQuota.fromJson({'used': 1, 'limit': 2, 'remaining': 1});
    expect(quota.unlimited, isFalse);
    expect(QuestionQuota.fromJson({'used': 5, 'limit': null, 'remaining': null}).unlimited, isTrue);

    final e = Expert.fromJson({'id': 'e1', 'full_name': 'Dilnoza', 'answers': 3, 'rating': 4.8, 'accepting_questions': false});
    expect(e.rating, 4.8);
    expect(e.acceptingQuestions, isFalse);
    expect(ExpertApplication.fromJson({'id': 'a', 'status': 'pending', 'specialization': 'Bog\'lar'}).pending, isTrue);
  });

  test('Tashxis: agronom tekshiruvi maydonlari', () {
    final d = Diagnosis.fromJson({
      'id': 'd1', 'image_url': '/media/x.jpg', 'confidence': '54.0', 'low_confidence': false,
      'ai_label': 'Tomato_Late_blight', 'disease_label': 'Tomato_Early_blight',
      'review_status': 'corrected', 'review_requested': true, 'expert_comment': 'Bu alternarioz',
    });
    expect(d.expertChecked, isTrue);
    expect(d.canAskExpert, isFalse);
    expect(d.diseaseLabel, 'Tomato_Early_blight');
    expect(Diagnosis.fromJson({'id': 'd2', 'image_url': '/m.jpg'}).canAskExpert, isTrue);
  });

  test('Agronom rejimi: navbat, statistika, rol', () {
    final i = QueueItem.fromJson({
      'id': 'q1', 'image_url': '/m.jpg', 'farmer_name': 'Jasur', 'ai_label': 'Grape_healthy', 'confidence': 61.5,
      'review_requested': true,
      'alternatives': [
        {'label': 'Grape_healthy', 'confidence': 61.5, 'disease_name': "Sog'lom", 'healthy': true},
        {'label': 'Grape_Black_rot', 'confidence': 30, 'disease_id': 'x', 'disease_name': 'Uzum qora chirishi'},
      ],
    });
    expect(i.title, "Sog'lom");
    expect(i.lowConfidence, isTrue);
    expect(i.alternatives.length, 2);
    expect(i.alternatives.first.healthy, isTrue);
    expect(i.alternatives.last.confidence, 30.0);

    final s = ExpertStats.fromJson({'reviewed_today': 3, 'ai_agreement': 87, 'avg_answer_minutes': 125, 'rating': 4.8, 'ratings_count': 12});
    expect(s.reviewedToday, 3);
    expect(s.rating, 4.8);
    expect(formatWait(s.avgAnswerMinutes), '2 soat');
    expect(formatWait(35), '35 daq');
    expect(formatWait(null), '—');

    AppUser u(String role) => AppUser.fromJson({'id': 'u', 'full_name': 'A', 'username': 'a', 'role': role, 'work_hours': '9–18'});
    expect(u('agronomist').canReview, isTrue);
    expect(u('admin').canReview, isTrue);
    expect(u('user').canReview, isFalse);
    expect(u('user').workHours, '9–18');
  });
}
