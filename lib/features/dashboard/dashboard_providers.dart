import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard/dashboard_api.dart';
import '../../data/dashboard/dashboard_repository.dart';
import '../../models/dashboard.dart';
import '../auth/auth_providers.dart';
import '../rooms/property_selection_provider.dart';

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(ref.watch(sessionDioProvider).client);
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dashboardApiProvider));
});

final dashboardMonthsProvider = StateProvider<int>((ref) => 12);

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) {
  final months = ref.watch(dashboardMonthsProvider);
  final propertyId = ref.watch(selectedPropertyProvider);
  final userId = ref.watch(sessionControllerProvider).session?.user.id;
  if (userId == null) {
    throw StateError('Dashboard requires an authenticated session.');
  }
  return ref.watch(dashboardRepositoryProvider).metrics(
        propertyId: propertyId,
        months: months,
      );
});
