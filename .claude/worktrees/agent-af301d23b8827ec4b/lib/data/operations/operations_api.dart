import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/landlord_notification.dart';

class OperationsApi {
  const OperationsApi(this._dio);

  final Dio _dio;

  Future<ActionItems> actionItems() async {
    final response = await _request(() => _dio.get('/operations/action-items'));
    return ActionItems.fromJson(response.data as Map<String, dynamic>);
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
