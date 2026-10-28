class LandlordUser {
  const LandlordUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role = 'landlord',
    this.landlordId,
    this.preset,
    this.permissions = const [],
    this.propertyIds = const [],
    this.adminMfaEnabled = false,
    this.adminMfaRequired = false,
    this.adminMfaVerified = false,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String? landlordId;
  final String? preset;
  final List<String> permissions;
  final List<String> propertyIds;
  final bool adminMfaEnabled;
  final bool adminMfaRequired;
  final bool adminMfaVerified;

  factory LandlordUser.fromJson(Map<String, dynamic> json) {
    return LandlordUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'landlord',
      landlordId: json['landlordId'] as String?,
      preset: json['preset'] as String?,
      propertyIds: (json['propertyIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      adminMfaEnabled: json['adminMfaEnabled'] == true,
      adminMfaRequired: json['adminMfaRequired'] == true,
      adminMfaVerified: json['adminMfaVerified'] == true,
      permissions: json['permissions'] is List
          ? (json['permissions'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
  });

  final LandlordUser user;
  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;
  final DateTime? refreshTokenExpiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AuthSession(
      user: LandlordUser.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      accessTokenExpiresAt: _date(data['accessTokenExpiresAt']),
      refreshTokenExpiresAt: _date(data['refreshTokenExpiresAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'user': {
          'id': user.id,
          'fullName': user.fullName,
          'email': user.email,
          'phone': user.phone,
          'role': user.role,
          'landlordId': user.landlordId,
          'preset': user.preset,
          'propertyIds': user.propertyIds,
          'permissions': user.permissions,
          'adminMfaEnabled': user.adminMfaEnabled,
          'adminMfaRequired': user.adminMfaRequired,
          'adminMfaVerified': user.adminMfaVerified,
        },
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
        'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
      };

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
