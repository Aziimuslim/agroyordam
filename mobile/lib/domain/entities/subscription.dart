import '../../core/utils/format.dart';

class Plan {
  Plan({required this.code, required this.title, required this.price, this.durationDays, this.features = const []});
  final String code, title;
  final double price;
  final int? durationDays;
  final List<String> features;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        code: j['code'],
        title: j['title'],
        price: double.parse('${j['price']}'),
        durationDays: j['duration_days'],
        features: List<String>.from(j['features'] ?? []),
      );
}

class Subscription {
  Subscription({required this.id, required this.plan, required this.status, this.price, this.provider, this.startedAt, this.expiresAt, this.autoRenew = true});
  final String id, plan, status;
  final double? price;
  final String? provider;
  final DateTime? startedAt, expiresAt;
  final bool autoRenew;

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'],
        plan: j['plan'],
        status: j['status'],
        price: j['price'] == null ? null : double.parse('${j['price']}'),
        provider: j['payment_provider'],
        startedAt: parseDate(j['started_at']),
        expiresAt: parseDate(j['expires_at']),
        autoRenew: j['auto_renew'] ?? true,
      );
}

class MySubscription {
  MySubscription({required this.isPremium, this.premiumUntil, this.active, this.aiUsedToday = 0, this.aiDailyLimit, this.cropsUsed = 0, this.cropLimit});
  final bool isPremium;
  final DateTime? premiumUntil;
  final Subscription? active;
  final int aiUsedToday, cropsUsed;
  final int? aiDailyLimit, cropLimit;

  factory MySubscription.fromJson(Map<String, dynamic> j) => MySubscription(
        isPremium: j['is_premium'] ?? false,
        premiumUntil: parseDate(j['premium_until']),
        active: j['active'] == null ? null : Subscription.fromJson(j['active']),
        aiUsedToday: j['ai_used_today'] ?? 0,
        aiDailyLimit: j['ai_daily_limit'],
        cropsUsed: j['crops_used'] ?? 0,
        cropLimit: j['crop_limit'],
      );
}

class Checkout {
  Checkout({required this.subscriptionId, required this.provider, required this.amount, required this.paymentUrl, required this.sandbox});
  final String subscriptionId, provider, paymentUrl;
  final double amount;
  final bool sandbox;

  factory Checkout.fromJson(Map<String, dynamic> j) => Checkout(
        subscriptionId: j['subscription_id'],
        provider: j['provider'],
        amount: double.parse('${j['amount']}'),
        paymentUrl: j['payment_url'],
        sandbox: j['sandbox'] ?? false,
      );
}
