import 'package:flutter/material.dart';

/// State of a lease contract.
enum LeaseStatus {
  active,
  ended;

  String get wire => name;

  String get label => switch (this) {
        LeaseStatus.active => 'Đang hiệu lực',
        LeaseStatus.ended => 'Đã kết thúc',
      };

  Color get color => switch (this) {
        LeaseStatus.active => const Color(0xFF10B981),
        LeaseStatus.ended => const Color(0xFF9CA3AF),
      };

  static LeaseStatus fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return LeaseStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => LeaseStatus.ended,
    );
  }
}

/// A lease contract linking a [Tenant] to a room, with denormalized room/tenant
/// names for display. Envelope-tolerant like the other models.
class Lease {
  const Lease({
    required this.id,
    required this.roomId,
    required this.tenantId,
    required this.status,
    required this.monthlyRent,
    this.deposit = 0,
    this.depositBalance = 0,
    this.depositTransactions = const [],
    this.changes = const [],
    this.roomName,
    this.tenantName,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String roomId;
  final String tenantId;
  final LeaseStatus status;
  final int monthlyRent;
  final int deposit;
  final int depositBalance;
  final List<DepositTransaction> depositTransactions;
  final List<LeaseChange> changes;
  final String? roomName;
  final String? tenantName;
  final DateTime? startDate;
  final DateTime? endDate;

  factory Lease.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return Lease(
      id: data['id'] as String,
      roomId: data['roomId'] as String? ?? '',
      tenantId: data['tenantId'] as String? ?? '',
      status: LeaseStatus.fromWire(data['status']),
      monthlyRent: _int(data['monthlyRent']),
      deposit: _int(data['deposit']),
      depositBalance: _int(data['depositBalance']),
      depositTransactions: data['depositTransactions'] is List
          ? (data['depositTransactions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(DepositTransaction.fromJson)
              .toList(growable: false)
          : const [],
      changes: data['changes'] is List
          ? (data['changes'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LeaseChange.fromJson)
              .toList(growable: false)
          : const [],
      roomName: data['roomName'] as String?,
      tenantName: data['tenantName'] as String?,
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class DepositTransaction {
  const DepositTransaction({
    required this.id,
    required this.leaseId,
    required this.type,
    required this.amount,
    this.occurredAt,
    this.note,
    this.createdAt,
  });

  final String id;
  final String leaseId;
  final String type;
  final int amount;
  final DateTime? occurredAt;
  final String? note;
  final DateTime? createdAt;

  String get label => switch (type) {
        'collected' => 'Thu cọc',
        'refunded' => 'Hoàn cọc',
        'deducted' => 'Khấu trừ',
        'adjustment' => 'Điều chỉnh',
        _ => type,
      };

  factory DepositTransaction.fromJson(Map<String, dynamic> json) {
    return DepositTransaction(
      id: json['id'] as String? ?? '',
      leaseId: json['leaseId'] as String? ?? '',
      type: json['type'] as String? ?? 'collected',
      amount: Lease._int(json['amount']),
      occurredAt: Lease._date(json['occurredAt']),
      note: json['note'] as String?,
      createdAt: Lease._date(json['createdAt']),
    );
  }
}

class LeaseChange {
  const LeaseChange({
    required this.id,
    required this.changeType,
    this.note,
    this.createdAt,
  });

  final String id;
  final String changeType;
  final String? note;
  final DateTime? createdAt;

  factory LeaseChange.fromJson(Map<String, dynamic> json) {
    return LeaseChange(
      id: json['id'] as String? ?? '',
      changeType: json['changeType'] as String? ?? 'update',
      note: json['note'] as String?,
      createdAt: Lease._date(json['createdAt']),
    );
  }
}

class ExpiringLease {
  const ExpiringLease({
    required this.id,
    required this.roomId,
    required this.tenantId,
    required this.monthlyRent,
    required this.deposit,
    this.roomName,
    this.propertyName,
    this.tenantName,
    this.tenantPhone,
    this.startDate,
    this.endDate,
    this.daysUntilEnd,
  });

  final String id;
  final String roomId;
  final String tenantId;
  final String? roomName;
  final String? propertyName;
  final String? tenantName;
  final String? tenantPhone;
  final DateTime? startDate;
  final DateTime? endDate;
  final int monthlyRent;
  final int deposit;
  final int? daysUntilEnd;

  factory ExpiringLease.fromJson(Map<String, dynamic> json) {
    return ExpiringLease(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      roomName: json['roomName'] as String?,
      propertyName: json['propertyName'] as String?,
      tenantName: json['tenantName'] as String?,
      tenantPhone: json['tenantPhone'] as String?,
      startDate: Lease._date(json['startDate']),
      endDate: Lease._date(json['endDate']),
      monthlyRent: Lease._int(json['monthlyRent']),
      deposit: Lease._int(json['deposit']),
      daysUntilEnd: json['daysUntilEnd'] == null
          ? null
          : Lease._int(json['daysUntilEnd']),
    );
  }
}
