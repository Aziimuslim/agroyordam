import '../../domain/entities/entities.dart';
import 'base.dart';

class SubscriptionRepository extends BaseRepository {
  SubscriptionRepository(super.api);

  Future<List<Plan>> plans() => call(() async => list((await dio.get('/subscriptions/plans')).data, Plan.fromJson));
  Future<MySubscription> me() => call(() async => MySubscription.fromJson((await dio.get('/subscriptions/me')).data));
  Future<List<Subscription>> history() => call(() async => list((await dio.get('/subscriptions/history')).data, Subscription.fromJson));
  Future<Checkout> checkout(String plan, String provider) =>
      call(() async => Checkout.fromJson((await dio.post('/subscriptions/checkout', data: {'plan': plan, 'provider': provider})).data));
  Future<void> sandboxConfirm(String subId) => call(() => dio.post('/subscriptions/sandbox/confirm/$subId'));
  Future<void> cancel() => call(() => dio.post('/subscriptions/cancel'));
}
