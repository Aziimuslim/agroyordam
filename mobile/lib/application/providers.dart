import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/garden_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../domain/entities/entities.dart';

// ---------- Infrastruktura ----------
final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      ref.watch(tokenStorageProvider),
      onSessionExpired: () => ref.read(authProvider.notifier).sessionExpired(),
    ));

final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final catalogRepoProvider = Provider((ref) => CatalogRepository(ref.watch(apiClientProvider)));
final gardenRepoProvider = Provider((ref) => GardenRepository(ref.watch(apiClientProvider)));
final communityRepoProvider = Provider((ref) => CommunityRepository(ref.watch(apiClientProvider)));
final subscriptionRepoProvider = Provider((ref) => SubscriptionRepository(ref.watch(apiClientProvider)));
final adminRepoProvider = Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));

// ---------- Auth ----------
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final AppUser? user;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restore);
    return const AuthState(AuthStatus.unknown);
  }

  AuthRepository get _repo => ref.read(authRepoProvider);

  Future<void> restore() async {
    final token = await ref.read(tokenStorageProvider).readAccess();
    if (token == null) {
      state = const AuthState(AuthStatus.unauthenticated);
      return;
    }
    try {
      state = AuthState(AuthStatus.authenticated, await _repo.me());
    } catch (_) {
      await ref.read(tokenStorageProvider).clear();
      state = const AuthState(AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String login, String password) async {
    await _repo.login(login, password);
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  Future<void> register({required String fullName, required String username, String? email, String? phone, required String password, String? region}) async {
    await _repo.register(fullName: fullName, username: username, email: email, phone: phone, password: password, region: region);
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) return;
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = AuthState(AuthStatus.authenticated, await _repo.updateMe(data));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  void sessionExpired() {
    if (state.status == AuthStatus.authenticated) state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authProvider).user);

// ---------- Ma'lumot provayderlari ----------
final plantsProvider = FutureProvider<List<Plant>>((ref) => ref.watch(catalogRepoProvider).plants());
final diseasesProvider = FutureProvider.autoDispose<List<Disease>>((ref) => ref.watch(catalogRepoProvider).diseases());
final medicinesProvider = FutureProvider.autoDispose<List<Medicine>>((ref) => ref.watch(catalogRepoProvider).medicines());
final diseaseProvider = FutureProvider.autoDispose.family<Disease, String>((ref, id) => ref.watch(catalogRepoProvider).disease(id));

final cropsProvider = FutureProvider.autoDispose<List<Crop>>((ref) => ref.watch(gardenRepoProvider).crops());
final cropProvider = FutureProvider.autoDispose.family<Crop, String>((ref, id) => ref.watch(gardenRepoProvider).crop(id));
final cropHealthProvider =
    FutureProvider.autoDispose.family<List<HealthPoint>, String>((ref, id) => ref.watch(gardenRepoProvider).health(id));
final cropLogsProvider = FutureProvider.autoDispose.family<List<CropLog>, String>((ref, id) => ref.watch(gardenRepoProvider).logs(id));
final cropDiagnosesProvider =
    FutureProvider.autoDispose.family<List<Diagnosis>, String>((ref, id) => ref.watch(gardenRepoProvider).diagnoses(cropId: id));
final diagnosesProvider = FutureProvider.autoDispose<List<Diagnosis>>((ref) => ref.watch(gardenRepoProvider).diagnoses());
final remindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) => ref.watch(gardenRepoProvider).reminders());

final feedProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, feed) => ref.watch(communityRepoProvider).posts(feed: feed));
final userPostsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, uid) => ref.watch(communityRepoProvider).posts(userId: uid));
final postProvider = FutureProvider.autoDispose.family<Post, String>((ref, id) => ref.watch(communityRepoProvider).post(id));
final commentsProvider = FutureProvider.autoDispose.family<List<Comment>, String>((ref, id) => ref.watch(communityRepoProvider).comments(id));
final profileProvider = FutureProvider.autoDispose.family<UserProfile, String>((ref, id) => ref.watch(communityRepoProvider).profile(id));
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) => ref.watch(communityRepoProvider).conversations());
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) => ref.watch(communityRepoProvider).notifications());

final plansProvider = FutureProvider.autoDispose<List<Plan>>((ref) => ref.watch(subscriptionRepoProvider).plans());
final mySubscriptionProvider = FutureProvider.autoDispose<MySubscription>((ref) => ref.watch(subscriptionRepoProvider).me());
final paymentsProvider = FutureProvider.autoDispose<List<Subscription>>((ref) => ref.watch(subscriptionRepoProvider).history());
