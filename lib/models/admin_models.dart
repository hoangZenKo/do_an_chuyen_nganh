class AdminOverview {
  const AdminOverview({
    required this.generatedAt,
    required this.landlordsTotal,
    required this.landlordsActive,
    required this.landlordsInactive,
    required this.propertiesTotal,
    required this.roomsTotal,
    required this.tenantsTotal,
    required this.activeLeasesTotal,
    required this.recentLandlords,
    required this.recentProperties,
  });

  final DateTime? generatedAt;
  final int landlordsTotal;
  final int landlordsActive;
  final int landlordsInactive;
  final int propertiesTotal;
  final int roomsTotal;
  final int tenantsTotal;
  final int activeLeasesTotal;
  final List<AdminLandlordSummary> recentLandlords;
  final List<AdminPropertySummary> recentProperties;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    final landlords = _map(data['landlords']);
    final properties = _map(data['properties']);
    final rooms = _map(data['rooms']);
    final tenants = _map(data['tenants']);
    final leases = _map(data['leases']);
    return AdminOverview(
      generatedAt: _date(data['generatedAt']),
      landlordsTotal: _int(landlords['total']),
      landlordsActive: _int(landlords['active']),
      landlordsInactive: _int(landlords['inactive']),
      propertiesTotal: _int(properties['total']),
      roomsTotal: _int(rooms['total']),
      tenantsTotal: _int(tenants['total']),
      activeLeasesTotal: _int(leases['active']),
      recentLandlords: _list(data['recentLandlords'])
          .map(AdminLandlordSummary.fromJson)
          .toList(growable: false),
      recentProperties: _list(data['recentProperties'])
          .map(AdminPropertySummary.fromJson)
          .toList(growable: false),
    );
  }
}

class AdminCapabilities {
  const AdminCapabilities(this.permissions);
  final List<String> permissions;
  factory AdminCapabilities.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdminCapabilities((data['permissions'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false));
  }
  bool has(String permission) => permissions.contains(permission);
}

class AdminAccountsQuery {
  const AdminAccountsQuery(
      {this.page = 1,
      this.limit = 20,
      this.search,
      this.role,
      this.status = 'all',
      this.from,
      this.to});
  final int page;
  final int limit;
  final String? search;
  final String? role;
  final String status;
  final String? from, to;

  AdminAccountsQuery copyWith({
    int? page,
    String? search,
    String? role,
    String? status,
    String? from,
    String? to,
    bool clearRole = false,
    bool clearDates = false,
  }) =>
      AdminAccountsQuery(
        page: page ?? this.page,
        limit: limit,
        search: search ?? this.search,
        role: clearRole ? null : role ?? this.role,
        status: status ?? this.status,
        from: clearDates ? null : from ?? this.from,
        to: clearDates ? null : to ?? this.to,
      );
  @override
  bool operator ==(Object other) =>
      other is AdminAccountsQuery &&
      page == other.page &&
      limit == other.limit &&
      search == other.search &&
      role == other.role &&
      status == other.status &&
      from == other.from &&
      to == other.to;
  @override
  int get hashCode => Object.hash(page, limit, search, role, status, from, to);
}

class AdminPagedResponse<T> {
  const AdminPagedResponse(
      {required this.data,
      required this.page,
      required this.limit,
      required this.total,
      required this.pages});
  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final int pages;
  factory AdminPagedResponse.fromJson(
      Object? raw, T Function(Map<String, dynamic>) parse) {
    final envelope =
        raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>
            ? raw['data'] as Map<String, dynamic>
            : (raw is Map<String, dynamic> ? raw : const <String, dynamic>{});
    final list = raw is List
        ? raw
        : envelope['data'] is List
            ? envelope['data'] as List
            : raw is Map<String, dynamic> && raw['data'] is List
                ? raw['data'] as List
                : const [];
    final meta =
        raw is Map<String, dynamic> && raw['meta'] is Map<String, dynamic>
            ? raw['meta'] as Map<String, dynamic>
            : envelope['meta'] is Map<String, dynamic>
                ? envelope['meta'] as Map<String, dynamic>
                : const <String, dynamic>{};
    return AdminPagedResponse(
        data: list
            .whereType<Map<String, dynamic>>()
            .map(parse)
            .toList(growable: false),
        page: (meta['page'] as num?)?.toInt() ?? 1,
        limit: (meta['limit'] as num?)?.toInt() ?? list.length,
        total: (meta['total'] as num?)?.toInt() ?? list.length,
        pages: (meta['pages'] as num?)?.toInt() ?? 1);
  }
}

