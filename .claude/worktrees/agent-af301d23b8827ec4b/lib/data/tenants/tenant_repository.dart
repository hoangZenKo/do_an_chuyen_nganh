import '../../models/lease.dart';
import '../../models/tenant.dart';
import 'lease_api.dart';
import 'tenant_api.dart';

/// Thin coordinator over [TenantApi] and [LeaseApi].
class TenantRepository {
  const TenantRepository({required this.tenantApi, required this.leaseApi});

  final TenantApi tenantApi;
  final LeaseApi leaseApi;

  Future<List<Tenant>> tenants({String? lifecycle}) =>
      tenantApi.list(lifecycle: lifecycle);

  Future<Tenant> tenant(String id) => tenantApi.getById(id);

  Future<TenantOverview> tenantOverview(String id) => tenantApi.overview(id);

  Future<Tenant> createTenant(Tenant tenant) =>
      tenantApi.create(tenant.toPayload());

  Future<Tenant> updateTenant(String id, Tenant tenant) =>
      tenantApi.update(id, tenant.toPayload());

  Future<Tenant> createTenantAccount({
    required String tenantId,
    required String email,
    required String password,
  }) =>
      tenantApi.createAccount(tenantId, {
        'email': email.trim(),
        'password': password,
      });

  Future<Map<String, dynamic>> createTenantInvite({
    required String tenantId,
    required String email,
  }) =>
      tenantApi.createInvite(tenantId, {'email': email.trim()});

  Future<Tenant> setTenantActive(String id, bool isActive) =>
      tenantApi.setActive(id, isActive);

  Future<void> deleteTenant(String id) => tenantApi.delete(id);

  Future<List<Lease>> leasesOfTenant(String tenantId) =>
      leaseApi.listByTenant(tenantId);

  Future<List<Lease>> leasesOfRoom(String roomId) =>
      leaseApi.listByRoom(roomId);

  Future<Lease> createLease({
    required String roomId,
    required String tenantId,
    required int monthlyRent,
    int deposit = 0,
    DateTime? startDate,
  }) =>
      leaseApi.create({
        'roomId': roomId,
        'tenantId': tenantId,
        'monthlyRent': monthlyRent,
        'deposit': deposit,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
      });

  Future<Lease> endLease(String leaseId) => leaseApi.end(leaseId);

  Future<Lease> updateLease(
    String leaseId, {
    DateTime? startDate,
    DateTime? endDate,
    int? monthlyRent,
    int? deposit,
    String? note,
  }) {
    return leaseApi.update(leaseId, {
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (monthlyRent != null) 'monthlyRent': monthlyRent,
      if (deposit != null) 'deposit': deposit,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<Lease> renewLease(
    String leaseId, {
    required DateTime endDate,
    int? monthlyRent,
    int? deposit,
    String? note,
  }) {
    return leaseApi.renew(leaseId, {
      'endDate': endDate.toIso8601String(),
      if (monthlyRent != null) 'monthlyRent': monthlyRent,
      if (deposit != null) 'deposit': deposit,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<DepositTransaction> createDepositTransaction(
    String leaseId, {
    required String type,
    required int amount,
    String? note,
  }) {
    return leaseApi.createDeposit(leaseId, {
      'type': type,
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}
