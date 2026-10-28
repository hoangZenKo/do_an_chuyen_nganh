import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';

class LifecyclePage {
  const LifecyclePage(this.rows, this.nextCursor);
  final List<Map<String, dynamic>> rows;
  final String? nextCursor;
}

class TenantLifecycleApi {
  const TenantLifecycleApi(this.dio, {required this.ownerId});
  final Dio dio;
  final String? ownerId;

  Future<LifecyclePage> requests(
      {required bool tenant,
      required String leaseId,
      String? status,
      String? cursor}) async {
    final body = await _request(
        tenant ? '/tenant/lifecycle-requests' : '/tenant-lifecycle/requests',
        query: {
          'leaseId': leaseId,
          'limit': 25,
          if (status != null) 'status': status,
          if (cursor != null) 'cursor': cursor
        });
    return _page(body);
  }

  Future<void> create(Map<String, dynamic> input) async {
    await _request('/tenant/lifecycle-requests', method: 'POST', data: input);
  }

  Future<void> execute(Map<String, dynamic> request, String key,
      {int? monthlyRent}) async {
    await _request('/tenant-lifecycle/requests/${request['id']}/execute',
        method: 'POST',
        data: {
          'requestKey': key,
          'expectedUpdatedAt': request['updatedAt'],
          if (request['lease']?['updatedAt'] != null)
            'expectedLeaseUpdatedAt': request['lease']['updatedAt'],
          if (monthlyRent != null) 'monthlyRent': monthlyRent,
        });
  }

  Future<void> cancel(Map<String, dynamic> request) async {
    await _request('/tenant/lifecycle-requests/${request['id']}/cancel',
        method: 'POST', data: {'expectedUpdatedAt': request['updatedAt']});
  }

  Future<void> review(
      Map<String, dynamic> request, String status, String reason) async {
    await _request('/tenant-lifecycle/requests/${request['id']}/review',
        method: 'POST',
        data: {
          'status': status,
          'reason': reason,
          'expectedUpdatedAt': request['updatedAt'],
          if (request['lease']?['updatedAt'] != null)
            'expectedLeaseUpdatedAt': request['lease']['updatedAt']
        });
  }

  Future<LifecyclePage> transferRooms(String leaseId,
          {String? search, String? cursor}) async =>
      _page(await _request('/tenant/transfer-rooms', query: {
        'leaseId': leaseId,
        'limit': 25,
        if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
        if (cursor != null) 'cursor': cursor
      }));

  Future<List<Map<String, dynamic>>> occupants(String leaseId,
      {required bool tenant}) async {
    final body = await _request(
        tenant
            ? '/tenant/occupants'
            : '/tenant-lifecycle/leases/$leaseId/occupants',
        query: tenant ? {'leaseId': leaseId} : null);
    return _rows(body['data']);
  }

  Future<void> addOccupant(String leaseId, Map<String, dynamic> input) async {
    await _request('/tenant-lifecycle/leases/$leaseId/occupants',
        method: 'POST', data: input);
  }

  Future<void> removeOccupant(String leaseId, String id) async {
    await _request('/tenant-lifecycle/leases/$leaseId/occupants/$id',
        method: 'DELETE');
  }

  Future<Map<String, dynamic>?> settlement(String leaseId) async {
    final body = await _request('/tenant/leases/$leaseId/settlement');
    if (!body.containsKey('data')) {
      throw const ApiFailure(message: 'Phản hồi quyết toán không hợp lệ.');
    }
    return body['data'] == null
        ? null
        : Map<String, dynamic>.from(body['data'] as Map);
  }

  LifecyclePage _page(Map<String, dynamic> body) =>
      LifecyclePage(_rows(body['data']), body['nextCursor'] as String?);

  List<Map<String, dynamic>> _rows(dynamic rows) {
    if (rows is! List ||
        rows.any((row) => row is! Map || row['id'] is! String)) {
      throw const ApiFailure(message: 'Phản hồi danh sách không hợp lệ.');
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> _request(String path,
      {String method = 'GET',
      Map<String, dynamic>? data,
      Map<String, dynamic>? query}) async {
    if (ownerId == null || ownerId!.isEmpty) {
      throw const ApiFailure(
          message: 'Vui lòng đăng nhập lại.', statusCode: 401);
    }
    try {
      final response = await dio.request(path,
          data: data,
          queryParameters: query,
          options: Options(method: method, extra: {'expectedUserId': ownerId}));
      if (response.data is! Map) {
        throw const ApiFailure(message: 'Phản hồi không hợp lệ.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: error.response?.data);
    } on TypeError {
      throw const ApiFailure(message: 'Phản hồi không hợp lệ.');
    }
  }
}
