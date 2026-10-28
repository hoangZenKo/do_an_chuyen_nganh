import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/audit_log.dart';

class AuditApi {
  const AuditApi(this._dio);

  final Dio _dio;

  Future<List<AuditLog>> list({int take = 80}) async {
    final response = await _request(
      () => _dio.get('/audit-logs', queryParameters: {'take': take}),
    );
    return _parseList(response.data).map(AuditLog.fromJson).toList();
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
