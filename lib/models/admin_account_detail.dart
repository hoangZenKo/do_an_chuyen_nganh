import 'admin_models.dart';

class AdminAccountDetail {
  const AdminAccountDetail(
      {required this.account,
      required this.properties,
      required this.tenants,
      required this.history,
      this.staffLandlordId,
      this.tenantProfileId});

  final AdminAccount account;
  final int properties, tenants;
  final List<AdminAuditEntry> history;
  final String? staffLandlordId, tenantProfileId;

  factory AdminAccountDetail.fromJson(Map<String, dynamic> data) {
    final counts = data['counts'] as Map? ?? const {};
    return AdminAccountDetail(
        account: AdminAccount.fromJson(data),
        properties: (counts['properties'] as num?)?.toInt() ?? 0,
        tenants: (counts['tenants'] as num?)?.toInt() ?? 0,
        staffLandlordId:
            (data['staffProfile'] as Map?)?['landlordId'] as String?,
        tenantProfileId: (data['tenantProfile'] as Map?)?['id'] as String?,
        history: (data['history'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminAuditEntry.fromJson)
            .toList(growable: false));
  }
}

class AdminAccountContacts {
  const AdminAccountContacts({required this.email, this.phone});
  final String email;
  final String? phone;
  factory AdminAccountContacts.fromJson(Map<String, dynamic> data) =>
      AdminAccountContacts(
          email: data['email'] as String, phone: data['phone'] as String?);
}
