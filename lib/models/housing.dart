class HousingPage<T> {
  const HousingPage(
      {required this.items,
      required this.page,
      required this.total,
      this.limit = 20});
  final List<T> items;
  final int page, total, limit;
  bool get hasNext => page * limit < total;

  factory HousingPage.fromJson(
      Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    final meta = json['meta'] as Map<String, dynamic>;
    return HousingPage(
        items: (json['data'] as List)
            .map((entry) => parse(entry as Map<String, dynamic>))
            .toList(),
        page: (meta['page'] as num).toInt(),
        total: (meta['total'] as num).toInt(),
        limit: (meta['limit'] as num).toInt());
  }
}

class SavedRoom {
  const SavedRoom(
      {required this.id,
      required this.title,
      required this.address,
      required this.rent,
      required this.available});
  final String id, title, address;
  final int rent;
  final bool available;
  factory SavedRoom.fromJson(Map<String, dynamic> json) => SavedRoom(
      id: json['id'] as String,
      title: json['title'] as String,
      address: '${json['publicAddress']}, ${json['district']}, ${json['city']}',
      rent: (json['monthlyRent'] as num).toInt(),
      available: json['available'] == true);
}

class RoomViewing {
  const RoomViewing(
      {required this.id,
      required this.listingId,
      required this.title,
      required this.studentName,
      required this.landlordName,
      required this.address,
      required this.status,
      required this.version,
      required this.scheduledAt,
      required this.rent,
      required this.deposit,
      this.note = '',
      this.responseNote = '',
      this.cancellationReason = '',
      this.endsAt,
      this.leaseId});
  final String id,
      listingId,
      title,
      studentName,
      landlordName,
      address,
      status,
      note,
      responseNote;
  final String cancellationReason;
  final String? leaseId;
  final int version, rent, deposit;
  final DateTime scheduledAt;
  final DateTime? endsAt;
  bool get canCancel => status == 'REQUESTED' || status == 'CONFIRMED';
  String get statusLabel => switch (status) {
        'REQUESTED' => 'Chờ xác nhận',
        'CONFIRMED' => 'Đã xác nhận',
        'CANCELLED' => 'Đã hủy',
        'COMPLETED' => 'Đã xem phòng',
        'LEASED' => 'Đã tạo hợp đồng',
        _ => 'Chưa rõ trạng thái',
      };
  factory RoomViewing.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>;
    return RoomViewing(
        id: json['id'] as String,
        listingId: listing['id'] as String,
        title: listing['title'] as String,
        studentName: (json['student'] as Map)['fullName'] as String,
        landlordName: (json['landlord'] as Map)['fullName'] as String,
        address:
            '${listing['publicAddress']}, ${listing['district']}, ${listing['city']}',
        status: json['status'] as String,
        version: (json['version'] as num).toInt(),
        scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
        rent: (listing['monthlyRent'] as num).toInt(),
        deposit: (listing['deposit'] as num).toInt(),
        note: json['note'] as String? ?? '',
        responseNote: json['responseNote'] as String? ?? '',
        cancellationReason: json['cancellationReason'] as String? ?? '',
        endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '')?.toLocal(),
        leaseId: json['leaseId'] as String?);
  }
}

class ViewingSlot {
  const ViewingSlot(
      {required this.id,
      required this.startsAt,
      required this.endsAt,
      required this.available});
  final String id;
  final DateTime startsAt, endsAt;
  final bool available;
  factory ViewingSlot.fromJson(Map<String, dynamic> json) => ViewingSlot(
      id: json['id'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
      endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
      available: json['available'] == true);
}

class ViewingAvailability {
  const ViewingAvailability({required this.required, required this.slots});
  final bool required;
  final List<ViewingSlot> slots;
  factory ViewingAvailability.fromJson(Map<String, dynamic> json) =>
      ViewingAvailability(
          required: json['required'] == true,
          slots: (json['data'] as List)
              .map((item) => ViewingSlot.fromJson(item as Map<String, dynamic>))
              .toList());
}

class LeaseHandover {
  const LeaseHandover(
      {required this.version,
      required this.electricity,
      required this.water,
      required this.condition,
      required this.images,
      this.acceptedAt});
  final int version, electricity, water;
  final String condition;
  final List<String> images;
  final DateTime? acceptedAt;
  factory LeaseHandover.fromJson(Map<String, dynamic> json) => LeaseHandover(
      version: (json['version'] as num).toInt(),
      electricity: (json['electricity'] as num).toInt(),
      water: (json['water'] as num).toInt(),
      condition: json['condition'] as String,
      images: (json['imageUrls'] as List).cast<String>(),
      acceptedAt:
          DateTime.tryParse(json['acceptedAt'] as String? ?? '')?.toLocal());
}

class HandoverDetail {
  const HandoverDetail(
      {required this.leaseId,
      required this.roomName,
      required this.propertyName,
      required this.active,
      required this.startDate,
      required this.deposit,
      this.handover});
  final String leaseId, roomName, propertyName;
  final bool active;
  final DateTime startDate;
  final LeaseHandover? handover;
  final Map<String, int> deposit;
  factory HandoverDetail.fromJson(Map<String, dynamic> json) => HandoverDetail(
      leaseId: json['leaseId'] as String,
      roomName: json['roomName'] as String,
      propertyName: json['propertyName'] as String,
      active: json['status'] == 'ACTIVE',
      startDate: DateTime.parse(json['startDate'] as String).toLocal(),
      deposit: (json['deposit'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      handover: json['handover'] == null
          ? null
          : LeaseHandover.fromJson(json['handover'] as Map<String, dynamic>));
}

class HousingNotice {
  const HousingNotice(
      {required this.id,
      required this.viewingId,
      required this.message,
      required this.createdAt,
      required this.read});
  final String id, viewingId, message;
  final DateTime createdAt;
  final bool read;
  factory HousingNotice.fromJson(Map<String, dynamic> json) => HousingNotice(
      id: json['id'] as String,
      viewingId: json['viewingId'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      read: json['readAt'] != null);
}

class RentalPilot {
  const RentalPilot({required this.enabled, required this.area});
  final bool enabled;
  final String area;
  factory RentalPilot.fromJson(Map<String, dynamic> json) => RentalPilot(
      enabled: json['enabled'] == true, area: json['area'] as String);
}

class PilotFeedback {
  const PilotFeedback(
      {required this.area,
      required this.stage,
      required this.detail,
      required this.rating});
  final String area, stage, detail;
  final int rating;
  factory PilotFeedback.fromJson(Map<String, dynamic> json) => PilotFeedback(
      area: json['area'] as String,
      stage: json['stage'] as String,
      detail: json['detail'] as String,
      rating: (json['rating'] as num).toInt());
}