class AdminAccount {
  const AdminAccount(
      {required this.id,
      required this.fullName,
      required this.email,
      required this.role,
      required this.isActive,
      required this.createdAt,
      this.version = 0,
      this.phone,
      this.preset});
  final String id, fullName, email, role;
  final bool isActive;
  final int version;
  final DateTime? createdAt;
  final String? phone, preset;
  factory AdminAccount.fromJson(Map<String, dynamic> data) => AdminAccount(
      id: data['id'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      version: (data['version'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      phone: data['phone'] as String?,
      preset: data['preset'] as String?);
}

class AdminAuditEntry {
  const AdminAuditEntry(
      {required this.id,
      required this.action,
      required this.resourceType,
      required this.summary,
      this.createdAt});
  final String id, action, resourceType, summary;
  final DateTime? createdAt;
  factory AdminAuditEntry.fromJson(Map<String, dynamic> data) =>
      AdminAuditEntry(
          id: data['id'] as String? ?? '',
          action: data['action'] as String? ?? '',
          resourceType: data['resourceType'] as String? ?? '',
          summary: data['summary'] as String? ?? '',
          createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''));
}

class AdminQueueItem {
  const AdminQueueItem(
      {required this.id,
      required this.kind,
      required this.title,
      this.priority,
      this.dueAt});
  final String id, kind, title;
  final String? priority;
  final DateTime? dueAt;
  factory AdminQueueItem.fromJson(Map<String, dynamic> data) => AdminQueueItem(
      id: data['id']?.toString() ?? '',
      kind: data['kind']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      priority: data['priority']?.toString(),
      dueAt: DateTime.tryParse(data['dueAt']?.toString() ?? ''));
}

class AdminAnalytics {
  const AdminAnalytics(
      {required this.newAccounts,
      required this.newListings,
      required this.queue});
  final int newAccounts, newListings;
  final List<Map<String, dynamic>> queue;
  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdminAnalytics(
        newAccounts: (data['newAccounts'] as num?)?.toInt() ?? 0,
        newListings: (data['newListings'] as num?)?.toInt() ?? 0,
        queue: (data['queue'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false));
  }
}

class AdminLandlordSummary {
  const AdminLandlordSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.propertyCount,
    required this.roomCount,
    required this.occupiedCount,
    required this.tenantCount,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final bool isActive;
  final int propertyCount;
  final int roomCount;
  final int occupiedCount;
  final int tenantCount;

  factory AdminLandlordSummary.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return AdminLandlordSummary(
      id: data['id'] as String,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      isActive: _bool(data['isActive']),
      propertyCount: _int(data['propertyCount']),
      roomCount: _int(data['roomCount']),
      occupiedCount: _int(data['occupiedCount']),
      tenantCount: _int(data['tenantCount']),
    );
  }
}

class AdminLandlordRecord {
  const AdminLandlordRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.role,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final bool isActive;
  final String role;

  factory AdminLandlordRecord.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return AdminLandlordRecord(
      id: data['id'] as String,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      isActive: _bool(data['isActive']),
      role: data['role'] as String? ?? 'landlord',
    );
  }
}

class AdminLandlordDetail extends AdminLandlordSummary {
  const AdminLandlordDetail({
    required super.id,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.isActive,
    required super.propertyCount,
    required super.roomCount,
    required super.occupiedCount,
    required super.tenantCount,
    required this.activeLeaseCount,
    required this.recentProperties,
    this.version = 0,
  });

  final int version;
  final int activeLeaseCount;
  final List<AdminPropertySummary> recentProperties;

  factory AdminLandlordDetail.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return AdminLandlordDetail(
      id: data['id'] as String,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      isActive: _bool(data['isActive']),
      propertyCount: _int(data['propertyCount']),
      roomCount: _int(data['roomCount']),
      occupiedCount: _int(data['occupiedCount']),
      tenantCount: _int(data['tenantCount']),
      activeLeaseCount: _int(data['activeLeaseCount']),
      version: _int(data['version']),
      recentProperties: _list(data['recentProperties'])
          .map(AdminPropertySummary.fromJson)
          .toList(growable: false),
    );
  }
}

class AdminPropertySummary {
  const AdminPropertySummary({
    required this.id,
    required this.name,
    required this.address,
    required this.landlord,
    required this.roomCount,
    required this.occupiedCount,
    required this.vacantCount,
    this.isArchived = false,
    this.approvalStatus = 'NOT_SUBMITTED',
    this.approvalVersion = 0,
  });

  final String id;
  final String name;
  final String address;
  final AdminPropertyLandlord? landlord;
  final int roomCount;
  final int occupiedCount;
  final int vacantCount;
  final bool isArchived;
  final String approvalStatus;
  final int approvalVersion;

  factory AdminPropertySummary.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return AdminPropertySummary(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      landlord: data['landlord'] is Map<String, dynamic>
          ? AdminPropertyLandlord.fromJson(
              data['landlord'] as Map<String, dynamic>)
          : null,
      roomCount: _int(data['roomCount']),
      occupiedCount: _int(data['occupiedCount']),
      vacantCount: _int(data['vacantCount']),
      isArchived: _bool(data['isArchived']),
      approvalStatus:
          (data['approval'] as Map?)?['status'] as String? ?? 'NOT_SUBMITTED',
      approvalVersion: _int((data['approval'] as Map?)?['version']),
    );
  }
}

