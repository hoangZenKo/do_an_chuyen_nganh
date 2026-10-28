import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/staff.dart';

class StaffApi {
  const StaffApi(this._dio);

  final Dio _dio;

  Future<List<StaffMember>> list() async {
    final response = await _request(() => _dio.get('/staff'));
    return _parseList(response.data).map(StaffMember.fromJson).toList();
  }

  Future<List<StaffPreset>> presets() async {
    final response = await _request(() => _dio.get('/staff/presets'));
    return _parseList(response.data).map(StaffPreset.fromJson).toList();
  }

  Future<StaffInvite> createInvite(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/staff/invites', data: payload),
    );
    return StaffInvite.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StaffMember> update(String id, Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.patch('/staff/$id', data: payload),
    );
    return StaffMember.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> simulate(
    String id, {
    required String propertyId,
    required String permission,
  }) async {
    final response = await _request(() => _dio.post('/staff/$id/simulate', data: {
          'propertyId': propertyId,
          'permission': permission,
        }));
    return Map<String, dynamic>.from((response.data as Map)['data'] as Map);
  }

  List<Map<String, dynamic>> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
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
        message: 'The server returned an invalid response.',
      );
    }
  }
}
