import '../../core/utils/format.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    this.email,
    this.phone,
    this.avatarUrl,
    this.region,
    this.language = 'uz',
    this.role = 'user',
    this.isPremium = false,
    this.premiumUntil,
    this.isActive = true,
    this.createdAt,
    this.specialization,
    this.acceptingQuestions = true,
    this.workHours,
    this.education,
    this.skills = const [],
    this.district,
    this.address,
    this.about,
    this.experienceYears,
    this.farmType,
    this.farmArea,
    this.mainCrops = const [],
    this.irrigation,
  });

  final String id, fullName, username;
  final String? email, phone, avatarUrl, region;
  final String language, role;
  final bool isPremium, isActive;
  final DateTime? premiumUntil, createdAt;

  /// Agronom: mutaxassisligi va savol qabul qilyaptimi (onlayn/oflayn).
  final String? specialization;
  final bool acceptingQuestions;
  final String? workHours;
  final String? education;
  final List<String> skills;

  /// Hudud tafsiloti va o'zi haqida (dehqon ham, agronom ham).
  final String? district, address, about;
  final int? experienceYears;

  /// Dehqon xo'jaligi: tomorqa|dehqon|fermer|issiqxona, maydon (gektar), asosiy ekinlar, sug'orish.
  final String? farmType, irrigation;
  final double? farmArea;
  final List<String> mainCrops;

  bool get hasFarmInfo => farmType != null || farmArea != null || mainCrops.isNotEmpty || irrigation != null;

  bool get isExpert => role == 'agronomist';
  bool get isAdmin => role == 'admin' || role == 'moderator';

  /// Tashxislarni tekshira oladi va agronom rejimiga kira oladi.
  bool get canReview => isExpert || isAdmin;
  String get initials => initialsOf(fullName);

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        fullName: j['full_name'] ?? '',
        username: j['username'] ?? '',
        email: j['email'],
        phone: j['phone'],
        avatarUrl: j['avatar_url'],
        region: j['region'],
        language: j['language'] ?? 'uz',
        role: j['role'] ?? 'user',
        isPremium: j['is_premium'] ?? false,
        premiumUntil: parseDate(j['premium_until']),
        isActive: j['is_active'] ?? true,
        createdAt: parseDate(j['created_at']),
        specialization: j['specialization'],
        acceptingQuestions: j['accepting_questions'] ?? true,
        workHours: j['work_hours'],
        education: j['education'],
        skills: strList(j['skills']),
        district: j['district'],
        address: j['address'],
        about: j['about'],
        experienceYears: j['experience_years'],
        farmType: j['farm_type'],
        farmArea: (j['farm_area'] as num?)?.toDouble(),
        mainCrops: strList(j['main_crops']),
        irrigation: j['irrigation'],
      );
}

List<String> strList(dynamic v) => [for (final x in (v as List? ?? const [])) x.toString()];

/// Savol bergan dehqon xo'jaligi — faqat agronom ko'radi.
class FarmBrief {
  FarmBrief({this.region, this.district, this.farmType, this.farmArea, this.mainCrops = const [], this.irrigation, this.experienceYears});
  final String? region, district, farmType, irrigation;
  final double? farmArea;
  final List<String> mainCrops;
  final int? experienceYears;

  bool get isEmpty =>
      region == null && district == null && farmType == null && farmArea == null && mainCrops.isEmpty && irrigation == null && experienceYears == null;

  factory FarmBrief.fromJson(Map<String, dynamic> j) => FarmBrief(
        region: j['region'],
        district: j['district'],
        farmType: j['farm_type'],
        farmArea: (j['farm_area'] as num?)?.toDouble(),
        mainCrops: strList(j['main_crops']),
        irrigation: j['irrigation'],
        experienceYears: j['experience_years'],
      );
}

class UserProfile {
  UserProfile({required this.user, this.followers = 0, this.following = 0, this.posts = 0, this.isFollowing = false});
  final AppUser user;
  final int followers, following, posts;
  final bool isFollowing;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        user: AppUser.fromJson(j),
        followers: j['followers_count'] ?? 0,
        following: j['following_count'] ?? 0,
        posts: j['posts_count'] ?? 0,
        isFollowing: j['is_following'] ?? false,
      );
}

String initialsOf(String name) => initials(name);
