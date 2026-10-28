import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/landlord_notification.dart';

class OperationsApi {
  const OperationsApi(this._dio);

  final Dio _dio;

  Future<void> markRead(String id) async {
    await _request(() => _dio.post(
          '/operations/action-items/${Uri.encodeComponent(id)}/read',
        ));
  }

  Future<ActionItems> actionItems({
    int page = 1,
    int limit = 20,
    String category = 'all',
    String? propertyId,
  }) async {
    return _request(() async {
      final response = await _dio.get(
        '/operations/action-items',
        queryParameters: {
          'page': page,
          'limit': limit,
          'category': category,
          if (propertyId != null && propertyId.isNotEmpty)
            'propertyId': propertyId,
        },
      );
      return ActionItems.fromJson(response.data as Map<String, dynamic>);
    });
  }

  Future<T> _request<T>(
    Future<T> Function() request,
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
        message: 'Dữ liệu công việc không hợp lệ. Vui lòng thử lại.',
      );
    }
  }
}
