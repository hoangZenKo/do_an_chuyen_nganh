import '../../models/staff.dart';
import 'staff_api.dart';

class StaffRepository {
  const StaffRepository(this._api);

  final StaffApi _api;

  Future<List<StaffMember>> list() => _api.list();

  Future<List<StaffPreset>> presets() => _api.presets();

  Future<StaffInvite> createInvite({
    required String email,
    required String fullName,
    String? phone,
    String preset = 'viewer',
    List<String> permissions = const [],
    List<String> propertyIds = const [],
  }) {
    return _api.createInvite({
      'email': email.trim(),
      'fullName': fullName.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'preset': preset,
      if (permissions.isNotEmpty) 'permissions': permissions,
      'propertyIds': propertyIds,
    });
  }

  Future<StaffMember> setActive(String id, bool isActive) {
    return _api.update(id, {'isActive': isActive});
  }
}
