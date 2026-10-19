import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/app_mode.dart';
import '../application/providers.dart';
import '../core/widgets/brand.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/appearance_screen.dart';
import 'screens/settings/language_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/recovery_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/catalog/catalog_detail_screens.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/chat/conversations_screen.dart';
import 'screens/chat/thread_screen.dart';
import 'screens/community/create_post_screen.dart';
import 'screens/community/post_detail_screen.dart';
import 'screens/community/user_profile_screen.dart';
import 'screens/diagnosis/assistant_screen.dart';
import 'screens/diagnosis/care_plan_screen.dart';
import 'screens/diagnosis/diagnose_screen.dart';
import 'screens/diagnosis/diagnosis_detail_screen.dart';
import 'screens/expert/expert_profile_screen.dart';
import 'screens/expert/expert_tabs.dart';
import 'screens/expert/kb_screens.dart';
import 'screens/expert/queue_screen.dart';
import 'screens/expert/review_screen.dart';
import 'screens/garden/add_crop_screen.dart';
import 'screens/garden/care_screen.dart';
import 'screens/garden/crop_detail_screen.dart';
import 'screens/garden/garden_screen.dart';
import 'screens/help/expert_public_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/help/question_screens.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/weather_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/diagnoses_history_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/expert_application_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reminders/add_reminder_screen.dart';
import 'screens/reminders/reminders_screen.dart';

/// Faqat sessiyasiz ochiladigan sahifalar (kirgan foydalanuvchi bosh sahifaga o'tkaziladi).
const _publicRoutes = {'/welcome', '/auth/login', '/auth/register', '/auth/verify', '/auth/recovery', '/login', '/register', '/forgot'};

/// Ikkala holatda ham ochiq: til va ilova haqida (S33 dan til/qoidalar havolasi).
const _openRoutes = {'/settings/language', '/settings/about'};

/// Sessiya yo'qligi sababli kirishga yuborilganda so'ralgan sahifa (TZ S33 returnTo). Faqat ilova ichidagi
/// himoyalangan yo'l qabul qilinadi: tashqi URL, '//' va auth sahifalari rad etiladi.
String? _returnTo;

String? safeReturnTo(String? loc) {
  if (loc == null || !loc.startsWith('/') || loc.startsWith('//') || loc.contains('://')) return null;
  final path = Uri.tryParse(loc)?.path ?? '';
  if (path.isEmpty || path == '/splash' || _publicRoutes.contains(path) || path.startsWith('/auth')) return null;
  return loc;
}

