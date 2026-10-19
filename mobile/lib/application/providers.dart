import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/expert_repository.dart';
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
final expertRepoProvider = Provider((ref) => ExpertRepository(ref.watch(apiClientProvider)));

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

  Future<void> register({required String fullName, String? email, String? phone, required String password, String? region, String? language, bool acceptTerms = false}) async {
    await _repo.register(fullName: fullName, email: email, phone: phone, password: password, region: region, language: language, acceptTerms: acceptTerms);
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  /// Kod bilan tasdiqlangan sessiya (S35): tokenlar repo'da saqlangan, foydalanuvchini yuklaymiz.
  Future<void> completeSession() async {
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) return;
    state = AuthState(AuthStatus.authenticated, await _repo.me());
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = AuthState(AuthStatus.authenticated, await _repo.updateMe(data));
  }

  Future<void> uploadAvatar(List<int> bytes, String filename) async {
    state = AuthState(AuthStatus.authenticated, await _repo.uploadAvatar(bytes, filename));
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
final plantProvider = FutureProvider.autoDispose.family<Plant, String>((ref, id) => ref.watch(catalogRepoProvider).plant(id));
final medicineProvider = FutureProvider.autoDispose.family<Medicine, String>((ref, id) => ref.watch(catalogRepoProvider).medicine(id));
final plantDiseasesProvider =
    FutureProvider.autoDispose.family<List<Disease>, String>((ref, id) => ref.watch(catalogRepoProvider).diseases(plantId: id));
final plantMedicinesProvider =
    FutureProvider.autoDispose.family<List<Medicine>, String>((ref, id) => ref.watch(catalogRepoProvider).plantMedicines(id));
final medicineDiseasesProvider =
    FutureProvider.autoDispose.family<List<Disease>, String>((ref, id) => ref.watch(catalogRepoProvider).medicineDiseases(id));

/// Ob-havo (foydalanuvchi hududi bo'yicha). autoDispose emas: tarmoq uzilsa oxirgi ma'lumot
/// (AsyncError ichidagi oldingi qiymat) ko'rsatiladi; xato faqat ob-havo blokida chiqadi (TZ S01).
final weatherProvider = FutureProvider<Weather>((ref) {
  ref.watch(currentUserProvider.select((u) => (u?.id, u?.region)));
  return ref.watch(gardenRepoProvider).weather();
});
final cropsProvider = FutureProvider.autoDispose<List<Crop>>((ref) => ref.watch(gardenRepoProvider).crops());
final archivedCropsProvider = FutureProvider.autoDispose<List<Crop>>((ref) => ref.watch(gardenRepoProvider).crops(status: 'archived'));
final cropProvider = FutureProvider.autoDispose.family<Crop, String>((ref, id) => ref.watch(gardenRepoProvider).crop(id));
final cropHealthProvider =
    FutureProvider.autoDispose.family<List<HealthPoint>, String>((ref, id) => ref.watch(gardenRepoProvider).health(id));
final cropLogsProvider = FutureProvider.autoDispose.family<List<CropLog>, String>((ref, id) => ref.watch(gardenRepoProvider).logs(id));
final cropDiagnosesProvider =
    FutureProvider.autoDispose.family<List<Diagnosis>, String>((ref, id) => ref.watch(gardenRepoProvider).diagnoses(cropId: id));
final diagnosisProvider = FutureProvider.autoDispose.family<Diagnosis, String>((ref, id) => ref.watch(gardenRepoProvider).diagnosis(id));
final carePlanProvider = FutureProvider.autoDispose.family<CarePlan, String>((ref, id) => ref.watch(gardenRepoProvider).carePlan(id));
final diagnosesProvider = FutureProvider.autoDispose<List<Diagnosis>>((ref) => ref.watch(gardenRepoProvider).diagnoses());
final remindersProvider = FutureProvider.autoDispose<List<Reminder>>((ref) => ref.watch(gardenRepoProvider).reminders());
final reminderProvider = FutureProvider.autoDispose.family<Reminder, String>((ref, id) => ref.watch(gardenRepoProvider).reminder(id));
/// Bitta ekin vazifalari (arxivlangan ekin uchun ham — tarix S06 da ko'rinadi).
final cropRemindersProvider =
    FutureProvider.autoDispose.family<List<Reminder>, String>((ref, id) => ref.watch(gardenRepoProvider).reminders(cropId: id));

/// Jamoat lentasi (S11): 'all' | 'following' | turkum ('experience', 'question', 'disease', 'advice').
final feedProvider = FutureProvider.autoDispose.family<List<Post>, String>((ref, feed) {
  final repo = ref.watch(communityRepoProvider);
  return switch (feed) {
    'all' || 'following' => repo.posts(feed: feed),
    _ => repo.posts(category: feed),
  };
});
final userPostsProvider =
    FutureProvider.autoDispose.family<List<Post>, String>((ref, uid) => ref.watch(communityRepoProvider).posts(userId: uid));
final postProvider = FutureProvider.autoDispose.family<Post, String>((ref, id) => ref.watch(communityRepoProvider).post(id));
final commentsProvider = FutureProvider.autoDispose.family<List<Comment>, String>((ref, id) => ref.watch(communityRepoProvider).comments(id));
final profileProvider = FutureProvider.autoDispose.family<UserProfile, String>((ref, id) => ref.watch(communityRepoProvider).profile(id));
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) => ref.watch(communityRepoProvider).conversations());
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) => ref.watch(communityRepoProvider).notifications());

