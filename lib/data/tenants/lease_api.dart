import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/lease.dart';

/// REST client for leases. Creating/ending a lease also updates the room's
/// status server-side (transactional), so callers should refresh room lists.
class LeaseApi {
  const LeaseApi(this._dio);

  final Dio _dio;

  Future<Lease> create(Map<String, dynamic> payload) async {
    final response = await _request(() => _dio.post('/leases', data: payload));
    return Lease.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Lease> end(String id) async {
    final response = await _request(() => _dio.post('/leases/$id/end'));
    return Lease.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Lease> update(String id, Map<String, dynamic> payload) async {
    final response =
        await _request(() => _dio.patch('/leases/$id', data: payload));
    return Lease.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Lease> renew(String id, Map<String, dynamic> payload) async {
    final response =
        await _request(() => _dio.post('/leases/$id/renew', data: payload));
    return Lease.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DepositTransaction> createDeposit(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _request(() => _dio.post('/leases/$id/deposits', data: payload));
    final data = response.data as Map<String, dynamic>;
    return DepositTransaction.fromJson(
      data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data,
    );
  }

  Future<List<Lease>> listByTenant(String tenantId) async {
    final response =
        await _request(() => _dio.get('/tenants/$tenantId/leases'));
    return _parseList(response.data);
  }

  Future<List<Lease>> listByRoom(String roomId) async {
    final response = await _request(() => _dio.get('/rooms/$roomId/leases'));
    return _parseList(response.data);
  }

  Future<List<ExpiringLease>> expiring({int days = 30}) async {
    final response = await _request(
      () => _dio.get('/leases/expiring', queryParameters: {'days': days}),
    );
    final raw = response.data is Map<String, dynamic> &&
            (response.data as Map<String, dynamic>)['data'] is List
        ? (response.data as Map<String, dynamic>)['data'] as List
        : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ExpiringLease.fromJson)
        .toList(growable: false);
  }

  List<Lease> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Lease.fromJson)
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
