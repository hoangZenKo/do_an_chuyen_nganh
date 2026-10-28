import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/landlord_notification.dart';
import '../../models/notification_delivery.dart';

class NotificationsApi {
  const NotificationsApi(this._dio);

  final Dio _dio;

  Future<NotificationBundle> list() async {
    final response = await _request(() => _dio.get('/notifications'));
    return NotificationBundle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> markRead(String id) async {
    await _request(() => _dio.post('/notifications/$id/read'));
  }

  Future<List<NotificationDeliveryLog>> deliveryLogs({int take = 80}) async {
    final response = await _request(
      () => _dio.get(
        '/notifications/deliveries',
        queryParameters: {'take': take},
      ),
    );
    return notificationDeliveryListFromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> createZaloTestMessage() async {
    await _request(() => _dio.post('/notifications/zalo/test-message'));
  }

  Future<NotificationDeliveryLog> sendZaloManualMessage({
    required String tenantId,
    required String message,
    String? invoiceId,
  }) async {
    final response = await _request(
      () => _dio.post(
        '/notifications/zalo/manual-message',
        data: {
          'tenantId': tenantId,
          'message': message,
          if (invoiceId != null && invoiceId.isNotEmpty) 'invoiceId': invoiceId,
        },
      ),
    );
    final data = response.data as Map<String, dynamic>;
    final raw = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return NotificationDeliveryLog.fromJson(raw);
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
