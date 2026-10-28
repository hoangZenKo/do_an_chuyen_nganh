/// Reference to a tenant's currently active lease, for list display.
class ActiveLeaseRef {
  const ActiveLeaseRef({
    required this.id,
    required this.roomId,
    this.roomName,
    this.monthlyRent = 0,
  });

  final String id;
  final String roomId;
  final String? roomName;
  final int monthlyRent;

  factory ActiveLeaseRef.fromJson(Map<String, dynamic> json) {
    return ActiveLeaseRef(
      id: json['id'] as String,
      roomId: json['roomId'] as String? ?? '',
      roomName: json['roomName'] as String?,
      monthlyRent: _int(json['monthlyRent']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// A tenant profile owned by the signed-in landlord. Envelope-tolerant.
class Tenant {
  const Tenant({
    required this.id,
    required this.fullName,
    this.phone,
    this.idNumber,
    this.note,
    this.isActive = true,
    this.userId,
    this.accountEmail,
    this.activeLease,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? idNumber;
  final String? note;
  final bool isActive;
  final String? userId;
  final String? accountEmail;
  final ActiveLeaseRef? activeLease;

  factory Tenant.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final lease = data['activeLease'];
    return Tenant(
      id: data['id'] as String,
      fullName: data['fullName'] as String,
      phone: data['phone'] as String?,
      idNumber: data['idNumber'] as String?,
      note: data['note'] as String?,
      isActive: data['isActive'] != false,
      userId: data['userId'] as String?,
      accountEmail: data['accountEmail'] as String?,
      activeLease:
          lease is Map<String, dynamic> ? ActiveLeaseRef.fromJson(lease) : null,
    );
  }

  /// Payload for create/update. Server-owned fields are omitted.
  Map<String, dynamic> toPayload() => {
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (idNumber != null) 'idNumber': idNumber,
        if (note != null) 'note': note,
      };
}

class TenantOverview {
  const TenantOverview({
    required this.financial,
    required this.timeline,
    this.account,
  });

  final TenantFinancialSummary financial;
  final TenantAccountInfo? account;
  final List<TenantTimelineEvent> timeline;

  factory TenantOverview.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final timeline =
        data['timeline'] is List ? data['timeline'] as List : const [];
    return TenantOverview(
      financial: TenantFinancialSummary.fromJson(
        data['financial'] as Map<String, dynamic>? ?? const {},
      ),
      account: data['account'] is Map<String, dynamic>
          ? TenantAccountInfo.fromJson(data['account'] as Map<String, dynamic>)
          : null,
      timeline: timeline
          .whereType<Map<String, dynamic>>()
          .map(TenantTimelineEvent.fromJson)
          .toList(growable: false),
    );
  }
}

class TenantFinancialSummary {
  const TenantFinancialSummary({
    required this.invoiceCount,
    required this.totalBilled,
    required this.totalPaid,
    required this.outstandingAmount,
    required this.overdueAmount,
    required this.openInvoiceCount,
    required this.overdueInvoiceCount,
    required this.pendingProofCount,
    required this.depositBalance,
    required this.activeLeaseCount,
    required this.maintenanceOpenCount,
  });

  final int invoiceCount;
  final int totalBilled;
  final int totalPaid;
  final int outstandingAmount;
  final int overdueAmount;
  final int openInvoiceCount;
  final int overdueInvoiceCount;
  final int pendingProofCount;
  final int depositBalance;
  final int activeLeaseCount;
  final int maintenanceOpenCount;

  factory TenantFinancialSummary.fromJson(Map<String, dynamic> json) {
    return TenantFinancialSummary(
      invoiceCount: _int(json['invoiceCount']),
      totalBilled: _int(json['totalBilled']),
      totalPaid: _int(json['totalPaid']),
      outstandingAmount: _int(json['outstandingAmount']),
      overdueAmount: _int(json['overdueAmount']),
      openInvoiceCount: _int(json['openInvoiceCount']),
      overdueInvoiceCount: _int(json['overdueInvoiceCount']),
      pendingProofCount: _int(json['pendingProofCount']),
      depositBalance: _int(json['depositBalance']),
      activeLeaseCount: _int(json['activeLeaseCount']),
      maintenanceOpenCount: _int(json['maintenanceOpenCount']),
    );
  }
}

class TenantAccountInfo {
  const TenantAccountInfo({
    required this.id,
    required this.email,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String email;
  final bool isActive;
  final DateTime? createdAt;

  factory TenantAccountInfo.fromJson(Map<String, dynamic> json) {
    return TenantAccountInfo(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isActive: json['isActive'] != false,
      createdAt: _date(json['createdAt']),
    );
  }
}

class TenantTimelineEvent {
  const TenantTimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.occurredAt,
    this.amount,
    this.status,
    this.roomName,
    this.resourceId,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final DateTime? occurredAt;
  final int? amount;
  final String? status;
  final String? roomName;
  final String? resourceId;

  factory TenantTimelineEvent.fromJson(Map<String, dynamic> json) {
    return TenantTimelineEvent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? 'Sự kiện',
      description: json['description'] as String? ?? '',
      occurredAt: _date(json['occurredAt']),
      amount: _intOrNull(json['amount']),
      status: json['status'] as String?,
      roomName: json['roomName'] as String?,
      resourceId: json['resourceId'] as String?,
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