class AdminPropertyLandlord {
  const AdminPropertyLandlord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isActive,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final bool isActive;

  factory AdminPropertyLandlord.fromJson(Map<String, dynamic> json) {
    return AdminPropertyLandlord(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      isActive: _bool(json['isActive']),
    );
  }
}

class AdminPropertyDetail extends AdminPropertySummary {
  const AdminPropertyDetail({
    required super.id,
    required super.name,
    required super.address,
    required super.landlord,
    required super.roomCount,
    required super.occupiedCount,
    required super.vacantCount,
    super.isArchived,
    super.approvalStatus,
    super.approvalVersion,
    required this.rooms,
  });

  final List<AdminPropertyRoom> rooms;

  factory AdminPropertyDetail.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return AdminPropertyDetail(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      landlord: data['landlord'] is Map<String, dynamic>
          ? AdminPropertyLandlord.fromJson(
              data['landlord'] as Map<String, dynamic>)
          : null,
      roomCount: _int(data['roomCount']),
      occupiedCount: _int(data['occupiedCount']),
      vacantCount: _int(data['vacantCount']),
      rooms: _list(data['rooms'])
          .map(AdminPropertyRoom.fromJson)
          .toList(growable: false),
      isArchived: _bool(data['isArchived']),
      approvalStatus:
          (data['approval'] as Map?)?['status'] as String? ?? 'NOT_SUBMITTED',
      approvalVersion: _int((data['approval'] as Map?)?['version']),
    );
  }
}

class AdminPropertyRoom {
  const AdminPropertyRoom(
      {required this.id,
      required this.name,
      required this.status,
      this.floor,
      this.areaSqm,
      this.basePrice = 0,
      this.isActive = true,
      this.listing});

  final String id;
  final String name;
  final String status;
  final int? floor;
  final double? areaSqm;
  final int basePrice;
  final bool isActive;
  final AdminPropertyListing? listing;

  factory AdminPropertyRoom.fromJson(Map<String, dynamic> json) {
    return AdminPropertyRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Room',
      status: json['status'] as String? ?? 'vacant',
      floor: (json['floor'] as num?)?.toInt(),
      areaSqm: (json['areaSqm'] as num?)?.toDouble(),
      basePrice: _int(json['basePrice']),
      isActive: json['isActive'] != false,
      listing: json['listing'] is Map<String, dynamic>
          ? AdminPropertyListing.fromJson(
              json['listing'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AdminPropertyListing {
  const AdminPropertyListing(
      {required this.id,
      required this.title,
      required this.status,
      required this.version,
      required this.monthlyRent});
  final String id;
  final String title;
  final String status;
  final int version;
  final int monthlyRent;
  factory AdminPropertyListing.fromJson(Map<String, dynamic> json) =>
      AdminPropertyListing(
          id: json['id'] as String? ?? '',
          title: json['title'] as String? ?? '',
          status: json['status'] as String? ?? 'DRAFT',
          version: _int(json['version']),
          monthlyRent: _int(json['monthlyRent']));
}

class AdminLandlordsQuery {
  const AdminLandlordsQuery({this.search, this.status = 'all'});

  final String? search;
  final String status;

  Map<String, dynamic> toQuery() => {
        if (search != null && search!.trim().isNotEmpty)
          'search': search!.trim(),
        if (status.isNotEmpty) 'status': status,
      };

  @override
  bool operator ==(Object other) =>
      other is AdminLandlordsQuery &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(search, status);
}

class AdminPropertiesQuery {
  const AdminPropertiesQuery(
      {this.page = 1,
      this.limit = 20,
      this.search,
      this.landlordId,
      this.archived = 'all',
      this.ownerStatus = 'all'});
  final int page;
  final int limit;

  final String? search;
  final String? landlordId;
  final String archived;
  final String ownerStatus;

  Map<String, dynamic> toQuery() => {
        'page': page,
        'limit': limit,
        if (search != null && search!.trim().isNotEmpty)
          'search': search!.trim(),
        if (landlordId != null && landlordId!.isNotEmpty)
          'landlordId': landlordId,
        if (archived != 'all') 'archived': archived,
        if (ownerStatus != 'all') 'ownerStatus': ownerStatus,
      };

  @override
  bool operator ==(Object other) =>
      other is AdminPropertiesQuery &&
      other.page == page &&
      other.limit == limit &&
      other.search == search &&
      other.landlordId == landlordId &&
      other.archived == archived &&
      other.ownerStatus == ownerStatus;

  @override
  int get hashCode =>
      Object.hash(page, limit, search, landlordId, archived, ownerStatus);

  AdminPropertiesQuery copyWith(
          {int? page, String? search, String? archived, String? ownerStatus}) =>
      AdminPropertiesQuery(
          page: page ?? this.page,
          limit: limit,
          search: search ?? this.search,
          landlordId: landlordId,
          archived: archived ?? this.archived,
          ownerStatus: ownerStatus ?? this.ownerStatus);
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

bool _bool(Object? value) =>
    value is bool ? value : value?.toString() == 'true';

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
