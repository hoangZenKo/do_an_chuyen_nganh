import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/room.dart';

/// REST client for rooms within a property.
///
/// All endpoints are protected; the shared Dio instance attaches the bearer
/// token and handles 401 refresh. The backend must verify that the room's
/// property belongs to the landlord identity carried by the JWT.
class RoomApi {
  const RoomApi(this._dio);

  final Dio _dio;

  Future<List<Room>> listByProperty(
    String propertyId, {
    String? lifecycle,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/properties/$propertyId/rooms',
        queryParameters: {
          if (lifecycle != null) 'lifecycle': lifecycle,
        },
      ),
    );
    return _parseList(response.data);
  }

  Future<Room> getById(String id) async {
    final response = await _request(() => _dio.get('/rooms/$id'));
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> create(String propertyId, Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/properties/$propertyId/rooms', data: payload),
    );
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> update(String id, Map<String, dynamic> payload) async {
    final response =
        await _request(() => _dio.patch('/rooms/$id', data: payload));
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Room> setActive(String id, bool isActive) async {
    final response = await _request(
      () => _dio.patch('/rooms/$id/status', data: {'isActive': isActive}),
    );
    return Room.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _request(() => _dio.delete('/rooms/$id'));
  }

  Future<List<RoomAsset>> assets(String roomId) async {
    final response = await _request(() => _dio.get('/rooms/$roomId/assets'));
    return _parseAssetList(response.data);
  }

  Future<RoomAsset> createAsset(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/rooms/$roomId/assets', data: payload),
    );
    return RoomAsset.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoomAsset> updateAsset(
    String roomId,
    String assetId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.patch('/rooms/$roomId/assets/$assetId', data: payload),
    );
    return RoomAsset.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAsset(String roomId, String assetId) async {
    await _request(() => _dio.delete('/rooms/$roomId/assets/$assetId'));
  }

  Future<List<RoomInspection>> inspections(String roomId) async {
    final response =
        await _request(() => _dio.get('/rooms/$roomId/inspections'));
    return _parseInspectionList(response.data);
  }

  Future<RoomInspection> createInspection(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/rooms/$roomId/inspections', data: payload),
    );
    return RoomInspection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoomInspection> completeInspection(
    String roomId,
    String inspectionId,
  ) async {
    final response = await _request(
      () => _dio.post('/rooms/$roomId/inspections/$inspectionId/complete'),
    );
    return RoomInspection.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteInspection(String roomId, String inspectionId) async {
    await _request(
      () => _dio.delete('/rooms/$roomId/inspections/$inspectionId'),
    );
  }

  Future<List<RoomServiceFee>> serviceFees(String roomId) async {
    final response =
        await _request(() => _dio.get('/rooms/$roomId/service-fees'));
    return _parseServiceFeeList(response.data);
  }

  Future<RoomServiceFee> createServiceFee(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/rooms/$roomId/service-fees', data: payload),
    );
    return RoomServiceFee.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoomServiceFee> updateServiceFee(
    String roomId,
    String feeId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.patch('/rooms/$roomId/service-fees/$feeId', data: payload),
    );
    return RoomServiceFee.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteServiceFee(String roomId, String feeId) async {
    await _request(() => _dio.delete('/rooms/$roomId/service-fees/$feeId'));
  }

  List<Room> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Room.fromJson)
        .toList(growable: false);
  }

  List<RoomAsset> _parseAssetList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RoomAsset.fromJson)
        .toList(growable: false);
  }

  List<RoomInspection> _parseInspectionList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RoomInspection.fromJson)
        .toList(growable: false);
  }

  List<RoomServiceFee> _parseServiceFeeList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RoomServiceFee.fromJson)
        .toList(growable: false);
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    } on TypeError {
      throw const ApiFailure(
          message: 'The server returned an invalid response.');
    }
  }
}
