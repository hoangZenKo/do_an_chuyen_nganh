import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/admin_dashboard.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import '../auth/auth_providers.dart';
import '../../core/network/api_failure.dart';

final adminDashboardDataProvider = FutureProvider.autoDispose
    .family<AdminDashboardData, int>((ref, days) async {
  ref.watch(sessionIdentityProvider);
  final rights = await ref.watch(adminCapabilitiesProvider.future);
  if (!rights.has('admin.dashboard.view')) {
    throw const ApiFailure(
        message: 'Bạn không có quyền xem tổng quan.', statusCode: 403);
  }
  final response = await ref.watch(adminWorkspaceResourceProvider(
      AdminRequest('/admin/analytics/overview', {'days': days})).future);
  return AdminDashboardData.fromJson(response);
});
