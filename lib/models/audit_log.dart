class AuditLog {
  const AuditLog({
    required this.id,
    required this.actorRole,
    required this.action,
    required this.resourceType,
    required this.summary,
    this.landlordId,
    this.actorId,
    this.actor,
    this.resourceId,
    this.metadata,
    this.createdAt,
  });

  final String id;
  final String? landlordId;
  final String? actorId;
  final String actorRole;
  final AuditActor? actor;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String summary;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AuditLog(
      id: data['id'] as String? ?? '',
      landlordId: data['landlordId'] as String?,
      actorId: data['actorId'] as String?,
      actorRole: data['actorRole']?.toString().toLowerCase() ?? 'landlord',
      actor: data['actor'] is Map<String, dynamic>
          ? AuditActor.fromJson(data['actor'] as Map<String, dynamic>)
          : null,
      action: data['action'] as String? ?? '',
      resourceType: data['resourceType'] as String? ?? '',
      resourceId: data['resourceId'] as String?,
      summary: data['summary'] as String? ?? '',
      metadata: data['metadata'] is Map<String, dynamic>
          ? data['metadata'] as Map<String, dynamic>
          : null,
      createdAt: _date(data['createdAt']),
    );
  }
}

class AuditActor {
  const AuditActor({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;

  factory AuditActor.fromJson(Map<String, dynamic> json) {
    return AuditActor(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Người dùng',
      email: json['email'] as String? ?? '',
      role: json['role']?.toString().toLowerCase() ?? '',
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
