import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/tenant.dart';

/// REST client for tenants. All endpoints protected; the shared Dio attaches
/// the bearer token. Backend scopes every query to the landlord in the JWT.
class TenantApi {
  const TenantApi(this._dio);

  final Dio _dio;

  Future<List<Tenant>> list({String? lifecycle}) async {
    final response = await _request(
      () => _dio.get(
        '/tenants',
        queryParameters: {
          if (lifecycle != null) 'lifecycle': lifecycle,
        },
      ),
    );
    return _parseList(response.data);
  }

  Future<Tenant> getById(String id) async {
    final response = await _request(() => _dio.get('/tenants/$id'));
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TenantOverview> overview(String id) async {
    final response = await _request(() => _dio.get('/tenants/$id/overview'));
    return TenantOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tenant> create(Map<String, dynamic> payload) async {
    final response = await _request(() => _dio.post('/tenants', data: payload));
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tenant> update(String id, Map<String, dynamic> payload) async {
    final response =
        await _request(() => _dio.patch('/tenants/$id', data: payload));
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Tenant> createAccount(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenants/$id/account', data: payload),
    );
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createInvite(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenants/$id/invite', data: payload),
    );
    final data = response.data as Map<String, dynamic>;
    return data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
  }

  Future<Tenant> setActive(String id, bool isActive) async {
    final response = await _request(
      () => _dio.patch('/tenants/$id/status', data: {'isActive': isActive}),
    );
    return Tenant.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _request(() => _dio.delete('/tenants/$id'));
  }

  List<Tenant> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Tenant.fromJson)
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
