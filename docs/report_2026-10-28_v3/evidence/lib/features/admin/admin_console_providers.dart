import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_providers.dart';
import '../auth/auth_providers.dart';
import '../../models/admin_workspace_models.dart';
import '../../core/network/api_failure.dart';

class AdminRequest {
  const AdminRequest(this.path, [this.query = const {}]);
  final String path;
  final Map<String, dynamic> query;
  @override
  bool operator ==(Object other) =>
      other is AdminRequest &&
      other.path == path &&
      other.query.length == query.length &&
      query.entries.every((entry) => other.query[entry.key] == entry.value);
  @override
  int get hashCode => Object.hash(
      path,
      Object.hashAllUnordered(
          query.entries.map((entry) => Object.hash(entry.key, entry.value))));
}

final adminResourceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AdminRequest>((ref, request) async {
  final owner = ref.watch(sessionIdentityProvider);
  final api = ref.watch(adminApiProvider);
  final permissions = request.path == '/admin/landlord-verifications'
      ? const ['admin.verifications.view', 'admin.support.read']
      : request.path == '/admin/property-reviews'
          ? const ['admin.properties.view']
          : request.path == '/admin/service-plans' ||
                  request.path.startsWith('/admin/subscriptions')
              ? const ['admin.plans.view']
              : request.path == '/admin/finance/transactions'
                  ? const ['admin.finance.read']
                  : const <String>[];
  if (permissions.isNotEmpty) {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    final rights = await ref.watch(adminCapabilitiesProvider.future);
    if (disposed ||
        owner == null ||
        ref.read(sessionIdentityProvider) != owner) {
      throw const ApiFailure(
          message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
    }
    if (!permissions.every(rights.has)) {
      throw const ApiFailure(
          message: 'Bạn không có quyền xem dữ liệu này.', statusCode: 403);
    }
  }
  if (request.path == '/admin/search' ||
      request.path.startsWith('/admin/resources/')) {
    final rights = await ref.watch(adminCapabilitiesProvider.future);
    if (!rights.has('admin.dashboard.view')) {
      throw const ApiFailure(
          message: 'Bạn không có quyền tra cứu.', statusCode: 403);
    }
  }
  if (request.path.startsWith('/admin/workspace/')) {
    final rights = await ref.watch(adminCapabilitiesProvider.future);
    if (!rights.has('admin.dashboard.view')) {
      throw const ApiFailure(
          message: 'Bạn không có quyền mở workspace.', statusCode: 403);
    }
  }
  return api.resource(request.path, query: request.query);
});

final adminOperationEpochProvider = StateProvider<int>((ref) => 0);

final adminWorkspaceResourceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AdminRequest>((ref, request) async {
  ref.watch(adminOperationEpochProvider);
  return ref.watch(adminResourceProvider(request).future);
});

void refreshAdminWorkspace(WidgetRef ref) {
  ref.invalidate(adminResourceProvider);
  ref.invalidate(adminCapabilitiesProvider);
  ref.read(adminOperationEpochProvider.notifier).state++;
}

const adminWorkspaceSummaryRequest = AdminRequest('/admin/workspace/summary');
final adminWorkspaceSummaryProvider =
    FutureProvider.autoDispose<AdminWorkspaceSummary>((ref) async {
  final response = await ref.watch(
      adminWorkspaceResourceProvider(adminWorkspaceSummaryRequest).future);
  return AdminWorkspaceSummary.fromJson(response);
});
