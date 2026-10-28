import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reports/reports_api.dart';
import '../../models/reports.dart';
import '../auth/auth_providers.dart';
import '../rooms/property_selection_provider.dart';

final reportsApiProvider = Provider<ReportsApi>((ref) {
  return ReportsApi(ref.watch(dioProvider));
});

final selectedReportMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final monthlyReportProvider = FutureProvider<MonthlyReport>((ref) {
  final month = ref.watch(selectedReportMonthProvider);
  final propertyId = ref.watch(selectedPropertyProvider);
  return ref.watch(reportsApiProvider).monthly(
        month: month.toIso8601String(),
        propertyId: propertyId,
      );
});

final billingRemindersProvider = FutureProvider<List<BillingReminder>>((ref) {
  final propertyId = ref.watch(selectedPropertyProvider);
  return ref.watch(reportsApiProvider).reminders(propertyId: propertyId);
});
