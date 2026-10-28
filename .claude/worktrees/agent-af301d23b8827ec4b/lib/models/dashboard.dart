import 'billing.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.propertyId,
    required this.generatedAt,
    required this.roomStats,
    required this.leaseStats,
    required this.currentMonth,
    required this.revenueTrend,
    required this.attentionItems,
    required this.recentInvoices,
  });

  final String? propertyId;
  final DateTime? generatedAt;
  final DashboardRoomStats roomStats;
  final DashboardLeaseStats leaseStats;
  final DashboardCurrentMonth currentMonth;
  final List<RevenuePoint> revenueTrend;
  final List<DashboardAttentionItem> attentionItems;
  final List<DashboardRecentInvoice> recentInvoices;

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return DashboardMetrics(
      propertyId: data['propertyId'] as String?,
      generatedAt: _date(data['generatedAt']),
      roomStats: DashboardRoomStats.fromJson(_map(data['roomStats'])),
      leaseStats: DashboardLeaseStats.fromJson(_map(data['leaseStats'])),
      currentMonth: DashboardCurrentMonth.fromJson(_map(data['currentMonth'])),
      revenueTrend: _list(data['revenueTrend'])
          .map(RevenuePoint.fromJson)
          .toList(growable: false),
      attentionItems: _list(data['attentionItems'])
          .map(DashboardAttentionItem.fromJson)
          .toList(growable: false),
      recentInvoices: _list(data['recentInvoices'])
          .map(DashboardRecentInvoice.fromJson)
          .toList(growable: false),
    );
  }
}

class DashboardRoomStats {
  const DashboardRoomStats({
    required this.total,
    required this.occupied,
    required this.vacant,
    required this.maintenance,
    required this.occupancyRate,
  });

  final int total;
  final int occupied;
  final int vacant;
  final int maintenance;
  final int occupancyRate;

  factory DashboardRoomStats.fromJson(Map<String, dynamic> json) {
    return DashboardRoomStats(
      total: _int(json['total']),
      occupied: _int(json['occupied']),
      vacant: _int(json['vacant']),
      maintenance: _int(json['maintenance']),
      occupancyRate: _int(json['occupancyRate']),
    );
  }
}

class DashboardLeaseStats {
  const DashboardLeaseStats({required this.active});

  final int active;

  factory DashboardLeaseStats.fromJson(Map<String, dynamic> json) {
    return DashboardLeaseStats(active: _int(json['active']));
  }
}

class DashboardCurrentMonth {
  const DashboardCurrentMonth({
    required this.invoiceCount,
    required this.billedAmount,
    required this.receivedAmount,
    required this.outstandingInvoiceCount,
    required this.outstandingAmount,
  });

  final int invoiceCount;
  final int billedAmount;
  final int receivedAmount;
  final int outstandingInvoiceCount;
  final int outstandingAmount;

  factory DashboardCurrentMonth.fromJson(Map<String, dynamic> json) {
    return DashboardCurrentMonth(
      invoiceCount: _int(json['invoiceCount']),
      billedAmount: _int(json['billedAmount']),
      receivedAmount: _int(json['receivedAmount']),
      outstandingInvoiceCount: _int(json['outstandingInvoiceCount']),
      outstandingAmount: _int(json['outstandingAmount']),
    );
  }
}

class RevenuePoint {
  const RevenuePoint({required this.month, required this.amount});

  final DateTime? month;
  final int amount;

  factory RevenuePoint.fromJson(Map<String, dynamic> json) {
    return RevenuePoint(
      month: _date(json['month']),
      amount: _int(json['amount']),
    );
  }
}

enum DashboardAttentionKind {
  overdueInvoice,
  dueSoonInvoice,
  maintenanceRoom;

  static DashboardAttentionKind fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return switch (raw) {
      'due_soon_invoice' => DashboardAttentionKind.dueSoonInvoice,
      'maintenance_room' => DashboardAttentionKind.maintenanceRoom,
      _ => DashboardAttentionKind.overdueInvoice,
    };
  }
}

class DashboardAttentionItem {
  const DashboardAttentionItem({
    required this.kind,
    required this.roomId,
    required this.roomName,
    this.tenantId,
    this.tenantName,
    this.invoiceId,
    this.remainingAmount = 0,
    this.dueDate,
    this.propertyId,
    this.propertyName,
    this.updatedAt,
  });

  final DashboardAttentionKind kind;
  final String roomId;
  final String roomName;
  final String? tenantId;
  final String? tenantName;
  final String? invoiceId;
  final int remainingAmount;
  final DateTime? dueDate;
  final String? propertyId;
  final String? propertyName;
  final DateTime? updatedAt;

  factory DashboardAttentionItem.fromJson(Map<String, dynamic> json) {
    return DashboardAttentionItem(
      kind: DashboardAttentionKind.fromWire(json['kind']),
      roomId: json['roomId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? 'Phòng',
      tenantId: json['tenantId'] as String?,
      tenantName: json['tenantName'] as String?,
      invoiceId: json['invoiceId'] as String?,
      remainingAmount: _int(json['remainingAmount']),
      dueDate: _date(json['dueDate']),
      propertyId: json['propertyId'] as String?,
      propertyName: json['propertyName'] as String?,
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class DashboardRecentInvoice {
  const DashboardRecentInvoice({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.tenantId,
    required this.tenantName,
    required this.billingMonth,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.dueDate,
    this.issuedAt,
  });

  final String id;
  final String roomId;
  final String roomName;
  final String tenantId;
  final String? tenantName;
  final DateTime? billingMonth;
  final int totalAmount;
  final int paidAmount;
  final int remainingAmount;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final DateTime? issuedAt;

  factory DashboardRecentInvoice.fromJson(Map<String, dynamic> json) {
    return DashboardRecentInvoice(
      id: json['id'] as String,
      roomId: json['roomId'] as String? ?? '',
      roomName: json['roomName'] as String? ?? 'Phòng',
      tenantId: json['tenantId'] as String? ?? '',
      tenantName: json['tenantName'] as String?,
      billingMonth: _date(json['billingMonth']),
      totalAmount: _int(json['totalAmount']),
      paidAmount: _int(json['paidAmount']),
      remainingAmount: _int(json['remainingAmount']),
      status: InvoiceStatus.fromWire(json['status']),
      dueDate: _date(json['dueDate']),
      issuedAt: _date(json['issuedAt']),
    );
  }
}

Map<String, dynamic> _envelope(Map<String, dynamic> json) =>
    json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) {
  final raw = value is List ? value : const <Object?>[];
  return raw.whereType<Map<String, dynamic>>().toList(growable: false);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
