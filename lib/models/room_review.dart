import 'housing.dart';

const reviewCriteria = {
  'roomRating': 'Căn phòng',
  'costRating': 'Chi phí',
  'landlordRating': 'Chủ trọ',
  'areaRating': 'Khu vực',
};

String reviewStatusLabel(String status) => switch (status) {
      'PENDING' => 'Chờ kiểm duyệt',
      'APPROVED' => 'Đã công khai',
      'REJECTED' => 'Chưa được duyệt',
      'HIDDEN' => 'Đã ẩn',
      _ => 'Chưa có phản hồi',
    };

class RoomReview {
  const RoomReview(
      {required this.id,
      required this.scores,
      required this.body,
      required this.createdAt,
      this.version = 0,
      this.status = 'APPROVED',
      this.roomName,
      this.propertyName,
      this.moderationNote,
      this.withdrawn = false,
      this.replyBody,
      this.replyStatus,
      this.replyModerationNote});
  final String id, body, status;
  final String? roomName,
      propertyName,
      moderationNote,
      replyBody,
      replyStatus,
      replyModerationNote;
  final Map<String, int> scores;
  final DateTime createdAt;
  final int version;
  final bool withdrawn;
  double get overall =>
      scores.values.fold<int>(0, (sum, value) => sum + value) / 4;
  factory RoomReview.fromJson(Map<String, dynamic> json) => RoomReview(
      id: json['id'] as String,
      body: json['body'] as String,
      scores: {
        for (final key in reviewCriteria.keys) key: (json[key] as num).toInt()
      },
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      version: (json['version'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'APPROVED',
      roomName: json['roomName'] as String?,
      propertyName: json['propertyName'] as String?,
      moderationNote: json['moderationNote'] as String?,
      withdrawn: json['withdrawnAt'] != null,
      replyBody: (json['reply'] as Map?)?['body'] as String? ??
          json['replyBody'] as String?,
      replyStatus:
          json['reply'] != null ? 'APPROVED' : json['replyStatus'] as String?,
      replyModerationNote: json['replyModerationNote'] as String?);
}

class ReviewContext {
  const ReviewContext(
      {required this.leaseId,
      required this.roomName,
      required this.propertyName,
      required this.eligible,
      this.reason,
      this.review});
  final String leaseId, roomName, propertyName;
  final bool eligible;
  final String? reason;
  final RoomReview? review;
  factory ReviewContext.fromJson(Map<String, dynamic> json) => ReviewContext(
      leaseId: json['leaseId'] as String,
      roomName: json['roomName'] as String,
      propertyName: json['propertyName'] as String,
      eligible: json['eligible'] == true,
      reason: json['reason'] as String?,
      review: json['review'] == null
          ? null
          : RoomReview.fromJson(json['review'] as Map<String, dynamic>));
}

class PublicReviewPage {
  const PublicReviewPage(
      {required this.page,
      required this.count,
      required this.averages,
      this.overall});
  final HousingPage<RoomReview> page;
  final int count;
  final double? overall;
  final Map<String, double?> averages;
  factory PublicReviewPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    return PublicReviewPage(
        page: HousingPage.fromJson(json, RoomReview.fromJson),
        count: (summary['count'] as num).toInt(),
        overall: (summary['overall'] as num?)?.toDouble(),
        averages: {
          for (final key in reviewCriteria.keys)
            key: (summary[key] as num?)?.toDouble()
        });
  }
}
