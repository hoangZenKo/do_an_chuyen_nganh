import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/maintenance.dart';

class MaintenanceApi {
  const MaintenanceApi(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> assignees({String? propertyId}) async {
    final response = await _request(() => _dio.get('/maintenance/assignees',
        queryParameters: {if (propertyId != null) 'propertyId': propertyId}));
    return ((response.data as Map)['data'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<MaintenanceListResult> list({
    String? propertyId,
    String? roomId,
    MaintenanceStatus? status,
    MaintenancePriority? priority,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/maintenance',
        queryParameters: {
          if (propertyId != null) 'propertyId': propertyId,
          if (roomId != null) 'roomId': roomId,
          if (status != null) 'status': status.wire,
          if (priority != null) 'priority': priority.name,
        },
      ),
    );
    return MaintenanceListResult.fromJson(response.data);
  }

  Future<MaintenanceTicket> getById(String id) async {
    final response = await _request(() => _dio.get('/maintenance/$id'));
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceTicket> create(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/maintenance', data: payload),
    );
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceTicket> update(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.patch('/maintenance/$id', data: payload),
    );
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceTicket> updateStatus(
    String id,
    MaintenanceStatus status,
  ) async {
    final response = await _request(
      () => _dio.post('/maintenance/$id/status', data: {'status': status.wire}),
    );
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceTicket> complete(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/maintenance/$id/complete', data: payload),
    );
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceComment> addComment(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/maintenance/$id/comments', data: payload),
    );
    final data = response.data as Map<String, dynamic>;
    return MaintenanceComment.fromJson(
      data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data,
    );
  }

  Future<void> delete(String id) async {
    await _request(() => _dio.delete('/maintenance/$id'));
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
