import 'admin_models.dart';

class AdminRoomProperty {
  const AdminRoomProperty(
      {required this.id,
      required this.name,
      required this.address,
      required this.isArchived,
      required this.landlord});
  final String id, name, address;
  final bool isArchived;
  final AdminPropertyLandlord? landlord;
  factory AdminRoomProperty.fromJson(Map<String, dynamic> json) =>
      AdminRoomProperty(
          id: json['id'] as String,
          name: json['name'] as String? ?? '',
          address: json['address'] as String? ?? '',
          isArchived: json['isArchived'] == true,
          landlord: json['landlord'] is Map<String, dynamic>
              ? AdminPropertyLandlord.fromJson(
                  json['landlord'] as Map<String, dynamic>)
              : null);
}

class AdminRoomSummary extends AdminPropertyRoom {
  const AdminRoomSummary(
      {required super.id,
      required super.name,
      required super.status,
      super.basePrice,
      super.floor,
      super.areaSqm,
      super.isActive,
      super.listing,
      required this.property});
  final AdminRoomProperty property;
  factory AdminRoomSummary.fromJson(Map<String, dynamic> json) {
    final room = AdminPropertyRoom.fromJson(json);
    return AdminRoomSummary(
        id: room.id,
        name: room.name,
        status: room.status,
        basePrice: room.basePrice,
        floor: room.floor,
        areaSqm: room.areaSqm,
        isActive: room.isActive,
        listing: room.listing,
        property: AdminRoomProperty.fromJson(
            json['property'] as Map<String, dynamic>));
  }
}

class AdminRoomsQuery {
  const AdminRoomsQuery(
      {this.page = 1,
      this.limit = 20,
      this.search = '',
      this.propertyId,
      this.landlordId,
      this.status = 'all',
      this.activity = 'all',
      this.listingStatus = 'all',
      this.minPrice,
      this.maxPrice});
  final int page, limit;
  final String search, status, activity, listingStatus;
  final String? propertyId, landlordId;
  final int? minPrice, maxPrice;
  Map<String, dynamic> toQuery() => {
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (propertyId != null) 'propertyId': propertyId,
        if (landlordId != null) 'landlordId': landlordId,
        if (status != 'all') 'status': status,
        if (activity != 'all') 'activity': activity,
        if (listingStatus != 'all') 'listingStatus': listingStatus,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      };
  AdminRoomsQuery copyWith(
          {int? page,
          String? search,
          String? propertyId,
          bool clearProperty = false,
          String? status,
          String? activity,
          String? listingStatus,
          int? minPrice,
          int? maxPrice,
          bool clearPrices = false}) =>
      AdminRoomsQuery(
          page: page ?? this.page,
          limit: limit,
          search: search ?? this.search,
          propertyId: clearProperty ? null : propertyId ?? this.propertyId,
          landlordId: landlordId,
          status: status ?? this.status,
          activity: activity ?? this.activity,
          listingStatus: listingStatus ?? this.listingStatus,
          minPrice: clearPrices ? null : minPrice ?? this.minPrice,
          maxPrice: clearPrices ? null : maxPrice ?? this.maxPrice);
  @override
  bool operator ==(Object other) =>
      other is AdminRoomsQuery &&
      other.page == page &&
      other.limit == limit &&
      other.search == search &&
      other.propertyId == propertyId &&
      other.landlordId == landlordId &&
      other.status == status &&
      other.activity == activity &&
      other.listingStatus == listingStatus &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice;
  @override
  int get hashCode => Object.hash(page, limit, search, propertyId, landlordId,
      status, activity, listingStatus, minPrice, maxPrice);
}
