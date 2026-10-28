import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin/admin_api.dart';
import '../../data/admin/admin_repository.dart';
import '../../models/admin_models.dart';
import '../../models/admin_inventory.dart';
import '../../models/admin_account_detail.dart';
import '../../core/network/api_failure.dart';
import '../auth/auth_providers.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  final session = ref.watch(sessionDioProvider);
  return AdminApi(session.client, ownerId: session.userId);
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(api: ref.watch(adminApiProvider));
});

final adminOverviewProvider = FutureProvider<AdminOverview>((ref) async {
  return ref.watch(adminRepositoryProvider).overview();
});

final adminCapabilitiesProvider =
    FutureProvider<AdminCapabilities>((ref) async {
  return ref.watch(adminRepositoryProvider).capabilities();
});

final adminAccountsQueryProvider = StateProvider<AdminAccountsQuery>((ref) {
  ref.watch(sessionIdentityProvider);
  return const AdminAccountsQuery();
});

final adminAccountsProvider =
    FutureProvider.family<AdminPagedResponse<AdminAccount>, AdminAccountsQuery>(
        (ref, query) async {
  final owner = ref.watch(sessionIdentityProvider);
  if (owner == null) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  final repository = ref.watch(adminRepositoryProvider);
  final rights = await ref.watch(adminCapabilitiesProvider.future);
  if (cancelled || ref.read(sessionIdentityProvider) != owner) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  if (!rights.has('admin.accounts.view')) {
    throw const ApiFailure(
        message: 'Bạn không có quyền xem tài khoản.', statusCode: 403);
  }
  return repository.accounts(
      page: query.page,
      limit: query.limit,
      search: query.search,
      role: query.role,
      status: query.status,
      from: query.from,
      to: query.to);
});

final adminAccountDetailProvider = FutureProvider.autoDispose
    .family<AdminAccountDetail, String>((ref, id) async {
  final owner = ref.watch(sessionIdentityProvider);
  if (owner == null) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  final repository = ref.watch(adminRepositoryProvider);
  final rights = await ref.watch(adminCapabilitiesProvider.future);
  if (cancelled || ref.read(sessionIdentityProvider) != owner) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  if (!rights.has('admin.accounts.view')) {
    throw const ApiFailure(
        message: 'Bạn không có quyền xem tài khoản.', statusCode: 403);
  }
  return repository.account(id);
});

final adminAuditLogsProvider =
    FutureProvider.family<AdminPagedResponse<AdminAuditEntry>, int>(
        (ref, page) async {
  return ref.watch(adminRepositoryProvider).auditLogs(page: page);
});

final adminAnalyticsProvider =
    FutureProvider.family<AdminAnalytics, int>((ref, days) async {
  return ref.watch(adminRepositoryProvider).analytics(days: days);
});

final adminModerationQueueProvider =
    FutureProvider.family<AdminPagedResponse<AdminQueueItem>, String>(
        (ref, kind) async {
  return ref.watch(adminRepositoryProvider).moderationQueue(kind: kind);
});

final adminLandlordsProvider =
    FutureProvider.family<List<AdminLandlordSummary>, AdminLandlordsQuery>(
  (ref, query) async {
    return ref.watch(adminRepositoryProvider).landlords(query);
  },
);

final adminLandlordDetailProvider =
    FutureProvider.family<AdminLandlordDetail, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).landlord(id);
});

final adminPropertiesQueryProvider = StateProvider<AdminPropertiesQuery>((ref) {
  ref.watch(sessionIdentityProvider);
  return const AdminPropertiesQuery();
});

final adminRoomsQueryProvider =
    StateProvider.family<AdminRoomsQuery, String?>((ref, propertyId) {
  ref.watch(sessionIdentityProvider);
  return AdminRoomsQuery(propertyId: propertyId);
});

