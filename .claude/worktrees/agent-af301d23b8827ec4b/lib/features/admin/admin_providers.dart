import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin/admin_api.dart';
import '../../data/admin/admin_repository.dart';
import '../../models/admin_models.dart';
import '../auth/auth_providers.dart';

final adminApiProvider = Provider<AdminApi>((ref) {
  return AdminApi(ref.watch(dioProvider));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(api: ref.watch(adminApiProvider));
});

final adminOverviewProvider = FutureProvider<AdminOverview>((ref) async {
  return ref.watch(adminRepositoryProvider).overview();
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

final adminPropertiesProvider =
    FutureProvider.family<List<AdminPropertySummary>, AdminPropertiesQuery>(
  (ref, query) async {
    return ref.watch(adminRepositoryProvider).properties(query);
  },
);

final adminPropertyDetailProvider =
    FutureProvider.family<AdminPropertyDetail, String>((ref, id) async {
  return ref.watch(adminRepositoryProvider).property(id);
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
        phone: phone,
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
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).updateLandlordStatus(
            landlordId,
            isActive: isActive,
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
    state = const AsyncValue.loading();
    final repo = ref.read(adminRepositoryProvider);
    final result = await AsyncValue.guard(() async {
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
    state = result;
    if (result.hasValue) {
      ref.invalidate(adminOverviewProvider);
      ref.invalidate(adminPropertiesProvider);
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
