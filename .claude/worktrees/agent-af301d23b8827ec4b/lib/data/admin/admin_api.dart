import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/admin_models.dart';

class AdminApi {
  const AdminApi(this._dio);

  final Dio _dio;

  Future<AdminOverview> overview() async {
    final response = await _request(() => _dio.get('/admin/overview'));
    return AdminOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AdminLandlordSummary>> listLandlords(
      AdminLandlordsQuery query) async {
    final response = await _request(() => _dio.get(
          '/admin/landlords',
          queryParameters: query.toQuery(),
        ));
    return _parseList(response.data, AdminLandlordSummary.fromJson);
  }

  Future<AdminLandlordRecord> createLandlord({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _request(() => _dio.post('/admin/landlords', data: {
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
        }));
    return AdminLandlordRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordDetail> getLandlord(String id) async {
    final response = await _request(() => _dio.get('/admin/landlords/$id'));
    return AdminLandlordDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordRecord> updateLandlord(
    String id, {
    String? fullName,
    String? phone,
  }) async {
    final response =
        await _request(() => _dio.patch('/admin/landlords/$id', data: {
              if (fullName != null) 'fullName': fullName,
              if (phone != null) 'phone': phone,
            }));
    return AdminLandlordRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordRecord> updateLandlordStatus(
    String id, {
    required bool isActive,
  }) async {
    final response = await _request(() => _dio.patch(
          '/admin/landlords/$id/status',
          data: {'isActive': isActive},
        ));
    return AdminLandlordRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AdminPropertySummary>> listProperties(
    AdminPropertiesQuery query,
  ) async {
    final response = await _request(() => _dio.get(
          '/admin/properties',
          queryParameters: query.toQuery(),
        ));
    return _parseList(response.data, AdminPropertySummary.fromJson);
  }

  Future<AdminPropertySummary> createProperty({
    required String landlordId,
    required String name,
    required String address,
  }) async {
    final response = await _request(() => _dio.post('/admin/properties', data: {
          'landlordId': landlordId,
          'name': name,
          'address': address,
        }));
    return AdminPropertySummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminPropertyDetail> getProperty(String id) async {
    final response = await _request(() => _dio.get('/admin/properties/$id'));
    return AdminPropertyDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminPropertyDetail> updateProperty(
    String id, {
    String? name,
    String? address,
  }) async {
    final response =
        await _request(() => _dio.patch('/admin/properties/$id', data: {
              if (name != null) 'name': name,
              if (address != null) 'address': address,
            }));
    return AdminPropertyDetail.fromJson(response.data as Map<String, dynamic>);
  }

  List<T> _parseList<T>(
    Object? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
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
