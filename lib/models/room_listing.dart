class RoomListing {
  const RoomListing({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.city,
    required this.district,
    required this.publicAddress,
    required this.monthlyRent,
    required this.deposit,
    required this.electricityPrice,
    required this.waterPrice,
    required this.serviceFee,
    required this.areaSqm,
    required this.amenities,
    required this.propertyName,
    this.roomId,
    this.status,
    this.reviewNote,
    this.version = 1,
    this.parkingFee = 0,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.publishedAt,
    this.availabilityConfirmedAt,
    this.landlordVerifiedAt,
    this.inspectedAt,
    this.estimatedMonthlyCost,
  });

  final String id,
      title,
      description,
      city,
      district,
      publicAddress,
      propertyName;
  final List<String> imageUrls, amenities;
  final int monthlyRent,
      deposit,
      electricityPrice,
      waterPrice,
      serviceFee,
      version;
  final double areaSqm;
  final String? roomId, status, reviewNote;
  final int parkingFee;
  final int? estimatedMonthlyCost;
  final double? latitude, longitude, distanceKm;
  final DateTime? publishedAt,
      availabilityConfirmedAt,
      landlordVerifiedAt,
      inspectedAt;
  bool get isDemo => description.contains('[explore-preview]');
  bool get availabilityFresh =>
      availabilityConfirmedAt != null &&
      availabilityConfirmedAt!
          .isAfter(DateTime.now().subtract(const Duration(days: 14)));

  factory RoomListing.fromJson(Map<String, dynamic> json) {
    final room = json['room'] as Map<String, dynamic>?;
    final property = room?['property'] as Map<String, dynamic>?;
    return RoomListing(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrls:
          (json['imageUrls'] as List).cast<String>().toList(growable: false),
      city: json['city'] as String,
      district: json['district'] as String,
      publicAddress: json['publicAddress'] as String,
      monthlyRent: (json['monthlyRent'] as num).toInt(),
      deposit: (json['deposit'] as num).toInt(),
      electricityPrice: (json['electricityPrice'] as num).toInt(),
      waterPrice: (json['waterPrice'] as num).toInt(),
      serviceFee: (json['serviceFee'] as num).toInt(),
      areaSqm: (json['areaSqm'] as num).toDouble(),
      amenities:
          (json['amenities'] as List).cast<String>().toList(growable: false),
      propertyName:
          json['propertyName'] as String? ?? property?['name'] as String? ?? '',
      roomId: json['roomId'] as String?,
      status: json['status'] as String?,
      reviewNote: json['reviewNote'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      parkingFee: (json['parkingFee'] as num?)?.toInt() ?? 0,
      estimatedMonthlyCost: (json['estimatedMonthlyCost'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      availabilityConfirmedAt:
          DateTime.tryParse(json['availabilityConfirmedAt'] as String? ?? ''),
      landlordVerifiedAt:
          DateTime.tryParse(json['landlordVerifiedAt'] as String? ?? ''),
      inspectedAt: DateTime.tryParse(json['inspectedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> get content => {
        'title': title,
        'description': description,
        'imageUrls': imageUrls,
        'city': city,
        'district': district,
        'publicAddress': publicAddress,
        'monthlyRent': monthlyRent,
        'deposit': deposit,
        'electricityPrice': electricityPrice,
        'waterPrice': waterPrice,
        'serviceFee': serviceFee,
        'parkingFee': parkingFee,
        if (latitude != null && longitude != null) ...{
          'latitude': latitude,
          'longitude': longitude
        },
        'areaSqm': areaSqm,
        'amenities': amenities,
      };
}

class ListingPage {
  const ListingPage(
      {required this.items,
      required this.total,
      required this.page,
      required this.limit});
  final List<RoomListing> items;
  final int total, page, limit;
  bool get hasNext => page * limit < total;

  factory ListingPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>;
    return ListingPage(
      items: (json['data'] as List)
          .map((item) => RoomListing.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (meta['total'] as num).toInt(),
      page: (meta['page'] as num).toInt(),
      limit: (meta['limit'] as num).toInt(),
    );
  }
}

class ListingQuery {
  const ListingQuery(
      {this.search = '',
      this.campusId,
      this.radiusKm,
      this.city = '',
      this.district = '',
      this.minPrice,
      this.maxPrice,
      this.maxBudget,
      this.electricityKwh = 50,
      this.waterM3 = 3,
      this.freshOnly = false,
      this.minArea,
      this.amenity = '',
      this.sort = 'newest',
      this.page = 1});
  final String search, city, district, amenity, sort;
  final int? minPrice, maxPrice;
  final int? maxBudget;
  final int electricityKwh, waterM3;
  final bool freshOnly;
  final double? minArea;
  final int page;
  final String? campusId;
  final double? radiusKm;

  Map<String, dynamic> toQuery() => {
        if (maxBudget != null) 'maxBudget': maxBudget,
        'electricityKwh': electricityKwh,
        'waterM3': waterM3,
        if (freshOnly) 'freshOnly': true,
        if (campusId != null) 'campusId': campusId,
        if (campusId != null && radiusKm != null) 'radiusKm': radiusKm,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (city.trim().isNotEmpty) 'city': city.trim(),
        if (district.trim().isNotEmpty) 'district': district.trim(),
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (minArea != null) 'minArea': minArea,
        if (amenity.trim().isNotEmpty) 'amenity': amenity.trim(),
        'sort': sort,
        'page': page,
        'limit': 12,
      };

  ListingQuery atPage(int value) => ListingQuery(
      maxBudget: maxBudget,
      electricityKwh: electricityKwh,
      waterM3: waterM3,
      freshOnly: freshOnly,
      campusId: campusId,
      radiusKm: radiusKm,
      search: search,
      city: city,
      district: district,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minArea: minArea,
      amenity: amenity,
      sort: sort,
      page: value);

  @override
  bool operator ==(Object other) =>
      other is ListingQuery &&
      maxBudget == other.maxBudget &&
      electricityKwh == other.electricityKwh &&
      waterM3 == other.waterM3 &&
      freshOnly == other.freshOnly &&
      search == other.search &&
      campusId == other.campusId &&
      radiusKm == other.radiusKm &&
      city == other.city &&
      district == other.district &&
      minPrice == other.minPrice &&
      maxPrice == other.maxPrice &&
      minArea == other.minArea &&
      amenity == other.amenity &&
      sort == other.sort &&
      page == other.page;

  @override
  int get hashCode => Object.hash(
      search,
      city,
      district,
      minPrice,
      maxPrice,
      minArea,
      amenity,
      sort,
      page,
      campusId,
      radiusKm,
      maxBudget,
      electricityKwh,
      waterM3,
      freshOnly);

  factory ListingQuery.fromJson(Map<String, dynamic> json) => ListingQuery(
        search: json['search'] as String? ?? '',
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        amenity: json['amenity'] as String? ?? '',
        sort: json['sort'] as String? ?? 'newest',
        campusId: json['campusId'] as String?,
        radiusKm: (json['radiusKm'] as num?)?.toDouble(),
        minPrice: json['minPrice'] as int?,
        maxPrice: json['maxPrice'] as int?,
        maxBudget: json['maxBudget'] as int?,
        minArea: (json['minArea'] as num?)?.toDouble(),
        electricityKwh: json['electricityKwh'] as int? ?? 50,
        waterM3: json['waterM3'] as int? ?? 3,
        freshOnly: json['freshOnly'] == true,
      );
}

String listingStatusLabel(String? status) => switch (status) {
      'DRAFT' => 'Bản nháp',
      'PENDING' => 'Chờ duyệt',
      'PUBLISHED' => 'Đã duyệt',
      'REJECTED' => 'Bị từ chối',
      'HIDDEN' => 'Đã ẩn',
      _ => 'Còn trống',
    };
