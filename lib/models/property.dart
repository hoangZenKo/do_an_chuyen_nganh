/// A rental property (khu trọ) owned by the signed-in landlord.
///
/// The parser accepts either a bare object or a `{ "data": { ... } }` envelope,
/// mirroring [AuthSession] so the client stays tolerant of small backend
/// differences.
class Property {
  const Property({
    required this.id,
    required this.name,
    required this.address,
    this.isArchived = false,
    this.roomCount = 0,
    this.occupiedCount = 0,
  });

  final String id;
  final String name;
  final String address;
  final bool isArchived;
  final int roomCount;
  final int occupiedCount;

  int get vacantCount => (roomCount - occupiedCount).clamp(0, roomCount);

  factory Property.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return Property(
      id: data['id'] as String,
      name: data['name'] as String,
      address: data['address'] as String? ?? '',
      isArchived: data['isArchived'] == true,
      roomCount: _int(data['roomCount']),
      occupiedCount: _int(data['occupiedCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'isArchived': isArchived,
        'roomCount': roomCount,
        'occupiedCount': occupiedCount,
      };

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
