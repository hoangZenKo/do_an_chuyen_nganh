import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/notifications/notifications_api.dart';

ResponseBody _json(String body, int statusCode) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final ResponseBody response;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

NotificationsApi _api(_RecordingAdapter adapter) {
  return NotificationsApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
  );
}

void main() {
  test('list requests notifications endpoint and parses bundle', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"n1","kind":"invoice_due","severity":"warning",'
        '"title":"Hóa đơn","body":"Thanh toán","resourceType":"invoice",'
        '"resourceId":"i1","actionRoute":"/tenant/invoices/i1",'
        '"isRead":false}],"summary":{"total":1,"unread":1}}',
        200,
      ),
    );

    final bundle = await _api(adapter).list();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/notifications');
    expect(bundle.items.single.id, 'n1');
    expect(bundle.summary.unread, 1);
  });

  test('markRead posts to the read endpoint', () async {
    final adapter = _RecordingAdapter(_json('{"data":{}}', 200));

    await _api(adapter).markRead('n1');

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/notifications/n1/read');
  });

  test('deliveryLogs forwards take query and parses delivery list', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"d1","channel":"zalo","purpose":"invoice_reminder",'
        '"recipient":"0901","status":"sent",'
        '"payload":{"tenant_name":"Tenant","room_name":"A101",'
        '"billing_month":"2026-08","due_date":"2026-08-10",'
        '"amount":1175}}]}',
        200,
      ),
    );

    final logs = await _api(adapter).deliveryLogs(take: 12);

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/notifications/deliveries');
    expect(adapter.request.queryParameters, {'take': 12});
    expect(logs.single.id, 'd1');
    expect(logs.single.tenantName, 'Tenant');
  });

  test('createZaloTestMessage posts to the test endpoint', () async {
    final adapter = _RecordingAdapter(_json('{"data":{}}', 201));

    await _api(adapter).createZaloTestMessage();

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/notifications/zalo/test-message');
  });

  test('sendZaloManualMessage posts payload and unwraps nested data', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"d1","channel":"zalo","purpose":"tenant_manual_message",'
        '"recipient":"0901","status":"sent",'
        '"payload":{"message_text":"Xin chào","sender_role":"landlord",'
        '"direction":"landlord_to_tenant"}}}',
        201,
      ),
    );

    final log = await _api(adapter).sendZaloManualMessage(
      tenantId: 't1',
      message: 'Xin chào',
      invoiceId: 'i1',
    );

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/notifications/zalo/manual-message');
    expect(adapter.request.data, {
      'tenantId': 't1',
      'message': 'Xin chào',
      'invoiceId': 'i1',
    });
    expect(log.id, 'd1');
    expect(log.isTenantMessage, isTrue);
  });

  test('maps Dio failures to ApiFailure', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"error":{"code":"NOTIFICATION_NOT_FOUND",'
        '"message":"Notification not found"}}',
        404,
      ),
    );

    await expectLater(
      _api(adapter).markRead('n1'),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'statusCode', 404)
            .having((failure) => failure.code, 'code', 'NOTIFICATION_NOT_FOUND'),
      ),
    );
  });
}
