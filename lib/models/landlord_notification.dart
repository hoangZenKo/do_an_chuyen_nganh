class LandlordNotification {
  const LandlordNotification({
    required this.id,
    required this.kind,
    this.category = '',
    required this.severity,
    required this.title,
    required this.body,
    required this.resourceType,
    required this.resourceId,
    required this.actionRoute,
    required this.isRead,
    this.propertyId,
    this.propertyName,
    this.dueAt,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String category;
  final String severity;
  final String title;
  final String body;
  final String resourceType;
  final String resourceId;
  final String actionRoute;
  final bool isRead;
  final String? propertyId;
  final String? propertyName;
  final DateTime? dueAt;
  final DateTime? createdAt;

  factory LandlordNotification.fromJson(Map<String, dynamic> json) {
    return LandlordNotification(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      category: json['category'] as String? ?? _categoryFromKind(json['kind']),
      severity: json['severity'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      resourceType: json['resourceType'] as String? ?? '',
      resourceId: json['resourceId'] as String? ?? '',
      actionRoute: json['actionRoute'] as String? ?? '',
      isRead: json['isRead'] == true,
      propertyId: json['propertyId'] as String?,
      propertyName: json['propertyName'] as String?,
      dueAt: _date(json['dueAt']),
      createdAt: _date(json['createdAt']),
    );
  }
}

class NotificationSummary {
  const NotificationSummary({required this.total, required this.unread});

  final int total;
  final int unread;

  factory NotificationSummary.fromJson(Map<String, dynamic> json) {
    return NotificationSummary(
      total: _int(json['total']),
      unread: _int(json['unread']),
    );
  }
}

class NotificationBundle {
  const NotificationBundle({required this.items, required this.summary});

  final List<LandlordNotification> items;
  final NotificationSummary summary;

  factory NotificationBundle.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] is List ? json['data'] as List : const [];
    return NotificationBundle(
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(LandlordNotification.fromJson)
          .toList(growable: false),
      summary: NotificationSummary.fromJson(
        json['summary'] is Map<String, dynamic>
            ? json['summary'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}

class ActionItems {
  const ActionItems({
    required this.summary,
    required this.items,
    required this.meta,
    this.categories = const <String>[],
  });

  final ActionItemsSummary summary;
  final List<LandlordNotification> items;
  final ActionItemsMeta meta;
  final List<String> categories;

  factory ActionItems.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final raw = data['items'] is List ? data['items'] as List : const [];
    return ActionItems(
      summary: ActionItemsSummary.fromJson(
        data['summary'] is Map<String, dynamic>
            ? data['summary'] as Map<String, dynamic>
            : const {},
      ),
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(LandlordNotification.fromJson)
          .toList(growable: false),
      meta: ActionItemsMeta.fromJson(
        json['meta'] is Map<String, dynamic>
            ? json['meta'] as Map<String, dynamic>
            : const {},
      ),
      categories:
          (data['categories'] is List ? data['categories'] as List : const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class ActionItemsMeta {
  const ActionItemsMeta({
    required this.total,
    required this.page,
    required this.limit,
  });

  final int total;
  final int page;
  final int limit;

  bool get hasNext => page * limit < total;

  factory ActionItemsMeta.fromJson(Map<String, dynamic> json) {
    return ActionItemsMeta(
      total: _int(json['total']),
      page: _int(json['page']) == 0 ? 1 : _int(json['page']),
      limit: _int(json['limit']) == 0 ? 20 : _int(json['limit']),
    );
  }
}

class ActionItemsSummary {
  const ActionItemsSummary({
    required this.total,
    required this.unread,
    required this.overdueInvoices,
    required this.dueSoonInvoices,
    required this.pendingPaymentProofs,
    required this.pendingViewings,
    required this.urgentMaintenance,
    required this.openMaintenance,
    required this.expiringLeases,
    required this.dueInspections,
  });

  final int total;
  final int unread;
  final int overdueInvoices;
  final int dueSoonInvoices;
  final int pendingPaymentProofs;
  final int pendingViewings;
  final int urgentMaintenance;
  final int openMaintenance;
  final int expiringLeases;
  final int dueInspections;

  factory ActionItemsSummary.fromJson(Map<String, dynamic> json) {
    return ActionItemsSummary(
      total: _int(json['total']),
      unread: _int(json['unread']),
      overdueInvoices: _int(json['overdueInvoices']),
      dueSoonInvoices: _int(json['dueSoonInvoices']),
      pendingPaymentProofs: _int(json['pendingPaymentProofs']),
      pendingViewings: _int(json['pendingViewings']),
      urgentMaintenance: _int(json['urgentMaintenance']),
      openMaintenance: _int(json['openMaintenance']),
      expiringLeases: _int(json['expiringLeases']),
      dueInspections: _int(json['dueInspections']),
    );
  }
}

String _categoryFromKind(Object? value) {
  final kind = value?.toString() ?? '';
  if (kind.startsWith('viewing')) return 'viewing';
  if (kind.startsWith('payment')) return 'payment';
  if (kind.startsWith('invoice')) return 'invoice';
  if (kind.startsWith('maintenance')) return 'maintenance';
  if (kind.startsWith('lease')) return 'lease';
  if (kind.startsWith('room_inspection')) return 'inspection';
  return 'other';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
