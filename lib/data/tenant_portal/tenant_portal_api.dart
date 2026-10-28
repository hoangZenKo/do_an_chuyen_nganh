import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/billing.dart';
import '../../models/maintenance.dart';
import '../../models/notification_delivery.dart';
import '../../models/tenant_portal.dart';

class TenantPortalApi {
  const TenantPortalApi(this._dio);

  final Dio _dio;

  Future<TenantPortalProfile> me() async {
    final response = await _request(() => _dio.get('/tenant/me'));
    return TenantPortalProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TenantDashboard> dashboard() async {
    final response = await _request(() => _dio.get('/tenant/dashboard'));
    return TenantDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Invoice>> invoices() async {
    final response = await _request(() => _dio.get('/tenant/invoices'));
    return _parseList(response.data).map(Invoice.fromJson).toList();
  }

  Future<List<TenantPortalLease>> leases() async {
    final response = await _request(() => _dio.get('/tenant/leases'));
    return _parseList(response.data)
        .map(TenantPortalLease.fromJson)
        .toList(growable: false);
  }

  Future<Invoice> invoice(String id) async {
    final response = await _request(() => _dio.get('/tenant/invoices/$id'));
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TenantNotification>> notifications() async {
    final response = await _request(() => _dio.get('/tenant/notifications'));
    return _parseList(response.data)
        .map(TenantNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markNotificationRead(String id) async {
    await _request(() => _dio.post('/tenant/notifications/$id/read'));
  }

  Future<List<NotificationDeliveryLog>> zaloMessages() async {
    final response = await _request(() => _dio.get('/tenant/zalo-messages'));
    return notificationDeliveryListFromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<NotificationDeliveryLog> createZaloMessage(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenant/zalo-messages', data: payload),
    );
    final data = response.data as Map<String, dynamic>;
    final raw = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return NotificationDeliveryLog.fromJson(raw);
  }

  Future<void> markZaloMessageRead(String id) async {
    await _request(() => _dio.post('/tenant/zalo-messages/$id/read'));
  }

  Future<PaymentProof> submitPaymentProof(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenant/invoices/$invoiceId/payment-proofs',
          data: payload),
    );
    return PaymentProof.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MaintenanceTicket>> maintenance() async {
    final response = await _request(() => _dio.get('/tenant/maintenance'));
    return _parseList(response.data).map(MaintenanceTicket.fromJson).toList();
  }

  Future<MaintenanceTicket> createMaintenance(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenant/maintenance', data: payload),
    );
    return MaintenanceTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaintenanceComment> addMaintenanceComment(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/tenant/maintenance/$id/comments', data: payload),
    );
    return MaintenanceComment.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  List<Map<String, dynamic>> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
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
