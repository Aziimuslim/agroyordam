import 'package:agroyordam/app.dart';
import 'package:agroyordam/application/display_prefs.dart';
import 'package:agroyordam/application/providers.dart';
import 'package:agroyordam/core/catalog_images.dart';
import 'package:agroyordam/core/data/farm_options.dart';
import 'package:agroyordam/core/data/uz_regions.dart';
import 'package:agroyordam/core/i18n/i18n.dart';
import 'package:agroyordam/core/i18n/translit.dart';
import 'package:agroyordam/core/storage/token_storage.dart';
import 'package:agroyordam/core/theme/app_colors.dart';
import 'package:agroyordam/core/utils/format.dart';
import 'package:agroyordam/core/widgets/photos.dart';
import 'package:agroyordam/domain/entities/entities.dart';
import 'package:agroyordam/presentation/router.dart';
import 'package:agroyordam/presentation/screens/auth/auth_widgets.dart';
import 'package:agroyordam/presentation/screens/chat/chat_widgets.dart';
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
    expect(find.text('Email yoki foydalanuvchi nomini kiriting'), findsOneWidget);
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
      // asosiy tugma: c.onPrimary yozuvi c.primary ustida; tanlangan tab — olive
      expect(contrast(c.primary, c.onPrimary), greaterThanOrEqualTo(4.5));
      expect(contrast(c.olive, c.onOlive), greaterThanOrEqualTo(4.5));
      expect(contrast(c.onOliveSoft, c.oliveSoft), greaterThanOrEqualTo(4.5));
      // terrakota havola/ikonka sahifa fonida
      expect(contrast(c.primary, c.cream), greaterThanOrEqualTo(4.5));
      expect(contrast(c.muted, c.cream2), greaterThanOrEqualTo(4.5));
      expect(contrast(c.focus, c.cream), greaterThanOrEqualTo(3));
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

  test("Profil: xo'jalik, agronom ma'lumotlari, hududlar", () {
    final u = AppUser.fromJson({
      'id': '1', 'full_name': 'Ali', 'username': 'ali', 'region': "Qoraqalpog'iston", 'district': 'Amudaryo tumani',
      'farm_type': 'fermer', 'farm_area': 3, 'main_crops': ['Paxta', "Bug'doy"], 'irrigation': 'tomchi', 'experience_years': 12,
    });
    expect(u.hasFarmInfo, isTrue);
    expect(u.mainCrops, ['Paxta', "Bug'doy"]);
    expect(u.farmArea, 3.0);
    expect(AppUser.fromJson({'id': '2', 'full_name': 'B', 'username': 'b'}).hasFarmInfo, isFalse);
    expect(placeText(u.region, u.district), "Qoraqalpog'iston, Amudaryo tumani");
    expect(placeText(null, null), '');
    expect(formatArea(0.12), '12 sotix');
    expect(formatArea(2.5), '2.5 gektar');
    expect(formatArea(3), '3 gektar');
    // Ro'yxatdagi barcha viloyatlarda tumanlar bor, takrorlanmaydi
    for (final e in uzRegions.entries) {
      expect(e.value, isNotEmpty, reason: e.key);
      expect(e.value.toSet().length, e.value.length, reason: e.key);
    }
    final q = Question.fromJson({
      'id': 'q', 'title': 'T', 'status': 'new', 'author': {'id': '1', 'full_name': 'Ali', 'username': 'ali'},
      'author_farm': {'farm_type': 'tomorqa', 'farm_area': 0.08, 'main_crops': ['Pomidor']},
    });
    expect(q.authorFarm!.isEmpty, isFalse);
    expect(farmTypes[q.authorFarm!.farmType], 'Tomorqa');
    final e = Expert.fromJson({'id': 'e', 'full_name': 'Agro', 'skills': ['Uzum'], 'experience_years': 15, 'ratings_count': 4});
    expect(e.skills, ['Uzum']);
    expect(e.ratingsCount, 4);
  });

  test('Tillar: tarjima, kirill transliteratsiyasi, o\'rinbosarlar', () {
    addTearDown(() => I18n.lang = AppLang.uz);
    expect(toCyrillic("Qo'shimcha ma'lumotlar"), 'Қўшимча маълумотлар');
    expect(toCyrillic("Yo'q, yangi ekin"), 'Йўқ, янги экин');
    expect(toCyrillic('SHAXSIY'), 'ШАХСИЙ');
    expect(toCyrillic("Sug'orish · {0} kun"), 'Суғориш · {0} кун');
    expect(toCyrillic("AgroYordam AI Premium'ga"), 'AgroYordam AI Премиумга');
    expect(toCyrillic('iyun, Seshanba'), 'июн, Сешанба');

    I18n.lang = AppLang.uz;
    expect(trf('{0} kun oldin', [3]), '3 kun oldin');
    I18n.lang = AppLang.uzCyrl;
    expect(trf('{0} kun oldin', [3]), '3 кун олдин');
    I18n.lang = AppLang.ru;
    expect(tr('Saqlash'), 'Сохранить');
    expect(trf('{0} kun oldin', [3]), '3 дн. назад');
    expect(tr('Lug\'atda yo\'q matn'), "Lug'atda yo'q matn"); // topilmasa manba qaytadi
    I18n.lang = AppLang.en;
    expect(tr('Saqlash'), 'Save');
    I18n.lang = AppLang.kaa;
    expect(tr('Saqlash'), 'Saqlaw');
    expect(AppLang.fromCode('uz-Cyrl'), AppLang.uzCyrl);
    expect(AppLang.fromCode('xx'), AppLang.uz);
  });

  test("To'lov holati va tilni oldindan ko'rish", () {
    final paid = Subscription.fromJson({'id': 'a', 'plan': 'monthly', 'status': 'cancelled', 'paid_at': '2026-10-01T10:00:00', 'payment_status': 'paid'});
    expect(paid.paymentStatus, 'paid'); // avto-yangilanish o'chirilgan, lekin to'langan
    final failed = Subscription.fromJson({'id': 'b', 'plan': 'monthly', 'status': 'cancelled'});
    expect(failed.paymentStatus, 'failed'); // eski server: to'lov vaqti yo'q
    final pending = Subscription.fromJson({'id': 'c', 'plan': 'yearly', 'status': 'pending'});
    expect(pending.paymentStatus, 'pending');
    expect(pending.autoRenew, false);

    expect(I18n.lang, AppLang.uz);
    expect(trIn(AppLang.ru, 'Saqlash'), 'Сохранить');
    expect(trIn(AppLang.en, 'Saqlash'), 'Save');
    expect(trIn(AppLang.uzCyrl, 'Saqlash'), 'Сақлаш');
    expect(tr('Saqlash'), 'Saqlash'); // global til o'zgarmadi
  });

  test('Kirish: telefon E.164 va xavfsiz returnTo', () {
    expect(normalizePhone('90 123 45 67'), '+998901234567');
    expect(normalizePhone('998901234567'), '+998901234567');
    expect(normalizePhone('+7 912 345-67-89'), '+79123456789');
    expect(normalizePhone('12345'), isNull);
    expect(validEmail('a@b.uz'), isTrue);
    expect(validEmail('a@b'), isFalse);

    expect(safeReturnTo('/garden/1?tab=care'), '/garden/1?tab=care');
    expect(safeReturnTo('//evil.com'), isNull);
    expect(safeReturnTo('https://evil.com'), isNull);
    expect(safeReturnTo('/auth/login'), isNull);
    expect(safeReturnTo('/splash'), isNull);
    expect(safeReturnTo(null), isNull);
  });

  test('AuthOptions: kanal yo\'q bo\'lsa kodli oqim yopiq', () {
    final none = AuthOptions.fromJson({'channels': [], 'dev_codes': false, 'terms_version': 'v1'});
    expect(none.any, isFalse);
    final dev = AuthOptions.fromJson({'channels': ['sms', 'email'], 'dev_codes': true});
    expect(dev.sms && dev.email, isTrue);
    final ch = Challenge.fromJson({'challenge_id': 'x', 'purpose': 'register', 'channel': 'sms', 'destination_masked': '+998 ••• •• 33', 'expires_in': 300, 'resend_in': 60, 'attempts_left': 5});
    expect(ch.devCode, isNull);
  });

  test('Ob-havo prognozi: soatlik va kunlik', () {
    final w = Weather.fromJson({
      'city': 'Namangan', 'temperature': 21, 'humidity': 50, 'condition': 'ochiq osmon', 'risk': 'low', 'risk_text': '',
      'hourly': [
        {'time': '2026-10-20T14:00', 'temperature': 21.4, 'code': 0, 'rain_probability': 5, 'is_day': true},
      ],
      'daily': [
        {'date': '2026-10-21', 't_max': 22, 't_min': 8, 'code': 61, 'condition': "yomg'ir", 'rain_mm': 2.5, 'rain_probability': 80},
      ],
    });
    expect(w.hourly.single.time.hour, 14);
    expect(w.daily.single.rainProbability, 80);
    final old = Weather.fromJson({'city': 'X', 'temperature': 1, 'humidity': 1, 'condition': '', 'risk': 'low', 'risk_text': ''});
    expect(old.hourly, isEmpty); // eski server — prognoz yo'q
  });

  test('DM08: Tabiiy Agro token juftliklari kontrasti (ikkala mavzu)', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
    }

    for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.darkTheme)]) {
      final pairs = <(String, Color, Color, double)>[
        ('text/cream', c.text, c.cream, 4.5),
        ('text/card', c.text, c.card, 4.5),
        ('muted/cream', c.muted, c.cream, 4.5),
        ('muted/card', c.muted, c.card, 4.5),
        ('onPrimary/primary', c.onPrimary, c.primary, 4.5),
        ('primaryDark/cream', c.primaryDark, c.cream, 4.5),
        ('onOlive/olive', c.onOlive, c.olive, 4.5),
        ('onOliveSoft/oliveSoft', c.onOliveSoft, c.oliveSoft, 4.5),
        ('danger/card', c.danger, c.card, 4.5),
        ('lineStrong/card', c.lineStrong, c.card, 3), // forma chegarasi — 3:1
      ];
      for (final (label, fg, bg, min) in pairs) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(min), reason: '$name $label = ${contrast(fg, bg).toStringAsFixed(2)}');
      }
    }
  });

  test('QA14: nochiziqli matn shkalasi — oddiy matn 200%, yirik sarlavha kamroq', () {
    const s = NonlinearTextScaler(2);
    expect(s.scale(14), 28); // oddiy matn to'liq
    expect(s.scale(16), 32);
    expect(s.scale(32), closeTo(48, 0.01)); // 1.5x
    expect(s.scale(30) / 30, lessThan(1.6));
    expect(const NonlinearTextScaler(1).scale(20), 20);
  });

  test('0.8.11: post/izoh/xabar JSON — rasmlar ro\'yxati, javob, o\'chirilgan izoh, yetkazildi', () {
    final author = {'id': 'u', 'full_name': 'Ali', 'username': 'ali', 'role': 'farmer'};
    final p = Post.fromJson({'id': 'p', 'author': author, 'title': 'T', 'image_url': '/a.jpg', 'image_urls': ['/a.jpg', '/b.jpg']});
    expect(p.imageUrls, ['/a.jpg', '/b.jpg']);
    expect(Post.fromJson({'id': 'p', 'author': author, 'title': 'T', 'image_url': '/a.jpg'}).imageUrls, ['/a.jpg']); // eski server
    expect(Post.fromJson({'id': 'p', 'author': author, 'title': 'T'}).imageUrls, isEmpty);
    final gone = Comment.fromJson({'id': 'c', 'author': null, 'content': '', 'deleted': true});
    expect(gone.deleted && gone.author == null, isTrue);
    final r = Comment.fromJson({'id': 'r', 'author': author, 'content': 'x', 'parent_id': 'c', 'reply_to_id': 'c', 'reply_to_name': 'Vali'});
    expect([r.parentId, r.replyToName], ['c', 'Vali']);
    final m = ChatMessage.fromJson({'id': 'm', 'sender_id': 'u', 'image_urls': ['/1.jpg', '/2.jpg'], 'is_read': false, 'delivered': true});
    expect([m.imageUrls.length, m.delivered, m.isRead], [2, true, false]);
    expect(ChatMessage.fromJson({'id': 'm', 'sender_id': 'u', 'is_read': true}).delivered, isTrue); // eski server: o'qilgan = yetkazilgan
    expect(m.copyWith(isRead: true).imageUrls.length, 2);
  });

  testWidgets('0.8.11: 5 rasmli grid "+1" ko\'rsatadi, xabar "Yetkazildi" holati', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [AppColors.light]),
      home: Scaffold(
        body: Column(children: [
          SizedBox(width: 300, child: PhotoGrid(urls: [for (var i = 0; i < 5; i++) '/m/$i.jpg'])),
          const MessageBubble(text: 'salom', me: true, state: MsgState.delivered),
        ]),
      ),
    ));
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Yetkazildi'), findsOneWidget);
    expect(kMaxPhotos, 5);
  });

  test('0.8.12: A01 fon tahlili holati', () {
    final q = AnalysisJob.fromJson({'id': 'j', 'status': 'queued'});
    expect([q.isActive, q.isDone], [true, false]);
    expect(AnalysisJob.fromJson({'id': 'j', 'status': 'finishing'}).isActive, isTrue);
    final d = AnalysisJob.fromJson({'id': 'j', 'status': 'done', 'diagnosis_id': 'd1'});
    expect([d.isActive, d.isDone, d.diagnosisId], [false, true, 'd1']);
    final f = AnalysisJob.fromJson({'id': 'j', 'status': 'failed', 'error': 'x', 'error_code': 422});
    expect([f.isActive, f.errorCode], [false, 422]);
    expect(AnalysisJob.fromJson({'id': 'j', 'status': 'cancelled'}).isActive, isFalse);
  });

  test('0.8.13: AI suhbat JSON — qisman javob, bog\'lanish, suhbat', () {
    final m = AIMessage.fromJson({'id': 'a', 'role': 'assistant', 'content': 'x', 'status': 'partial', 'reply_to_id': 'q', 'conversation_id': 'c'});
    expect([m.isPartial, m.isUser, m.replyToId, m.conversationId], [true, false, 'q', 'c']);
    expect(AIMessage.fromJson({'role': 'user', 'content': 'y'}).status, 'done'); // eski server
    final c = AIConversation.fromJson({'id': 'c', 'title': 'Sug\'orish', 'last_message': 'z', 'message_count': 4});
    expect([c.title, c.messageCount], ["Sug'orish", 4]);
  });
}
