import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/app_mode.dart';
import '../application/providers.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/auth/forgot_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
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
import 'screens/garden/crop_detail_screen.dart';
import 'screens/garden/garden_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/help/question_screens.dart';
import 'screens/home/home_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/profile/diagnoses_history_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/expert_application_screen.dart';
import 'screens/profile/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reminders/add_reminder_screen.dart';
import 'screens/reminders/reminders_screen.dart';

const _publicRoutes = {'/welcome', '/login', '/register', '/forgot'};

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
      if (!loggedIn && !_publicRoutes.contains(loc)) return '/welcome';
      if (loggedIn && loc == '/splash') return (from != null && from.startsWith('/') && !from.startsWith('/splash')) ? from : '/home';
      if (loggedIn && _publicRoutes.contains(loc)) return '/home';
      if (loc.startsWith('/admin') && !(ref.read(currentUserProvider)?.isAdmin ?? false)) return '/home';
      // Agronom rejimi: bosh sahifa o'rniga tekshirish navbati; oddiy foydalanuvchi bu bo'limga kira olmaydi
      if (loc.startsWith('/expert') && !(ref.read(currentUserProvider)?.canReview ?? false)) return '/home';
      if (loc == '/home' && ref.read(expertModeProvider)) return '/expert';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(via: s.uri.queryParameters['via'] ?? 'email')),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),

      GoRoute(path: '/home', pageBuilder: (_, s) => _tab(const HomeScreen(), s)),
      GoRoute(path: '/garden', pageBuilder: (_, s) => _tab(const GardenScreen(), s), routes: [
        GoRoute(path: 'add', builder: (_, __) => const AddCropScreen()),
        GoRoute(path: ':id', builder: (_, s) => CropDetailScreen(id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/help', pageBuilder: (_, s) => _tab(HelpScreen(tab: s.uri.queryParameters['tab'] ?? 'agro'), s), routes: [
        GoRoute(path: 'ask', builder: (_, s) => AskQuestionScreen(diagnosisId: s.uri.queryParameters['diagnosis'], cropId: s.uri.queryParameters['crop'])),
        GoRoute(path: 'q/:id', builder: (_, s) => QuestionThreadScreen(id: s.pathParameters['id']!)),
      ]),
      // Jamoat endi "Maslahat" ichida; eski havolalar (post sahifalari) shu yerda qoladi
      GoRoute(path: '/community', pageBuilder: (_, s) => _tab(const HelpScreen(tab: 'comm'), s), routes: [
        GoRoute(path: 'new', builder: (_, __) => const CreatePostScreen()),
        GoRoute(path: ':id', builder: (_, s) => PostDetailScreen(id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/reminders', builder: (_, s) => RemindersScreen(cropId: s.uri.queryParameters['crop']), routes: [
        GoRoute(path: 'add', builder: (_, s) => AddReminderScreen(cropId: s.uri.queryParameters['crop'])),
      ]),
      GoRoute(path: '/profile', pageBuilder: (_, s) => _tab(const ProfileScreen(), s), routes: [
        GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
        GoRoute(path: 'expert', builder: (_, __) => const ExpertApplicationScreen()),
      ]),

      GoRoute(path: '/diagnose', builder: (_, s) => DiagnoseScreen(cropId: s.uri.queryParameters['crop'], source: s.uri.queryParameters['source'])),
      GoRoute(path: '/diagnosis/:id', builder: (_, s) => DiagnosisDetailScreen(id: s.pathParameters['id']!), routes: [
        GoRoute(path: 'plan', builder: (_, s) => CarePlanScreen(diagnosisId: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/diagnoses', builder: (_, __) => const DiagnosesHistoryScreen()),
      GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
      GoRoute(path: '/catalog', builder: (_, s) => CatalogScreen(tab: s.uri.queryParameters['tab'] ?? 'plants'), routes: [
        GoRoute(path: 'plant/:id', builder: (_, s) => PlantScreen(id: s.pathParameters['id']!)),
        GoRoute(path: 'disease/:id', builder: (_, s) => DiseaseScreen(id: s.pathParameters['id']!)),
        GoRoute(path: 'medicine/:id', builder: (_, s) => MedicineScreen(id: s.pathParameters['id']!)),
      ]),

      GoRoute(path: '/users/:id', builder: (_, s) => UserProfileScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/messages', builder: (_, __) => const ConversationsScreen(), routes: [
        GoRoute(path: ':id', builder: (_, s) => ThreadScreen(id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen(), routes: [
        GoRoute(path: 'payments', builder: (_, __) => const PaymentsScreen()),
      ]),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),

      // ---------- Agronom rejimi ----------
      GoRoute(path: '/expert', pageBuilder: (_, s) => _tab(const ExpertQueueScreen(), s)),
      GoRoute(path: '/expert/review/:id', builder: (_, s) => ReviewScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/expert/questions', pageBuilder: (_, s) => _tab(const ExpertQuestionsScreen(), s)),
      GoRoute(path: '/expert/community', pageBuilder: (_, s) => _tab(const ExpertCommunityScreen(), s)),
      GoRoute(path: '/expert/kb', pageBuilder: (_, s) => _tab(const KnowledgeScreen(), s), routes: [
        GoRoute(
          path: ':entity/:id',
          builder: (_, s) {
            final id = s.pathParameters['id']!;
            return KbEditScreen(entity: s.pathParameters['entity']!, id: id == 'new' ? null : id);
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
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