/// Tab ekranlari o'rtasida animatsiyasiz o'tish (pastki navigatsiya).
Page<void> _tab(Widget child, GoRouterState s) => NoTransitionPage(key: s.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthStatus>(ref.read(authProvider).status);
  ref.listen(authProvider, (_, next) => auth.value = next.status);
  ref.onDispose(auth.dispose);
  // Rejim tanlovi (agronom/dehqon) qurilmadan splash paytida o'qilib ulgursin
  ref.read(expertModePrefProvider);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: auth,
    redirect: (context, state) {
      final status = auth.value;
      final loc = state.matchedLocation;
      // Sahifa yangilanganda so'ralgan manzilni saqlab qolamiz (deep link)
      final from = state.uri.queryParameters['from'];
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : Uri(path: '/splash', queryParameters: {'from': state.uri.toString()}).toString();
      }
      final loggedIn = status == AuthStatus.authenticated;
      if (!loggedIn && !_publicRoutes.contains(loc) && !_openRoutes.contains(loc)) {
        // Himoyalangan sahifa so'ralgan — kirgach shu yerga qaytamiz (sessiyasiz ko'rsatilmaydi)
        _returnTo = safeReturnTo(loc == '/splash' ? from : state.uri.toString()) ?? _returnTo;
        return '/welcome';
      }
      if (loggedIn && loc == '/splash') return safeReturnTo(from) ?? '/home';
      if (loggedIn && _publicRoutes.contains(loc)) {
        final back = _returnTo;
        _returnTo = null;
        return back ?? '/home';
      }
      // Agronom rejimi: bosh sahifa o'rniga tekshirish navbati; oddiy foydalanuvchi bu bo'limga kira olmaydi
      if (loc.startsWith('/expert') && !(ref.read(currentUserProvider)?.canReview ?? false)) return '/home';
      if (loc == '/home' && ref.read(expertModeProvider)) return '/expert';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      // S33–S36 (TZ yo'llari); eski /login, /register, /forgot havolalari yangisiga yo'naltiriladi
      GoRoute(path: '/auth/login', builder: (_, s) => LoginScreen(via: s.uri.queryParameters['via'] ?? 'phone')),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/auth/verify', builder: (_, s) => VerifyScreen(args: s.extra is VerifyArgs ? s.extra as VerifyArgs : null)),
      GoRoute(path: '/auth/recovery', builder: (_, __) => const RecoveryScreen()),
      GoRoute(path: '/login', redirect: (_, s) => Uri(path: '/auth/login', queryParameters: s.uri.queryParameters.isEmpty ? null : s.uri.queryParameters).toString()),
      GoRoute(path: '/register', redirect: (_, __) => '/auth/register'),
      GoRoute(path: '/forgot', redirect: (_, __) => '/auth/recovery'),

      GoRoute(path: '/home', pageBuilder: (_, s) => _tab(const HomeScreen(), s)),
      GoRoute(path: '/garden', pageBuilder: (_, s) => _tab(const GardenScreen(), s), routes: [
        GoRoute(path: 'add', builder: (_, s) => AddCropScreen(plantId: s.uri.queryParameters['plant'])),
        GoRoute(
          path: ':id',
          builder: (_, s) => CropDetailScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!, tab: s.uri.queryParameters['tab']),
          routes: [
            GoRoute(path: 'edit', builder: (_, s) => EditCropRoute(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
            GoRoute(path: 'care', builder: (_, s) => CareScreen(key: ValueKey(s.matchedLocation), cropId: s.pathParameters['id']!)),
          ],
        ),
      ]),
      GoRoute(path: '/help', pageBuilder: (_, s) => _tab(HelpScreen(tab: s.uri.queryParameters['tab'] ?? 'agro'), s), routes: [
        GoRoute(path: 'ask', builder: (_, s) => AskQuestionScreen(diagnosisId: s.uri.queryParameters['diagnosis'], cropId: s.uri.queryParameters['crop'])),
        GoRoute(path: 'q/:id', builder: (_, s) => QuestionThreadScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
        GoRoute(path: 'agronom/:id', builder: (_, s) => ExpertPublicScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      ]),
      // Jamoat endi "Maslahat" ichida; eski havolalar (post sahifalari) shu yerda qoladi
      GoRoute(path: '/community', pageBuilder: (_, s) => _tab(const HelpScreen(tab: 'comm'), s), routes: [
        GoRoute(
          path: 'new',
          builder: (_, s) => s.uri.queryParameters['edit'] != null
              ? EditPostRoute(key: ValueKey(s.uri.toString()), id: s.uri.queryParameters['edit']!)
              : const CreatePostScreen(),
        ),
        GoRoute(path: ':id', builder: (_, s) => PostDetailScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!, focusComment: s.uri.queryParameters['comment'] == '1')),
      ]),
      GoRoute(path: '/reminders', builder: (_, s) => RemindersScreen(cropId: s.uri.queryParameters['crop']), routes: [
        GoRoute(path: 'add', builder: (_, s) => AddReminderScreen(cropId: s.uri.queryParameters['crop'])),
        GoRoute(path: ':id/edit', builder: (_, s) => EditReminderRoute(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/profile', pageBuilder: (_, s) => _tab(const ProfileScreen(), s), routes: [
        GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
        GoRoute(path: 'password', builder: (_, __) => const ChangePasswordScreen()),
        GoRoute(path: 'expert', builder: (_, __) => const ExpertApplicationScreen()),
      ]),

      GoRoute(path: '/diagnose', builder: (_, s) => DiagnoseScreen(cropId: s.uri.queryParameters['crop'], plantId: s.uri.queryParameters['plant'], source: s.uri.queryParameters['source'])),
      GoRoute(path: '/diagnosis/:id', builder: (_, s) => DiagnosisDetailScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!), routes: [
        GoRoute(path: 'plan', builder: (_, s) => CarePlanScreen(key: ValueKey(s.matchedLocation), diagnosisId: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/diagnoses', builder: (_, __) => const DiagnosesHistoryScreen()),
      GoRoute(path: '/assistant', builder: (_, s) => AssistantScreen(prefill: s.uri.queryParameters['q'])),
      GoRoute(path: '/catalog', builder: (_, s) => CatalogScreen(tab: s.uri.queryParameters['tab'] ?? 'plants'), routes: [
        GoRoute(path: 'plant/:id', builder: (_, s) => PlantScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
        GoRoute(path: 'disease/:id', builder: (_, s) => DiseaseScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
        GoRoute(path: 'medicine/:id', builder: (_, s) => MedicineScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      ]),

      GoRoute(path: '/users/:id', builder: (_, s) => UserProfileScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      GoRoute(path: '/messages', builder: (_, __) => const ConversationsScreen(), routes: [
        GoRoute(path: ':id', builder: (_, s) => ThreadScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      ]),
      // S31/S32/A05 sozlamalar; /subscription va /payments — TZ yo'llari (mavjud /premium ga yo'naltiriladi)
      GoRoute(path: '/settings/appearance', builder: (_, __) => const AppearanceScreen()),
      GoRoute(path: '/settings/language', builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/settings/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/subscription', redirect: (_, __) => '/premium'),
      GoRoute(path: '/payments', redirect: (_, __) => '/premium/payments'),
      GoRoute(path: '/weather', builder: (_, __) => const WeatherScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen(), routes: [
        GoRoute(path: 'payments', builder: (_, __) => const PaymentsScreen()),
      ]),

      // ---------- Agronom rejimi ----------
      GoRoute(path: '/expert', pageBuilder: (_, s) => _tab(const ExpertQueueScreen(), s)),
      GoRoute(path: '/expert/review/:id', builder: (_, s) => ReviewScreen(key: ValueKey(s.matchedLocation), id: s.pathParameters['id']!)),
      GoRoute(path: '/expert/questions', pageBuilder: (_, s) => _tab(const ExpertQuestionsScreen(), s)),
      GoRoute(path: '/expert/community', pageBuilder: (_, s) => _tab(const ExpertCommunityScreen(), s)),
      GoRoute(path: '/expert/kb', pageBuilder: (_, s) => _tab(const KnowledgeScreen(), s), routes: [
        GoRoute(
          path: ':entity/:id',
          builder: (_, s) {
            final id = s.pathParameters['id']!;
            return KbEditScreen(key: ValueKey(s.matchedLocation), entity: s.pathParameters['entity']!, id: id == 'new' ? null : id);
          },
        ),
      ]),
      GoRoute(path: '/expert/profile', pageBuilder: (_, s) => _tab(const ExpertProfileScreen(), s)),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandLogo(size: 96),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ]),
        ),
      );
}
