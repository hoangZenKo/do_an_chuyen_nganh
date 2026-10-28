class AdminWorkspaceItem {
  const AdminWorkspaceItem(
      {required this.key,
      required this.label,
      required this.route,
      required this.permission,
      required this.priority,
      required this.count,
      required this.available,
      this.actionPath});

  final String key, label, route, permission;
  final int priority;
  final int? count;
  final bool available;
  final String? actionPath;
  String get destination {
    final target = Uri.tryParse(actionPath ?? route);
    return target != null &&
            !target.hasScheme &&
            !target.hasAuthority &&
            target.path == route &&
            !target.hasFragment
        ? target.toString()
        : route;
  }

  factory AdminWorkspaceItem.fromJson(Map json) => AdminWorkspaceItem(
        key: '${json['key'] ?? ''}',
        label: '${json['label'] ?? ''}',
        route: '${json['route'] ?? ''}',
        permission: '${json['permission'] ?? ''}',
        priority: (json['priority'] as num?)?.toInt() ?? 4,
        count: (json['pendingCount'] as num?)?.toInt(),
        available: json['status'] == 'OK',
        actionPath: json['actionPath'] as String?,
      );
}

class AdminWorkspaceSummary {
  const AdminWorkspaceSummary(
      {required this.items,
      required this.updatedAt,
      required this.partial,
      required this.pendingCount,
      required this.unreadCount});

  final List<AdminWorkspaceItem> items;
  final DateTime? updatedAt;
  final bool partial;
  final int pendingCount;
  final int? unreadCount;

  factory AdminWorkspaceSummary.fromJson(Map<String, dynamic> response) {
    final data = response['data'] as Map? ?? const {};
    return AdminWorkspaceSummary(
      items: (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map(AdminWorkspaceItem.fromJson)
          .toList(growable: false),
      updatedAt: DateTime.tryParse('${data['lastUpdatedAt']}'),
      partial: data['dataFreshness'] == 'PARTIAL',
      pendingCount: (data['pendingCount'] as num?)?.toInt() ?? 0,
      unreadCount: (data['unreadNotificationCount'] as num?)?.toInt(),
    );
  }

  int? countFor(String route) {
    final rows = items.where((item) => item.route == route);
    if (rows.isEmpty || rows.any((item) => !item.available)) return null;
    return rows.fold<int>(0, (total, item) => total + (item.count ?? 0));
  }
}
