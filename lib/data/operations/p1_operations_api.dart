import 'package:dio/dio.dart';
import '../../core/network/api_failure.dart';
import '../../models/p1_operations.dart';

class P1OperationsApi {
  const P1OperationsApi(this._dio);
  final Dio _dio;
  Future<Map<String, dynamic>> options() =>
      _object('GET', '/operations/options');
  Future<void> reconcilePaymentEvent(String invoiceId, String eventId) async {
    await _object('POST',
        '/billing/invoices/$invoiceId/payment-events/$eventId/reconcile');
  }

  Future<P1Page<RoomTurnover>> turnovers({int page = 1}) =>
      _page('/operations/turnovers', RoomTurnover.fromJson, page: page);
  Future<RoomTurnover> startTurnover(String roomId, {String? note}) async =>
      RoomTurnover.fromJson(await _object('POST', '/operations/turnovers',
          data: {'roomId': roomId, if (note != null) 'note': note}));
  Future<RoomTurnover> advanceTurnover(
          RoomTurnover turnover, String note) async =>
      RoomTurnover.fromJson(await _object(
          'POST', '/operations/turnovers/${turnover.id}/advance', data: {
        'version': turnover.version,
        'stage': turnover.stage.wire,
        'note': note
      }));
  Future<P1Page<OperationTask>> tasks({int page = 1}) =>
      _page('/operations/tasks', OperationTask.fromJson, page: page);
  Future<OperationTask> checkTask(
          OperationTask task, int index, bool done) async =>
      OperationTask.fromJson(await _object(
          'PATCH', '/operations/tasks/${task.id}/checklist',
          data: {'version': task.version, 'index': index, 'done': done}));
  Future<P1Page<RecurringOperation>> recurring({int page = 1}) =>
      _page('/operations/recurring', RecurringOperation.fromJson, page: page);
  Future<void> createRecurring(Map<String, dynamic> data) async {
    await _object('POST', '/operations/recurring', data: data);
  }

  Future<void> toggleRecurring(String id, bool enabled) async {
    await _object('PATCH', '/operations/recurring/$id',
        data: {'isEnabled': enabled});
  }

  Future<List<AnnouncementItem>> announcements({bool tenant = false}) => _list(
      tenant ? '/tenant/announcements' : '/announcements',
      AnnouncementItem.fromJson);
  Future<void> createAnnouncement(Map<String, dynamic> data) async {
    await _object('POST', '/announcements', data: data);
  }

  Future<void> cancelAnnouncement(String id) async {
    await _object('POST', '/announcements/$id/cancel');
  }

  Future<List<Map<String, dynamic>>> receipts(String id) =>
      _list('/announcements/$id/receipts', (json) => json);
  Future<List<Map<String, dynamic>>> groups() =>
      _list('/announcements/groups', (json) => json);
  Future<List<Map<String, dynamic>>> templates() =>
      _list('/announcements/templates', (json) => json);
  Future<void> createGroup(String name, List<String> tenantIds) async {
    await _object('POST', '/announcements/groups',
        data: {'name': name, 'tenantIds': tenantIds});
  }

  Future<void> createTemplate(String name, String title, String body) async {
    await _object('POST', '/announcements/templates',
        data: {'name': name, 'title': title, 'body': body});
  }

  Future<void> markAnnouncementRead(String id) async {
    await _object('POST', '/tenant/announcements/$id/read');
  }

  Future<PaymentLinkInfo> paymentLink(String invoiceId) async =>
      PaymentLinkInfo.fromJson(
          await _object('POST', '/tenant/invoices/$invoiceId/payment-link'));
  Future<String> createDemoInvoice(String invoiceId) async {
    final raw =
        await _object('POST', '/tenant/invoices/$invoiceId/demo-invoice');
    final id = raw['id'];
    if (id is! String || id.isEmpty) {
      throw const ApiFailure(
          message: 'Không tạo được hóa đơn demo. Vui lòng thử lại.');
    }
    return id;
  }

  Future<PaymentLinkInfo?> paymentStatus(String invoiceId) async {
    final raw =
        await _request('GET', '/tenant/invoices/$invoiceId/payment-link');
    return raw == null
        ? null
        : PaymentLinkInfo.fromJson(raw as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> paymentEvents(String invoiceId) =>
      _list('/billing/invoices/$invoiceId/payment-events', (json) => json);

  Future<Map<String, dynamic>> _object(String method, String path,
      {Map<String, dynamic>? data}) async {
    final raw = await _request(method, path, data: data);
    if (raw is! Map<String, dynamic>) {
      throw const ApiFailure(
          message: 'Dữ liệu vận hành không hợp lệ. Vui lòng thử lại.');
    }
    return raw;
  }

  Future<P1Page<T>> _page<T>(
      String path, T Function(Map<String, dynamic>) parser,
      {required int page}) async {
    try {
      final response =
          await _dio.get(path, queryParameters: {'page': page, 'limit': 20});
      final raw = response.data as Map<String, dynamic>;
      return P1Page(
          items: (raw['data'] as List)
              .map((item) => parser(item as Map<String, dynamic>))
              .toList(),
          total: (raw['total'] as num).toInt(),
          page: page);
    } on DioException catch (error) {
      throw _failure(error);
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu vận hành không hợp lệ. Vui lòng thử lại.');
    }
  }

  Future<List<T>> _list<T>(
      String path, T Function(Map<String, dynamic>) parser) async {
    final raw = await _request('GET', path);
    try {
      return (raw as List)
          .map((item) => parser(item as Map<String, dynamic>))
          .toList(growable: false);
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu vận hành không hợp lệ. Vui lòng thử lại.');
    }
  }

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.request(path,
          data: data, options: Options(method: method));
      final raw = response.data;
      if (raw is! Map<String, dynamic> || !raw.containsKey('data')) {
        throw const ApiFailure(
            message: 'Dữ liệu vận hành không hợp lệ. Vui lòng thử lại.');
      }
      return raw['data'];
    } on DioException catch (error) {
      throw _failure(error);
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu vận hành không hợp lệ. Vui lòng thử lại.');
    }
  }

  ApiFailure _failure(DioException error) {
    final raw = error.response?.data;
    if (raw is Map<String, dynamic> && raw['message'] is String) {
      return ApiFailure(
          message: raw['message'] as String,
          statusCode: error.response?.statusCode);
    }
    return ApiFailure.fromResponse(
        statusCode: error.response?.statusCode, data: raw);
  }
}
