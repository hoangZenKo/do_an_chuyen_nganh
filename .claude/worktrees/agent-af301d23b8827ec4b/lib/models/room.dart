import 'package:flutter/material.dart';

/// Occupancy state of a room. Colors mirror the dashboard badges in
/// `dashboard_screen.dart` (teal / amber / indigo) so the app reads as one
/// system.
enum RoomStatus {
  occupied,
  vacant,
  maintenance;

  /// Wire value exchanged with the backend.
  String get wire => name;

  String get label => switch (this) {
        RoomStatus.occupied => 'Đang thuê',
        RoomStatus.vacant => 'Phòng trống',
        RoomStatus.maintenance => 'Bảo trì',
      };

  Color get color => switch (this) {
        RoomStatus.occupied => const Color(0xFF0D6E62),
        RoomStatus.vacant => const Color(0xFFF59E0B),
        RoomStatus.maintenance => const Color(0xFF6366F1),
      };

  static RoomStatus fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return RoomStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => RoomStatus.vacant,
    );
  }
}

/// A single rentable room belonging to a [Property].
///
/// Like [Property], the parser accepts either a bare object or a
/// `{ "data": { ... } }` envelope.
class Room {
  const Room({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.status,
    this.floor,
    this.areaSqm,
    this.basePrice = 0,
    this.isActive = true,
    this.capacity,
    this.amenities = const [],
    this.imageUrl,
    this.tenantName,
    this.note,
  });

  final String id;
  final String propertyId;
  final String name;
  final RoomStatus status;
  final bool isActive;
  final int? floor;
  final double? areaSqm;
  final int basePrice;
  final int? capacity;
  final List<String> amenities;
  final String? imageUrl;

  /// Denormalized current tenant name for list display; null when vacant.
  final String? tenantName;
  final String? note;

  factory Room.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return Room(
      id: data['id'] as String,
      propertyId: data['propertyId'] as String? ?? '',
      name: data['name'] as String,
      status: RoomStatus.fromWire(data['status']),
      isActive: data['isActive'] != false,
      floor: _intOrNull(data['floor']),
      areaSqm: _doubleOrNull(data['areaSqm']),
      basePrice: _int(data['basePrice']),
      capacity: _intOrNull(data['capacity']),
      amenities: data['amenities'] is List
          ? (data['amenities'] as List)
              .map((e) => e.toString())
              .toList(growable: false)
          : const [],
      imageUrl: (data['imageUrl'] as String?)?.trim().isEmpty ?? true
          ? null
          : data['imageUrl'] as String?,
      tenantName: (data['tenantName'] as String?)?.trim().isEmpty ?? true
          ? null
          : data['tenantName'] as String?,
      note: data['note'] as String?,
    );
  }

  /// Payload for create/update requests. Server-owned fields (`id`,
  /// `tenantName`) are omitted.
  Map<String, dynamic> toPayload() => {
        'name': name,
        'status': status.wire,
        if (floor != null) 'floor': floor,
        if (areaSqm != null) 'areaSqm': areaSqm,
        'basePrice': basePrice,
        if (capacity != null) 'capacity': capacity,
        'amenities': amenities,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (note != null) 'note': note,
      };

  Room copyWith({
    String? name,
    RoomStatus? status,
    bool? isActive,
    int? floor,
    double? areaSqm,
    int? basePrice,
    int? capacity,
    List<String>? amenities,
    String? imageUrl,
    String? note,
  }) {
    return Room(
      id: id,
      propertyId: propertyId,
      name: name ?? this.name,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      floor: floor ?? this.floor,
      areaSqm: areaSqm ?? this.areaSqm,
      basePrice: basePrice ?? this.basePrice,
      capacity: capacity ?? this.capacity,
      amenities: amenities ?? this.amenities,
      imageUrl: imageUrl ?? this.imageUrl,
      tenantName: tenantName,
      note: note ?? this.note,
    );
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class RoomAsset {
  const RoomAsset({
    required this.id,
    required this.roomId,
    required this.name,
    required this.quantity,
    required this.condition,
    this.value,
    this.purchasedAt,
    this.note,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String name;
  final int quantity;
  final String condition;
  final int? value;
  final DateTime? purchasedAt;
  final String? note;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoomAsset.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return RoomAsset(
      id: data['id'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      quantity: Room._int(data['quantity']),
      condition: data['condition'] as String? ?? 'good',
      value: Room._intOrNull(data['value']),
      purchasedAt: _date(data['purchasedAt']),
      note: data['note'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toPayload() => {
        'name': name,
        'quantity': quantity,
        'condition': condition,
        if (value != null) 'value': value,
        if (purchasedAt != null) 'purchasedAt': purchasedAt!.toIso8601String(),
        if (note != null) 'note': note,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

class RoomInspection {
  const RoomInspection({
    required this.id,
    required this.roomId,
    required this.title,
    this.dueAt,
    this.completedAt,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String title;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => completedAt != null;

  factory RoomInspection.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return RoomInspection(
      id: data['id'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      dueAt: _date(data['dueAt']),
      completedAt: _date(data['completedAt']),
      note: data['note'] as String?,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toPayload() => {
        'title': title,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        if (note != null) 'note': note,
      };
}

class RoomServiceFee {
  const RoomServiceFee({
    required this.id,
    required this.roomId,
    required this.name,
    required this.amount,
    required this.isActive,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String name;
  final int amount;
  final bool isActive;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RoomServiceFee.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return RoomServiceFee(
      id: data['id'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      amount: Room._int(data['amount']),
      isActive: data['isActive'] != false,
      note: data['note'] as String?,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toPayload() => {
        'name': name,
        'amount': amount,
        if (note != null) 'note': note,
      };
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
