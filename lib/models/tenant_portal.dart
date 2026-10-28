import 'billing.dart';
import 'maintenance.dart';
import 'lease.dart' show DepositTransaction;

class TenantPortalLease {
  const TenantPortalLease({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.propertyId,
    required this.propertyName,
    required this.monthlyRent,
    this.status = 'active',
    this.propertyAddress,
    this.deposit = 0,
    this.depositBalance = 0,
    this.depositTransactions = const [],
    this.requiresHandover = false,
    this.handedOverAt,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String roomId;
  final String roomName;
  final String propertyId;
  final String propertyName;
  final String? propertyAddress;
  final int monthlyRent;
  final int deposit;
  final int depositBalance;
  final List<DepositTransaction> depositTransactions;
  final String status;
  final bool requiresHandover;
  final DateTime? handedOverAt;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isActive => status == 'active';
  String get occupancyLabel => !isActive
      ? 'Đã kết thúc'
      : requiresHandover && handedOverAt == null
          ? 'Chờ bàn giao'
          : 'Đang thuê';

  factory TenantPortalLease.fromJson(Map<String, dynamic> json) {
    return TenantPortalLease(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? 'Phòng',
      propertyId: json['propertyId'] as String? ?? '',
      propertyName: json['propertyName'] as String? ?? 'Khu trọ',
      propertyAddress: json['propertyAddress'] as String?,
      monthlyRent: _int(json['monthlyRent']),
      deposit: _int(json['deposit']),
      depositBalance: _int(json['depositBalance']),
      depositTransactions: (json['depositTransactions'] as List? ?? [])
          .map((entry) =>
              DepositTransaction.fromJson(entry as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'active',
      requiresHandover: json['requiresHandover'] == true,
      handedOverAt: _date(json['handedOverAt']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
    );
  }
}

class TenantPortalProfile {
  const TenantPortalProfile({
    required this.id,
    required this.fullName,
    required this.landlordId,
    required this.landlordName,
    this.phone,
    this.activeLease,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String landlordId;
  final String landlordName;
  final TenantPortalLease? activeLease;

  factory TenantPortalProfile.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final lease = data['activeLease'];
    return TenantPortalProfile(
      id: data['id'] as String? ?? '',
      fullName: data['fullName'] as String? ?? 'Khách thuê',
      phone: data['phone'] as String?,
      landlordId: data['landlordId'] as String? ?? '',
      landlordName: data['landlordName'] as String? ?? 'Chủ trọ',
      activeLease: lease is Map<String, dynamic>
          ? TenantPortalLease.fromJson(lease)
          : null,
    );
  }
}

class TenantDashboard {
  const TenantDashboard({
    required this.profile,
    required this.outstandingAmount,
    required this.openInvoiceCount,
    required this.overdueInvoiceCount,
    required this.dueSoonInvoiceCount,
    required this.openMaintenanceCount,
    required this.unreadNotificationCount,
    this.nextInvoice,
    this.recentMaintenance = const [],
  });

  final TenantPortalProfile profile;
  final int outstandingAmount;
  final int openInvoiceCount;
  final int overdueInvoiceCount;
  final int dueSoonInvoiceCount;
  final int openMaintenanceCount;
  final int unreadNotificationCount;
  final Invoice? nextInvoice;
  final List<MaintenanceTicket> recentMaintenance;

  factory TenantDashboard.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final profile = data['profile'] is Map<String, dynamic>
        ? TenantPortalProfile.fromJson(data['profile'] as Map<String, dynamic>)
        : TenantPortalProfile.fromJson(const <String, dynamic>{});
    final nextInvoice = data['nextInvoice'] is Map<String, dynamic>
        ? Invoice.fromJson(data['nextInvoice'] as Map<String, dynamic>)
        : null;
    final recentMaintenance = data['recentMaintenance'] is List
        ? (data['recentMaintenance'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MaintenanceTicket.fromJson)
            .toList(growable: false)
        : const <MaintenanceTicket>[];

    return TenantDashboard(
      profile: profile,
      outstandingAmount: _int(data['outstandingAmount']),
      openInvoiceCount: _int(data['openInvoiceCount']),
      overdueInvoiceCount: _int(data['overdueInvoiceCount']),
      dueSoonInvoiceCount: _int(data['dueSoonInvoiceCount']),
      openMaintenanceCount: _int(data['openMaintenanceCount']),
      unreadNotificationCount: _int(data['unreadNotificationCount']),
      nextInvoice: nextInvoice,
      recentMaintenance: recentMaintenance,
    );
  }
}

class TenantNotification {
  const TenantNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.invoiceId,
    this.maintenanceId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final String? invoiceId;
  final String? maintenanceId;
  final bool read;
  final DateTime? createdAt;

  factory TenantNotification.fromJson(Map<String, dynamic> json) {
    return TenantNotification(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'notification',
      title: json['title'] as String? ?? 'Thông báo',
      body: json['body'] as String? ?? '',
      invoiceId: json['invoiceId'] as String?,
      maintenanceId: json['maintenanceId'] as String?,
      read: json['read'] == true,
      createdAt: _date(json['createdAt']),
    );
  }
}

class PaymentProof {
  const PaymentProof({
    required this.id,
    required this.invoiceId,
    required this.tenantId,
    required this.amount,
    required this.method,
    required this.status,
    this.tenantName,
    this.roomName,
    this.billingMonth,
    this.note,
    this.proofImageUrls = const [],
    this.submittedAt,
    this.reviewedAt,
    this.reviewNote,
  });

  final String id;
  final String invoiceId;
  final String tenantId;
  final String? tenantName;
  final String? roomName;
  final DateTime? billingMonth;
  final int amount;
  final String method;
  final String status;
  final String? note;
  final List<String> proofImageUrls;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return PaymentProof(
      id: data['id'] as String? ?? '',
      invoiceId: data['invoiceId'] as String? ?? '',
      tenantId: data['tenantId'] as String? ?? '',
      tenantName: data['tenantName'] as String?,
      roomName: data['roomName'] as String?,
      billingMonth: _date(data['billingMonth']),
      amount: _int(data['amount']),
      method: data['method'] as String? ?? 'bank_transfer',
      status: data['status'] as String? ?? 'pending',
      note: data['note'] as String?,
      proofImageUrls: data['proofImageUrls'] is List
          ? (data['proofImageUrls'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      submittedAt: _date(data['submittedAt']),
      reviewedAt: _date(data['reviewedAt']),
      reviewNote: data['reviewNote'] as String?,
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
