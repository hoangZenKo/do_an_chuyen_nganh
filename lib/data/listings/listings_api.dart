import 'package:dio/dio.dart';
import '../../core/network/api_failure.dart';
import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';

class ListingsApi {
  Future<void> verify(RoomListing listing,
          {required bool landlordVerified,
          required bool roomInspected,
          required String note}) =>
      _request(() async {
        await _dio.post(
            '/admin/listings/${Uri.encodeComponent(listing.id)}/verification',
            data: {
              'version': listing.version,
              'landlordVerified': landlordVerified,
              'roomInspected': roomInspected,
              'note': note,
            });
      });
  Future<List<SchoolCampus>> campuses() => _request(() async {
        final response = await _dio.get('/public/campuses');
        return (response.data['data'] as List)
            .map((item) => SchoolCampus.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  Future<void> report(String id,
          {required String reason, required String detail}) =>
      _request(() async {
        await _dio.post('/student/listings/${Uri.encodeComponent(id)}/reports',
            data: {'reason': reason, 'detail': detail});
      });

  Future<Map<String, dynamic>> reports(int page) => _request(() async {
        final response = await _dio.get('/admin/listings/reports',
            queryParameters: {'page': page, 'limit': 12});
        return response.data as Map<String, dynamic>;
      });

  Future<void> reviewReport(String id, String status, String note) =>
      _request(() async {
        await _dio.post(
            '/admin/listings/reports/${Uri.encodeComponent(id)}/review',
            data: {'status': status, 'note': note});
      });
  const ListingsApi(this._dio);
  final Dio _dio;

  Future<ListingPage> browse(ListingQuery query) => _request(() async {
        final response = await _dio.get('/public/listings',
            queryParameters: query.toQuery());
        return ListingPage.fromJson(response.data as Map<String, dynamic>);
      });

  Future<RoomListing> detail(String id) => _request(() async {
        final response =
            await _dio.get('/public/listings/${Uri.encodeComponent(id)}');
        return RoomListing.fromJson(
            response.data['data'] as Map<String, dynamic>);
      });

  Future<ListingPage> manage(
          {required bool admin, required int page, String? status}) =>
      _request(() async {
        final response = await _dio.get(admin ? '/admin/listings' : '/listings',
            queryParameters: {
              'page': page,
              'limit': 12,
              if (status != null) 'status': status
            });
        return ListingPage.fromJson(response.data as Map<String, dynamic>);
      });

  Future<void> save(Map<String, dynamic> content, {String? id}) =>
      _request(() async {
        if (id == null) {
          await _dio.post('/listings', data: content);
        } else {
          await _dio.patch('/listings/${Uri.encodeComponent(id)}',
              data: content);
        }
      });

  Future<void> action(RoomListing listing, String action, {String? note}) =>
      _request(() async {
        final review = ['PUBLISH', 'REJECT', 'HIDE'].contains(action);
        final prefix = review ? '/admin/listings' : '/listings';
        final endpoint = review ? 'review' : action;
        await _dio.post('$prefix/${Uri.encodeComponent(listing.id)}/$endpoint',
            data: {
              'version': listing.version,
              if (review) 'decision': action,
              if (note != null) 'note': note,
            });
      });

  Future<T> _request<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const ApiFailure(message: 'Kết nối quá hạn. Vui lòng thử lại.');
      }
      final body = error.response?.data;
      if (body is Map<String, dynamic> && body['message'] is List) {
        throw ApiFailure(
            message:
                'Vui lòng kiểm tra thông tin: ${(body['message'] as List).join('; ')}',
            statusCode: error.response?.statusCode);
      }
      if (body is Map<String, dynamic> && body['message'] is String) {
        throw ApiFailure(
            message: body['message'] as String,
            statusCode: error.response?.statusCode);
      }
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: body);
    } on TypeError {
      throw const ApiFailure(message: 'Dữ liệu tin đăng không hợp lệ.');
    } on FormatException {
      throw const ApiFailure(message: 'Dữ liệu tin đăng không hợp lệ.');
    }
  }
}
