import 'package:dio/dio.dart';
import '../../core/network/api_failure.dart';
import '../../models/housing.dart';
import '../../models/room_review.dart';

class ReviewsRepository {
  const ReviewsRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(path,
          data: data, queryParameters: query, options: Options(method: method));
      return response.data!;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['message'] != null) {
        final message = body['message'];
        throw ApiFailure(
            message: message is List ? message.join('; ') : message.toString(),
            statusCode: error.response?.statusCode);
      }
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: body);
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu đánh giá không hợp lệ. Hãy tải lại.');
    }
  }

  Future<PublicReviewPage> publicReviews(String listingId, int page) async =>
      PublicReviewPage.fromJson(await _request(
          'GET', '/public/listings/${Uri.encodeComponent(listingId)}/reviews',
          query: {'page': page}));

  Future<ReviewContext> context(String leaseId) async =>
      ReviewContext.fromJson((await _request(
              'GET', '/reviews/leases/${Uri.encodeComponent(leaseId)}'))['data']
          as Map<String, dynamic>);

  Future<void> submit(String leaseId, Map<String, int> scores, String body,
      {RoomReview? existing}) async {
    await _request(
        existing == null ? 'POST' : 'PATCH',
        existing == null
            ? '/reviews/leases/${Uri.encodeComponent(leaseId)}'
            : '/reviews/${Uri.encodeComponent(existing.id)}',
        data: {
          ...scores,
          'body': body.trim(),
          if (existing != null) 'version': existing.version
        });
  }

  Future<void> withdraw(RoomReview review) async {
    await _request('DELETE', '/reviews/${Uri.encodeComponent(review.id)}',
        data: {'version': review.version});
  }

  Future<HousingPage<RoomReview>> manage(
          {required bool admin,
          required int page,
          String status = 'PENDING',
          bool replies = false}) async =>
      HousingPage.fromJson(
          await _request(
              'GET', admin ? '/admin/room-reviews' : '/reviews/landlord',
              query: {
                'page': page,
                if (admin) ...{
                  'status': status,
                  'target': replies ? 'reply' : 'review'
                }
              }),
          RoomReview.fromJson);

  Future<void> reply(RoomReview review, String body) async {
    await _request('POST', '/reviews/${Uri.encodeComponent(review.id)}/reply',
        data: {'version': review.version, 'body': body.trim()});
  }

  Future<void> moderate(RoomReview review, String status, String note,
      {required bool reply}) async {
    await _request('POST',
        '/admin/room-reviews/${Uri.encodeComponent(review.id)}/${reply ? 'reply/' : ''}moderate',
        data: {
          'version': review.version,
          'status': status,
          'note': note.trim()
        });
  }
}
