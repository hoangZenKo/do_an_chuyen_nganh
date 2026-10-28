import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tenants/lease_api.dart';
import '../../data/tenants/tenant_api.dart';
import '../../data/tenants/tenant_repository.dart';
import '../../models/lease.dart';
import '../../models/tenant.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../reports/reports_providers.dart';
import '../rooms/room_providers.dart';

// ── Dependency injection ──────────────────────────────────────────────────────

final tenantApiProvider = Provider<TenantApi>((ref) {
  return TenantApi(ref.watch(sessionDioProvider).client);
});

final leaseApiProvider = Provider<LeaseApi>((ref) {
  return LeaseApi(ref.watch(sessionDioProvider).client);
});

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository(
    tenantApi: ref.watch(tenantApiProvider),
    leaseApi: ref.watch(leaseApiProvider),
  );
});

// ── Reads ─────────────────────────────────────────────────────────────────────

final tenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  return ref.watch(tenantRepositoryProvider).tenants();
});

final inactiveTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  return ref.watch(tenantRepositoryProvider).tenants(lifecycle: 'inactive');
});

final tenantDetailProvider =
    FutureProvider.family<Tenant, String>((ref, id) async {
  return ref.watch(tenantRepositoryProvider).tenant(id);
});

final tenantOverviewProvider =
    FutureProvider.family<TenantOverview, String>((ref, id) async {
  return ref.watch(tenantRepositoryProvider).tenantOverview(id);
});

final tenantLeasesProvider =
    FutureProvider.family<List<Lease>, String>((ref, tenantId) async {
  return ref.watch(tenantRepositoryProvider).leasesOfTenant(tenantId);
});

/// Lease history for a room; the first ACTIVE one is the current tenancy.
final roomLeasesProvider =
    FutureProvider.family<List<Lease>, String>((ref, roomId) async {
  return ref.watch(tenantRepositoryProvider).leasesOfRoom(roomId);
});

final expiringLeasesProvider = FutureProvider<List<ExpiringLease>>((ref) {
  return ref.watch(leaseApiProvider).expiring();
});

// ── Tenant create / update / lifecycle ────────────────────────────────────────

class TenantFormController extends AutoDisposeAsyncNotifier<Tenant?> {
  @override
  Future<Tenant?> build() async => null;

  Future<Tenant> submit({Tenant? existing, required Tenant draft}) async {
    state = const AsyncValue.loading();
    final repo = ref.read(tenantRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      return existing == null
          ? repo.createTenant(draft)
          : repo.updateTenant(existing.id, draft);
    });
    state = result;
    if (result.hasValue) {
      _invalidateTenant(existing?.id ?? result.value!.id);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Tenant> setActive({
    required String tenantId,
    required bool isActive,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantRepositoryProvider).setTenantActive(
            tenantId,
            isActive,
          );
    });
    state = result;
    if (result.hasValue) {
      _invalidateTenant(tenantId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Tenant> createAccount({
    required String tenantId,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantRepositoryProvider).createTenantAccount(
            tenantId: tenantId,
            email: email,
            password: password,
          );
    });
    state = result;
    if (result.hasValue) {
      _invalidateTenant(tenantId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Map<String, dynamic>> createInvite({
    required String tenantId,
    required String email,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantRepositoryProvider).createTenantInvite(
            tenantId: tenantId,
            email: email,
          );
    });
    state = result.hasError
        ? AsyncValue<Tenant?>.error(result.error!, result.stackTrace!)
        : const AsyncValue<Tenant?>.data(null);
    if (result.hasError) throw result.error!;
    return result.value!;
  }

  Future<void> delete(String tenantId) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(tenantRepositoryProvider).deleteTenant(tenantId);
      return null;
    });
    state = result;
    if (result.hasValue) {
      _invalidateTenant(tenantId);
    }
    if (result.hasError) throw result.error!;
  }

  void _invalidateTenant(String tenantId) {
    ref.invalidate(tenantsProvider);
    ref.invalidate(inactiveTenantsProvider);
    ref.invalidate(tenantDetailProvider(tenantId));
    ref.invalidate(tenantOverviewProvider(tenantId));
    ref.invalidate(tenantLeasesProvider(tenantId));
    final propertyId = ref.read(selectedPropertyProvider);
    if (propertyId != null) {
      ref.invalidate(roomsProvider(propertyId));
      ref.invalidate(inactiveRoomsProvider(propertyId));
    }
    ref.invalidate(propertiesProvider);
    ref.invalidate(dashboardMetricsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(billingRemindersProvider);
  }
}

final tenantFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<TenantFormController, Tenant?>(
  TenantFormController.new,
);

// ── Lease create / end ─────────────────────────────────────────────────────────

class LeaseFormController extends AutoDisposeAsyncNotifier<Lease?> {
  @override
  Future<Lease?> build() async => null;

  Future<Lease> create({
    required String roomId,
    required String tenantId,
    required int monthlyRent,
    int deposit = 0,
    DateTime? startDate,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(tenantRepositoryProvider);
    final result = await AsyncValue.guard(() {
      return repo.createLease(
        roomId: roomId,
        tenantId: tenantId,
        monthlyRent: monthlyRent,
        deposit: deposit,
        startDate: startDate,
      );
    });
    state = result;
    if (result.hasValue) _invalidateAll(tenantId);
    return result.value ?? (throw result.error!);
  }

  Future<Lease> end({
    required String leaseId,
    required String tenantId,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(tenantRepositoryProvider);
    final result = await AsyncValue.guard(() => repo.endLease(leaseId));
    state = result;
    if (result.hasValue) _invalidateAll(tenantId);
    return result.value ?? (throw result.error!);
  }

  Future<Lease> renew({
    required String leaseId,
    required String tenantId,
    required DateTime endDate,
    int? monthlyRent,
    int? deposit,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantRepositoryProvider).renewLease(
            leaseId,
            endDate: endDate,
            monthlyRent: monthlyRent,
            deposit: deposit,
            note: note,
          );
    });
    state = result;
    if (result.hasValue) _invalidateAll(tenantId);
    return result.value ?? (throw result.error!);
  }

  Future<DepositTransaction> depositTransaction({
    required String leaseId,
    required String tenantId,
    required String type,
    required int amount,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantRepositoryProvider).createDepositTransaction(
            leaseId,
            type: type,
            amount: amount,
            note: note,
          );
    });
    state = const AsyncValue<Lease?>.data(null);
    if (result.hasValue) _invalidateAll(tenantId);
    return result.value ?? (throw result.error!);
  }

  /// A lease change updates room status server-side, so refresh both features.
  void _invalidateAll(String tenantId) {
    ref.invalidate(tenantsProvider);
    ref.invalidate(inactiveTenantsProvider);
    ref.invalidate(tenantDetailProvider(tenantId));
    ref.invalidate(tenantOverviewProvider(tenantId));
    ref.invalidate(tenantLeasesProvider(tenantId));
    final propertyId = ref.read(selectedPropertyProvider);
    if (propertyId != null) {
      ref.invalidate(roomsProvider(propertyId));
      ref.invalidate(inactiveRoomsProvider(propertyId));
    }
    ref.invalidate(propertiesProvider);
    ref.invalidate(dashboardMetricsProvider);
  }
}

final leaseFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<LeaseFormController, Lease?>(
  LeaseFormController.new,
);
