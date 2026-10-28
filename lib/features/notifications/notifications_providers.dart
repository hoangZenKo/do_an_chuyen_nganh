import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notifications/notifications_api.dart';
import '../../models/landlord_notification.dart';
import '../../models/notification_delivery.dart';
import '../auth/auth_providers.dart';

final notificationsApiProvider = Provider<NotificationsApi>((ref) {
  return NotificationsApi(ref.watch(sessionDioProvider).client);
});

final notificationsProvider = FutureProvider<NotificationBundle>((ref) {
  return ref.watch(notificationsApiProvider).list();
});

final notificationDeliveriesProvider =
    FutureProvider.autoDispose<List<NotificationDeliveryLog>>((ref) {
  return ref.watch(notificationsApiProvider).deliveryLogs();
});

class NotificationsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markRead(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(notificationsApiProvider).markRead(id);
    });
    state = result;
    if (result.hasValue) ref.invalidate(notificationsProvider);
    if (result.hasError) throw result.error!;
  }
}

final notificationsControllerProvider =
    AutoDisposeAsyncNotifierProvider<NotificationsController, void>(
  NotificationsController.new,
);
