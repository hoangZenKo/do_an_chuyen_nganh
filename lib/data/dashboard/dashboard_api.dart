import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/dashboard.dart';

class DashboardApi {
  const DashboardApi(this._dio);

  final Dio _dio;

  Future<DashboardMetrics> metrics({
    String? propertyId,
    int months = 12,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/dashboard/metrics',
        queryParameters: {
          if (propertyId != null) 'propertyId': propertyId,
          'months': months,
        },
      ),
    );
    return DashboardMetrics.fromJson(response.data as Map<String, dynamic>);
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
