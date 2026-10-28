import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/operations/operations_api.dart';
import '../../models/landlord_notification.dart';
import '../auth/auth_providers.dart';

final operationsApiProvider = Provider<OperationsApi>((ref) {
  return OperationsApi(ref.watch(dioProvider));
});

final actionItemsProvider = FutureProvider<ActionItems>((ref) {
  return ref.watch(operationsApiProvider).actionItems();
});
