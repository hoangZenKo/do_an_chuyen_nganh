import '../../models/admin_models.dart';
import 'admin_api.dart';

class AdminRepository {
  const AdminRepository({required this.api});

  final AdminApi api;

  Future<AdminOverview> overview() => api.overview();

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
  }) =>
      api.updateLandlordStatus(id, isActive: isActive);

  Future<List<AdminPropertySummary>> properties(AdminPropertiesQuery query) =>
      api.listProperties(query);

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