Future<AdminRepository> _inventoryRepository(Ref ref) async {
  final owner = ref.watch(sessionIdentityProvider);
  if (owner == null) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  final repository = ref.watch(adminRepositoryProvider);
  final rights = await ref.watch(adminCapabilitiesProvider.future);
  if (cancelled || ref.read(sessionIdentityProvider) != owner) {
    throw const ApiFailure(
        message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
  }
  if (!rights.has('admin.properties.view')) {
    throw const ApiFailure(
        message: 'Bạn không có quyền xem khu trọ/phòng.', statusCode: 403);
  }
  return repository;
}

final adminPropertiesProvider = FutureProvider.family<
    AdminPagedResponse<AdminPropertySummary>, AdminPropertiesQuery>(
  (ref, query) async {
    return (await _inventoryRepository(ref)).properties(query);
  },
);

final adminPropertyDetailProvider = FutureProvider.autoDispose
    .family<AdminPropertyDetail, String>((ref, id) async {
  return (await _inventoryRepository(ref)).property(id);
});

final adminRoomsProvider = FutureProvider.family<
    AdminPagedResponse<AdminRoomSummary>, AdminRoomsQuery>((ref, query) async {
  return (await _inventoryRepository(ref)).rooms(query);
});

class AdminLandlordFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    String? landlordId,
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(adminRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      if (landlordId == null) {
        await repo.createLandlord(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
        );
        return;
      }
      await repo.updateLandlord(
        landlordId,
        fullName: fullName,
        phone: phone.contains('*') ? null : phone,
      );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(adminLandlordsProvider);
      if (landlordId != null) {
        ref.invalidate(adminLandlordDetailProvider(landlordId));
      }
    }
    if (result.hasError) throw result.error!;
  }
}

final adminLandlordFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<AdminLandlordFormController, void>(
  AdminLandlordFormController.new,
);

class AdminLandlordStatusController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String landlordId,
    required bool isActive,
    String? reason,
    int? version,
    AdminStepUpPrompt? prompt,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).updateLandlordStatus(
            landlordId,
            isActive: isActive,
            reason: reason,
            version: version,
            prompt: prompt,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(adminLandlordDetailProvider(landlordId));
      ref.invalidate(adminLandlordsProvider);
    }
    if (result.hasError) throw result.error!;
  }
}

final adminLandlordStatusControllerProvider =
    AutoDisposeAsyncNotifierProvider<AdminLandlordStatusController, void>(
  AdminLandlordStatusController.new,
);

class AdminPropertyFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    String? propertyId,
    String? landlordId,
    required String name,
    required String address,
  }) async {
    final owner = ref.read(sessionIdentityProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    state = const AsyncValue.loading();
    final repo = ref.read(adminRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      final rights = await ref.read(adminCapabilitiesProvider.future);
      if (disposed ||
          owner == null ||
          ref.read(sessionIdentityProvider) != owner) {
        throw const ApiFailure(
            message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
      }
      if (!rights.has('admin.properties.manage')) {
        throw const ApiFailure(
            message: 'Bạn không có quyền chỉnh sửa khu trọ.', statusCode: 403);
      }
      if (propertyId == null) {
        await repo.createProperty(
          landlordId: landlordId ?? '',
          name: name,
          address: address,
        );
        return;
      }
      await repo.updateProperty(
        propertyId,
        name: name,
        address: address,
      );
    });
    if (disposed || ref.read(sessionIdentityProvider) != owner) {
      throw const ApiFailure(
          message: 'Phiên đăng nhập đã thay đổi.', statusCode: 401);
    }
    state = result;
    if (result.hasValue) {
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(adminPropertiesProvider);
      ref.invalidate(adminRoomsProvider);
      if (propertyId != null) {
        ref.invalidate(adminPropertyDetailProvider(propertyId));
      }
      if (landlordId != null && landlordId.isNotEmpty) {
        ref.invalidate(adminLandlordDetailProvider(landlordId));
      }
    }
    if (result.hasError) throw result.error!;
  }
}

final adminPropertyFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<AdminPropertyFormController, void>(
  AdminPropertyFormController.new,
);
