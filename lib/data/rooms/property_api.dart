import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/property.dart';

/// REST client for landlord properties (khu trọ).
///
/// All endpoints are protected; the shared Dio instance attaches the bearer
/// token and handles 401 refresh. The backend must scope every query to the
/// landlord identity carried by the JWT.
class PropertyApi {
  const PropertyApi(this._dio);

  final Dio _dio;

  Future<List<Property>> list({String? lifecycle}) async {
    final response = await _request(
      () => _dio.get(
        '/properties',
        queryParameters: {
          if (lifecycle != null) 'lifecycle': lifecycle,
        },
      ),
    );
    return _parseList(response.data);
  }

  Future<Property> getById(String id) async {
    final response = await _request(() => _dio.get('/properties/$id'));
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Property> create({
    required String name,
    required String address,
  }) async {
    final response = await _request(
      () => _dio.post('/properties', data: {'name': name, 'address': address}),
    );
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Property> update(
    String id, {
    String? name,
    String? address,
  }) async {
    final response = await _request(
      () => _dio.patch('/properties/$id', data: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
      }),
    );
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Property> setArchived(String id, bool isArchived) async {
    final response = await _request(
      () => _dio.patch(
        '/properties/$id/status',
        data: {'isArchived': isArchived},
      ),
    );
    return Property.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _request(() => _dio.delete('/properties/$id'));
  }

  List<Property> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
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