final authOptionsProvider = FutureProvider.autoDispose<AuthOptions>((ref) => ref.watch(authRepoProvider).options());

final plansProvider = FutureProvider.autoDispose<List<Plan>>((ref) => ref.watch(subscriptionRepoProvider).plans());
final mySubscriptionProvider = FutureProvider.autoDispose<MySubscription>((ref) => ref.watch(subscriptionRepoProvider).me());
final paymentsProvider = FutureProvider.autoDispose<List<Subscription>>((ref) => ref.watch(subscriptionRepoProvider).history());

// ---------- Agronomlar va savollar ----------
final expertsProvider = FutureProvider.autoDispose<List<Expert>>((ref) => ref.watch(expertRepoProvider).experts());
final expertProvider = FutureProvider.autoDispose.family<Expert, String>((ref, id) => ref.watch(expertRepoProvider).expert(id));
final myQuestionsProvider = FutureProvider.autoDispose<List<Question>>((ref) => ref.watch(expertRepoProvider).mine());
final questionProvider = FutureProvider.autoDispose.family<Question, String>((ref, id) => ref.watch(expertRepoProvider).question(id));
final questionQuotaProvider = FutureProvider.autoDispose<QuestionQuota>((ref) => ref.watch(expertRepoProvider).quota());
final myApplicationProvider = FutureProvider.autoDispose<ExpertApplication?>((ref) => ref.watch(expertRepoProvider).myApplication());

// ---------- Agronom rejimi ----------
final expertStatsProvider = FutureProvider.autoDispose<ExpertStats>((ref) => ref.watch(expertRepoProvider).stats());
final reviewQueueProvider = FutureProvider.autoDispose.family<List<QueueItem>, String>((ref, f) => ref.watch(expertRepoProvider).queue(f));
final queueItemProvider = FutureProvider.autoDispose.family<QueueItem, String>((ref, id) => ref.watch(expertRepoProvider).queueItem(id));
final inboxProvider = FutureProvider.autoDispose.family<List<Question>, String>((ref, s) => ref.watch(expertRepoProvider).inbox(s));
final catalogChangesProvider = FutureProvider.autoDispose<List<CatalogChange>>((ref) => ref.watch(expertRepoProvider).changes());
final datasetImagesProvider =
    FutureProvider.autoDispose.family<List<DatasetImage>, String>((ref, label) => ref.watch(expertRepoProvider).datasetImages(label));
final unansweredPostsProvider =
    FutureProvider.autoDispose<List<Post>>((ref) => ref.watch(communityRepoProvider).posts(unanswered: true));
