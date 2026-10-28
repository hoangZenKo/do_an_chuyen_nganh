import '../../models/admin_models.dart';
import '../../models/admin_inventory.dart';
import '../../models/admin_account_detail.dart';
import 'admin_api.dart';

class AdminRepository {
  const AdminRepository({required this.api});

  final AdminApi api;

  Future<AdminOverview> overview() => api.overview();
  Future<AdminAccountDetail> account(String id) => api.account(id);
  Future<AdminCapabilities> capabilities() => api.capabilities();
  Future<AdminPagedResponse<AdminAccount>> accounts(
          {int page = 1,
          int limit = 20,
          String? search,
          String? role,
          String status = 'all',
          String? from,
          String? to}) =>
      api.accounts(
          page: page,
          limit: limit,
          search: search,
          role: role,
          status: status,
          from: from,
          to: to);
  Future<AdminPagedResponse<AdminAuditEntry>> auditLogs({
    int page = 1,
    int limit = 30,
    String? search,
    String? requestId,
    String? from,
    String? to,
  }) =>
      api.auditLogs(
        page: page,
        limit: limit,
        search: search,
        requestId: requestId,
        from: from,
        to: to,
      );
  Future<AdminAnalytics> analytics({int days = 30}) =>
      api.analytics(days: days);
  Future<AdminPagedResponse<AdminQueueItem>> moderationQueue(
          {String kind = 'LISTING', int page = 1}) =>
      api.moderationQueue(kind: kind, page: page);

  Future<List<AdminLandlordSummary>> landlords(AdminLandlordsQuery query) =>
      api.listLandlords(query);

  Future<AdminLandlordRecord> createLandlord({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) =>
      api.createLandlord(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );

  Future<AdminLandlordDetail> landlord(String id) => api.getLandlord(id);

  Future<AdminLandlordRecord> updateLandlord(
    String id, {
    String? fullName,
    String? phone,
  }) =>
      api.updateLandlord(id, fullName: fullName, phone: phone);

  Future<AdminLandlordRecord> updateLandlordStatus(
    String id, {
    required bool isActive,
    String? reason,
    int? version,
    AdminStepUpPrompt? prompt,
  }) =>
      api.updateLandlordStatus(id,
          isActive: isActive, reason: reason, version: version, prompt: prompt);

  Future<AdminPagedResponse<AdminPropertySummary>> properties(
          AdminPropertiesQuery query) =>
      api.listProperties(query);

  Future<AdminPagedResponse<AdminRoomSummary>> rooms(AdminRoomsQuery query) =>
      api.rooms(query);

  Future<AdminPropertySummary> createProperty({
    required String landlordId,
    required String name,
    required String address,
  }) =>
      api.createProperty(
        landlordId: landlordId,
        name: name,
        address: address,
      );

  Future<AdminPropertyDetail> property(String id) => api.getProperty(id);

  Future<AdminPropertyDetail> updateProperty(
    String id, {
    String? name,
    String? address,
  }) =>
      api.updateProperty(id, name: name, address: address);
}
