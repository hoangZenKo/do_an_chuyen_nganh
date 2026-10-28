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
  });

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
  });

  final String id;
  final String name;
  final String address;
  final AdminPropertyLandlord? landlord;
  final int roomCount;
  final int occupiedCount;
  final int vacantCount;

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
    );
  }
}

class AdminPropertyRoom {
  const AdminPropertyRoom(
      {required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status;

  factory AdminPropertyRoom.fromJson(Map<String, dynamic> json) {
    return AdminPropertyRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Room',
      status: json['status'] as String? ?? 'vacant',
    );
  }
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
  const AdminPropertiesQuery({this.search, this.landlordId});

  final String? search;
  final String? landlordId;

  Map<String, dynamic> toQuery() => {
        if (search != null && search!.trim().isNotEmpty)
          'search': search!.trim(),
        if (landlordId != null && landlordId!.isNotEmpty)
          'landlordId': landlordId,
      };

  @override
  bool operator ==(Object other) =>
      other is AdminPropertiesQuery &&
      other.search == search &&
      other.landlordId == landlordId;

  @override
  int get hashCode => Object.hash(search, landlordId);
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
