import 'room_listing.dart';

class SchoolCampus {
  const SchoolCampus(
      {required this.id,
      required this.name,
      required this.campus,
      required this.city,
      this.isDemo = false,
      this.isActive = true,
      this.address = '',
      this.latitude = 0,
      this.longitude = 0,
      this.sourceUrl});
  final String id, name, campus, city;
  final bool isDemo;
  final bool isActive;
  final String address;
  final double latitude, longitude;
  final String? sourceUrl;
  String get label => '$name · $campus${isDemo ? ' (mẫu)' : ''}';
  factory SchoolCampus.fromJson(Map<String, dynamic> json) => SchoolCampus(
        id: json['id'] as String,
        name: json['name'] as String,
        campus: json['campus'] as String,
        city: json['city'] as String,
        isDemo: json['isDemo'] == true,
        isActive: json['isActive'] != false,
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        sourceUrl: json['sourceUrl'] as String?,
      );
}

class LivingCostEstimate {
  const LivingCostEstimate(
      {this.electricityKwh = 50, this.waterM3 = 3, this.people = 1});
  final int electricityKwh, waterM3, people;
  int monthly(RoomListing listing) =>
      listing.monthlyRent +
      listing.electricityPrice * electricityKwh +
      listing.waterPrice * waterM3 +
      listing.serviceFee +
      listing.parkingFee;
  int perPerson(RoomListing listing) => (monthly(listing) / people).ceil();
  int moveIn(RoomListing listing) => listing.deposit + monthly(listing);
}

const listingReportReasons = {
  'wrong_price': 'Giá hoặc phí không đúng',
  'wrong_photos': 'Ảnh không đúng thực tế',
  'unavailable': 'Phòng đã hết',
  'suspected_scam': 'Nghi ngờ lừa đảo',
  'other': 'Vấn đề khác',
};
