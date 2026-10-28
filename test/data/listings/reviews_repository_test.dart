import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/reviews_repository.dart';
import 'package:rental_room_management/models/room_review.dart';

import 'listings_api_test.dart' show RecordingListingsAdapter;

const reviewJson = <String, dynamic>{
  'id': 'review-1',
  'version': 3,
  'status': 'APPROVED',
  'roomRating': 5,
  'costRating': 3,
  'landlordRating': 4,
  'areaRating': 4,
  'body': 'Phòng thoáng, chi phí rõ ràng và khu vực yên tĩnh.',
  'createdAt': '2026-10-24T00:00:00.000Z',
};

void main() {
  ReviewsRepository repository(RecordingListingsAdapter adapter) =>
      ReviewsRepository(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter);

  test('parses real aggregates, approved replies and public pagination',
      () async {
    final adapter = RecordingListingsAdapter({
      'data': [
        {
          ...reviewJson,
          'reply': {'body': 'Cảm ơn bạn!'}
        }
      ],
      'summary': {
        'count': 12,
        'overall': 4,
        'roomRating': 5,
        'costRating': 3,
        'landlordRating': 4,
        'areaRating': 4
      },
      'meta': {'page': 1, 'limit': 10, 'total': 12},
    });
    final page = await repository(adapter).publicReviews('listing-1', 1);
    expect(adapter.request.path, '/public/listings/listing-1/reviews');
    expect(adapter.request.queryParameters, {'page': 1});
    expect(page.page.hasNext, isTrue);
    expect(page.overall, 4);
    expect(page.page.items.single.replyBody, 'Cảm ơn bạn!');
    expect(page.page.items.single.replyStatus, 'APPROVED');
  });

  test('does not invent a score when there are no reviews', () async {
    final adapter = RecordingListingsAdapter({
      'data': [],
      'summary': {'count': 0, 'overall': null},
      'meta': {'page': 1, 'limit': 10, 'total': 0},
    });
    final page = await repository(adapter).publicReviews('listing-1', 1);
    expect(page.overall, isNull);
    expect(page.averages.values, everyElement(isNull));
    expect(page.page.items, isEmpty);
  });

  test('parses eligibility and private moderation state', () async {
    final adapter = RecordingListingsAdapter({
      'data': {
        'leaseId': 'lease-1',
        'roomName': 'P.101',
        'propertyName': 'Trọ A',
        'eligible': true,
        'review': {
          ...reviewJson,
          'withdrawnAt': '2026-10-24T01:00:00Z',
          'moderationNote': 'Nội dung đã kiểm tra',
          'replyBody': 'Phản hồi chờ duyệt',
          'replyStatus': 'PENDING'
        },
      }
    });
    final context = await repository(adapter).context('lease-1');
    expect(adapter.request.path, '/reviews/leases/lease-1');
    expect(context.eligible, isTrue);
    expect(context.review!.withdrawn, isTrue);
    expect(context.review!.replyStatus, 'PENDING');
  });

  test('creates, updates and withdraws using current review version', () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    final api = repository(adapter);
    final review = RoomReview.fromJson(reviewJson);
    await api.submit('lease-1', review.scores, '  ${review.body}  ');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/reviews/leases/lease-1');
    expect(adapter.request.data, {...review.scores, 'body': review.body});
    await api.submit('lease-1', review.scores, review.body, existing: review);
    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/reviews/review-1');
    expect(adapter.request.data['version'], 3);
    await api.withdraw(review);
    expect(adapter.request.method, 'DELETE');
    expect(adapter.request.data, {'version': 3});
  });

  test('filters admin queues and does not send admin filters for landlords',
      () async {
    final adapter = RecordingListingsAdapter({
      'data': [reviewJson],
      'meta': {'page': 2, 'limit': 10, 'total': 12}
    });
    final api = repository(adapter);
    await api.manage(admin: true, page: 2, status: 'REJECTED', replies: true);
    expect(adapter.request.path, '/admin/room-reviews');
    expect(adapter.request.queryParameters,
        {'page': 2, 'status': 'REJECTED', 'target': 'reply'});
    await api.manage(admin: false, page: 2);
    expect(adapter.request.path, '/reviews/landlord');
    expect(adapter.request.queryParameters, {'page': 2});
  });

  test('replies and moderates review and reply as separate versioned actions',
      () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    final api = repository(adapter);
    final review = RoomReview.fromJson(reviewJson);
    await api.reply(review, '  Cảm ơn phản hồi của bạn.  ');
    expect(adapter.request.path, '/reviews/review-1/reply');
    expect(adapter.request.data,
        {'version': 3, 'body': 'Cảm ơn phản hồi của bạn.'});
    for (final reply in [false, true]) {
      await api.moderate(review, 'HIDDEN', '  Cần sửa nội dung.  ',
          reply: reply);
      expect(adapter.request.path,
          '/admin/room-reviews/review-1/${reply ? 'reply/' : ''}moderate');
      expect(adapter.request.data,
          {'version': 3, 'status': 'HIDDEN', 'note': 'Cần sửa nội dung.'});
    }
  });

  test('maps conflicts and validation errors without swallowing status',
      () async {
    final conflict = RecordingListingsAdapter(
        {'message': 'Đánh giá vừa thay đổi. Hãy tải lại.'},
        status: 409);
    await expectLater(
        repository(conflict).reply(RoomReview.fromJson(reviewJson), 'Phản hồi'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 409)));
    final invalid = RecordingListingsAdapter({
      'message': ['roomRating must not be greater than 5']
    }, status: 400);
    await expectLater(
        repository(invalid).context('lease-1'),
        throwsA(isA<ApiFailure>().having(
            (error) => error.message, 'message', contains('roomRating'))));
  });
}
