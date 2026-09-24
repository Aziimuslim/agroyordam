import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/providers.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/auth/forgot_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/chat/conversations_screen.dart';
import 'screens/chat/thread_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/create_post_screen.dart';
import 'screens/community/post_detail_screen.dart';
import 'screens/community/user_profile_screen.dart';
import 'screens/diagnosis/assistant_screen.dart';
import 'screens/diagnosis/care_plan_screen.dart';
import 'screens/diagnosis/diagnose_screen.dart';
import 'screens/diagnosis/diagnosis_detail_screen.dart';
import 'screens/garden/add_crop_screen.dart';
import 'screens/garden/crop_detail_screen.dart';
import 'screens/garden/garden_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/profile/diagnoses_history_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
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
      GoRoute(path: '/community', pageBuilder: (_, s) => _tab(const CommunityScreen(), s), routes: [
        GoRoute(path: 'new', builder: (_, __) => const CreatePostScreen()),
        GoRoute(path: ':id', builder: (_, s) => PostDetailScreen(id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/reminders', builder: (_, s) => RemindersScreen(cropId: s.uri.queryParameters['crop']), routes: [
        GoRoute(path: 'add', builder: (_, s) => AddReminderScreen(cropId: s.uri.queryParameters['crop'])),
      ]),
      GoRoute(path: '/profile', pageBuilder: (_, s) => _tab(const ProfileScreen(), s), routes: [
        GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
      ]),

      GoRoute(path: '/diagnose', builder: (_, s) => DiagnoseScreen(cropId: s.uri.queryParameters['crop'])),
      GoRoute(path: '/diagnosis/:id', builder: (_, s) => DiagnosisDetailScreen(id: s.pathParameters['id']!), routes: [
        GoRoute(path: 'plan', builder: (_, s) => CarePlanScreen(diagnosisId: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/diagnoses', builder: (_, __) => const DiagnosesHistoryScreen()),
      GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
      GoRoute(path: '/catalog', builder: (_, s) => CatalogScreen(tab: s.uri.queryParameters['tab'] ?? 'plants')),

      GoRoute(path: '/users/:id', builder: (_, s) => UserProfileScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/messages', builder: (_, __) => const ConversationsScreen(), routes: [
        GoRoute(path: ':id', builder: (_, s) => ThreadScreen(id: s.pathParameters['id']!)),
      ]),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen(), routes: [
        GoRoute(path: 'payments', builder: (_, __) => const PaymentsScreen()),
      ]),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
