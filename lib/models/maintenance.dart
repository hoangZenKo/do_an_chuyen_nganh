import 'package:flutter/material.dart';

enum MaintenanceStatus {
  open,
  inProgress,
  done,
  cancelled;

  String get wire => switch (this) {
        MaintenanceStatus.inProgress => 'in_progress',
        _ => name,
      };

  String get label => switch (this) {
        MaintenanceStatus.open => 'Mới báo',
        MaintenanceStatus.inProgress => 'Đang xử lý',
        MaintenanceStatus.done => 'Đã xong',
        MaintenanceStatus.cancelled => 'Đã hủy',
      };

  Color get color => switch (this) {
        MaintenanceStatus.open => const Color(0xFFF59E0B),
        MaintenanceStatus.inProgress => const Color(0xFF3B82F6),
        MaintenanceStatus.done => const Color(0xFF10B981),
        MaintenanceStatus.cancelled => const Color(0xFF8891A8),
      };

  IconData get icon => switch (this) {
        MaintenanceStatus.open => Icons.report_problem_rounded,
        MaintenanceStatus.inProgress => Icons.construction_rounded,
        MaintenanceStatus.done => Icons.check_circle_rounded,
        MaintenanceStatus.cancelled => Icons.cancel_rounded,
      };

  static MaintenanceStatus fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return MaintenanceStatus.values.firstWhere(
      (status) => status.wire == raw || status.name.toLowerCase() == raw,
      orElse: () => MaintenanceStatus.open,
    );
  }
}

enum MaintenancePriority {
  low,
  medium,
  urgent;

  String get label => switch (this) {
        MaintenancePriority.low => 'Thấp',
        MaintenancePriority.medium => 'Vừa',
        MaintenancePriority.urgent => 'Khẩn cấp',
      };

  Color get color => switch (this) {
        MaintenancePriority.low => const Color(0xFF10B981),
        MaintenancePriority.medium => const Color(0xFFF59E0B),
        MaintenancePriority.urgent => const Color(0xFFDC2626),
      };

  static MaintenancePriority fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return MaintenancePriority.values.firstWhere(
      (priority) => priority.name == raw,
      orElse: () => MaintenancePriority.medium,
    );
  }
}

class MaintenanceSummary {
  const MaintenanceSummary({
    required this.count,
    required this.openCount,
    required this.doneCount,
    required this.estimatedCost,
    required this.actualCost,
  });

  final int count;
  final int openCount;
  final int doneCount;
  final int estimatedCost;
  final int actualCost;

  factory MaintenanceSummary.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const MaintenanceSummary(
        count: 0,
        openCount: 0,
        doneCount: 0,
        estimatedCost: 0,
        actualCost: 0,
      );
    }
    return MaintenanceSummary(
      count: _int(json['count']),
      openCount: _int(json['openCount']),
      doneCount: _int(json['doneCount']),
      estimatedCost: _int(json['estimatedCost']),
      actualCost: _int(json['actualCost']),
    );
  }
}

class MaintenanceListResult {
  const MaintenanceListResult({required this.items, required this.summary});

  final List<MaintenanceTicket> items;
  final MaintenanceSummary summary;

  factory MaintenanceListResult.fromJson(Object? json) {
    if (json is List) {
      return MaintenanceListResult(
        items: json
            .whereType<Map<String, dynamic>>()
            .map(MaintenanceTicket.fromJson)
            .toList(growable: false),
        summary: MaintenanceSummary(
          count: json.length,
          openCount: 0,
          doneCount: 0,
          estimatedCost: 0,
          actualCost: 0,
        ),
      );
    }
    if (json is! Map<String, dynamic>) {
      return const MaintenanceListResult(
        items: [],
        summary: MaintenanceSummary(
          count: 0,
          openCount: 0,
          doneCount: 0,
          estimatedCost: 0,
          actualCost: 0,
        ),
      );
    }
    final raw = json['data'] is List ? json['data'] as List : const [];
    return MaintenanceListResult(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(MaintenanceTicket.fromJson)
          .toList(growable: false),
      summary: MaintenanceSummary.fromJson(json['summary']),
    );
  }
}

class MaintenanceTicket {
  const MaintenanceTicket({
    required this.id,
    required this.propertyId,
    required this.roomId,
    required this.status,
    required this.priority,
    required this.title,
    this.propertyName,
    this.roomName,
    this.description,
    this.reportedAt,
    this.startedAt,
    this.completedAt,
    this.estimatedCost,
    this.actualCost,
    this.note,
    this.imageUrls = const [],
    this.comments = const [],
    this.expenseId,
    this.expenseAmount,
    this.expenseDate,
    this.assigneeStaffProfileId,
    this.assigneeName,
    this.dueAt,
    this.escalatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String propertyId;
  final String? propertyName;
  final String roomId;
  final String? roomName;
  final MaintenanceStatus status;
  final MaintenancePriority priority;
  final String title;
  final String? description;
  final DateTime? reportedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? estimatedCost;
  final int? actualCost;
  final String? note;
  final List<String> imageUrls;
  final List<MaintenanceComment> comments;
  final String? expenseId;
  final int? expenseAmount;
  final DateTime? expenseDate;
  final String? assigneeStaffProfileId;
  final String? assigneeName;
  final DateTime? dueAt;
  final DateTime? escalatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDone => status == MaintenanceStatus.done;

  factory MaintenanceTicket.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return MaintenanceTicket(
      id: data['id'] as String,
      propertyId: data['propertyId'] as String? ?? '',
      propertyName: data['propertyName'] as String?,
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String?,
      status: MaintenanceStatus.fromWire(data['status']),
      priority: MaintenancePriority.fromWire(data['priority']),
      title: data['title'] as String? ?? 'Sửa chữa',
      description: data['description'] as String?,
      reportedAt: _date(data['reportedAt']),
      startedAt: _date(data['startedAt']),
      completedAt: _date(data['completedAt']),
      estimatedCost: _intOrNull(data['estimatedCost']),
      actualCost: _intOrNull(data['actualCost']),
      note: data['note'] as String?,
      imageUrls: data['imageUrls'] is List
          ? (data['imageUrls'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      comments: data['comments'] is List
          ? (data['comments'] as List)
              .whereType<Map<String, dynamic>>()
              .map(MaintenanceComment.fromJson)
              .toList(growable: false)
          : const [],
      expenseId: data['expenseId'] as String?,
      expenseAmount: _intOrNull(data['expenseAmount']),
      expenseDate: _date(data['expenseDate']),
      assigneeStaffProfileId: data['assigneeStaffProfileId'] as String?,
      assigneeName: data['assigneeName'] as String?,
      dueAt: _date(data['dueAt']),
      escalatedAt: _date(data['escalatedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }
}

class MaintenanceComment {
  const MaintenanceComment({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.authorRole,
    required this.body,
    this.authorName,
    this.imageUrls = const [],
    this.createdAt,
  });

  final String id;
  final String ticketId;
  final String authorId;
  final String? authorName;
  final String authorRole;
  final String body;
  final List<String> imageUrls;
  final DateTime? createdAt;

  factory MaintenanceComment.fromJson(Map<String, dynamic> json) {
    return MaintenanceComment(
      id: json['id'] as String? ?? '',
      ticketId: json['ticketId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String?,
      authorRole: json['authorRole'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrls: json['imageUrls'] is List
          ? (json['imageUrls'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      createdAt: _date(json['createdAt']),
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
