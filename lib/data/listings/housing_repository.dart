import 'package:dio/dio.dart';
import '../../core/network/api_failure.dart';
import '../../models/housing.dart';

class HousingRepository {
  const HousingRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? data, int? page}) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
          '/housing/$path',
          data: data,
          queryParameters: page == null ? null : {'page': page},
          options: Options(method: method));
      return response.data!;
    } on DioException catch (error) {
      if (error.response != null) {
        final body = error.response!.data;
        if (body is Map<String, dynamic> && body['message'] != null) {
          final message = body['message'];
          throw ApiFailure(
              message:
                  message is List ? message.join('; ') : message.toString(),
              statusCode: error.response!.statusCode);
        }
        throw ApiFailure.fromResponse(
            statusCode: error.response!.statusCode, data: error.response!.data);
      }
      throw const ApiFailure(
          message: 'Không thể kết nối. Kiểm tra mạng rồi thử lại.');
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu phản hồi không hợp lệ. Hãy tải lại.');
    }
  }

  Future<HousingPage<SavedRoom>> favorites(int page) async =>
      HousingPage.fromJson(
          await _request('GET', 'favorites', page: page), SavedRoom.fromJson);
  Future<bool> isSaved(String id) async =>
      (await _request('GET', 'favorites/${Uri.encodeComponent(id)}'))['data']
          ['saved'] ==
      true;
  Future<void> saveFavorite(String id, bool saved) async {
    await _request(
        saved ? 'PUT' : 'DELETE', 'favorites/${Uri.encodeComponent(id)}');
  }

  Future<HousingPage<RoomViewing>> viewings(int page) async =>
      HousingPage.fromJson(
          await _request('GET', 'viewings', page: page), RoomViewing.fromJson);
  Future<RoomViewing> viewing(String id) async => RoomViewing.fromJson(
      (await _request('GET', 'viewings/${Uri.encodeComponent(id)}'))['data']
          as Map<String, dynamic>);

  Future<void> book(String listingId, DateTime scheduledAt, String note) async {
    await _request('POST', 'viewings', data: {
      'listingId': listingId,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'note': note.trim()
    });
  }

  Future<ViewingAvailability> slots(String listingId) async =>
      ViewingAvailability.fromJson(await _request(
          'GET', 'listings/${Uri.encodeComponent(listingId)}/slots'));

  Future<void> addSlot(String listingId, DateTime startsAt) async {
    await _request('POST', 'listings/${Uri.encodeComponent(listingId)}/slots',
        data: {
          'startsAt': startsAt.toUtc().toIso8601String(),
          'endsAt': startsAt
              .add(const Duration(minutes: 30))
              .toUtc()
              .toIso8601String(),
        });
  }

  Future<void> removeSlot(String id) async {
    await _request('DELETE', 'slots/${Uri.encodeComponent(id)}');
  }

  Future<void> bookSlot(
      String listingId, DateTime date, String note, String? slotId) async {
    if (slotId == null) return book(listingId, date, note);
    await _request('POST', 'viewings', data: {
      'listingId': listingId,
      'scheduledAt': date.toUtc().toIso8601String(),
      'note': note.trim(),
      'slotId': slotId
    });
  }

  Future<void> reschedule(
      RoomViewing viewing, DateTime date, String note, String? slotId) async {
    await _request(
        'PATCH', 'viewings/${Uri.encodeComponent(viewing.id)}/reschedule',
        data: {
          'version': viewing.version,
          'listingId': viewing.listingId,
          'scheduledAt': date.toUtc().toIso8601String(),
          'note': note.trim(),
          if (slotId != null) 'slotId': slotId,
        });
  }

  Future<HandoverDetail> handover(String leaseId) async =>
      HandoverDetail.fromJson((await _request(
              'GET', 'leases/${Uri.encodeComponent(leaseId)}/handover'))['data']
          as Map<String, dynamic>);

  Future<void> saveHandover(String leaseId, int version, int electricity,
      int water, String condition, List<String> images) async {
    await _request('PUT', 'leases/${Uri.encodeComponent(leaseId)}/handover',
        data: {
          'version': version,
          'electricity': electricity,
          'water': water,
          'condition': condition.trim(),
          'imageUrls': images
        });
  }

  Future<void> acceptHandover(String leaseId, int version) async {
    await _request(
        'POST', 'leases/${Uri.encodeComponent(leaseId)}/handover/accept',
        data: {'version': version});
  }

  Future<void> updateViewing(
      RoomViewing viewing, String status, String note) async {
    await _request('PATCH', 'viewings/${Uri.encodeComponent(viewing.id)}',
        data: {
          'version': viewing.version,
          'status': status,
          'note': note.trim()
        });
  }

  Future<void> createLease(
      RoomViewing viewing, DateTime startDate, int rent, int deposit) async {
    await _request('POST', 'viewings/${Uri.encodeComponent(viewing.id)}/lease',
        data: {
          'version': viewing.version,
          'startDate':
              DateTime.utc(startDate.year, startDate.month, startDate.day)
                  .toIso8601String(),
          'monthlyRent': rent,
          'deposit': deposit
        });
  }

  Future<HousingPage<HousingNotice>> notifications(int page) async =>
      HousingPage.fromJson(await _request('GET', 'notifications', page: page),
          HousingNotice.fromJson);
  Future<void> readNotification(String id) async {
    await _request('POST', 'notifications/${Uri.encodeComponent(id)}/read');
  }

  Future<RentalPilot> pilot() async => RentalPilot.fromJson(
      (await _request('GET', 'pilot'))['data'] as Map<String, dynamic>);
  Future<void> feedback(
      RentalPilot pilot, String stage, int rating, String detail) async {
    await _request('POST', 'feedback', data: {
      'area': pilot.area,
      'stage': stage,
      'rating': rating,
      'detail': detail.trim()
    });
  }

  Future<HousingPage<PilotFeedback>> feedbackList(int page) async =>
      HousingPage.fromJson(await _request('GET', 'feedback', page: page),
          PilotFeedback.fromJson);
}
