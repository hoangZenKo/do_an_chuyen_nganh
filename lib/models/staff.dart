class StaffMember {
  const StaffMember({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.permissions,
    required this.isActive,
    this.email,
    this.phone,
    this.preset,
    this.createdAt,
    this.updatedAt,
    this.propertyIds = const [],
  });

  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? preset;
  final List<String> permissions;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> propertyIds;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return StaffMember(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      fullName: data['fullName'] as String? ?? 'Nhân viên',
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      preset: data['preset'] as String?,
      permissions: data['permissions'] is List
          ? (data['permissions'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      isActive: data['isActive'] != false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      propertyIds: (data['propertyIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

class StaffInvite {
  const StaffInvite({
    required this.id,
    required this.email,
    required this.fullName,
    required this.permissions,
    this.phone,
    this.preset,
    this.inviteCode,
    this.activationPath,
    this.expiresAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? preset;
  final List<String> permissions;
  final String? inviteCode;
  final String? activationPath;
  final DateTime? expiresAt;

  factory StaffInvite.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return StaffInvite(
      id: data['id'] as String? ?? '',
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      phone: data['phone'] as String?,
      preset: data['preset'] as String?,
      permissions: data['permissions'] is List
          ? (data['permissions'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      inviteCode: data['inviteCode'] as String?,
      activationPath: data['activationPath'] as String?,
      expiresAt: _date(data['expiresAt']),
    );
  }
}

class StaffPreset {
  const StaffPreset({required this.preset, required this.permissions});

  final String preset;
  final List<String> permissions;

  String get label => switch (preset) {
        'operator' => 'Quản lý vận hành',
        'accountant' => 'Kế toán',
        'maintenance' => 'Bảo trì',
        'viewer' => 'Chỉ xem',
        'custom' => 'Tùy chỉnh',
        _ => preset,
      };

  factory StaffPreset.fromJson(Map<String, dynamic> json) {
    return StaffPreset(
      preset: json['preset'] as String? ?? 'viewer',
      permissions: json['permissions'] is List
          ? (json['permissions'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
