import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/operations/operations_api.dart';
import '../../models/landlord_notification.dart';
import '../auth/auth_providers.dart';
import '../notifications/notifications_providers.dart';

final operationsApiProvider = Provider<OperationsApi>((ref) {
  return OperationsApi(ref.watch(sessionDioProvider).client);
});

class ActionItemsQuery {
  const ActionItemsQuery({
    this.page = 1,
    this.limit = 20,
    this.category = 'all',
    this.propertyId,
  });

  final int page;
  final int limit;
  final String category;
  final String? propertyId;

  @override
  bool operator ==(Object other) {
    return other is ActionItemsQuery &&
        other.page == page &&
        other.limit == limit &&
        other.category == category &&
        other.propertyId == propertyId;
  }

  @override
  int get hashCode => Object.hash(page, limit, category, propertyId);
}

final actionItemsProvider =
    FutureProvider.family<ActionItems, ActionItemsQuery>(
  (ref, query) {
    return ref.watch(operationsApiProvider).actionItems(
          page: query.page,
          limit: query.limit,
          category: query.category,
          propertyId: query.propertyId,
        );
  },
);

Future<void> markActionRead(WidgetRef ref, LandlordNotification item) async {
  if (item.isRead) return;
  await ref.read(operationsApiProvider).markRead(item.id);
  ref.invalidate(actionItemsProvider);
  ref.invalidate(notificationsProvider);
}
