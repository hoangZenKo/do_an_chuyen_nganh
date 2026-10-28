import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/tenant_portal/tenant_portal_api.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/maintenance.dart';
import 'package:rental_room_management/models/tenant_portal.dart';

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

TenantPortalApi _api(_RecordingAdapter adapter) {
  return TenantPortalApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
  );
}

const _invoiceJson = '{"id":"i1","leaseId":"l1","roomId":"r1",'
    '"tenantId":"t1","billingMonth":"2026-08-01T00:00:00.000Z",'
    '"rentAmount":1000,"electricityAmount":100,"waterAmount":50,'
    '"otherAmount":25,"totalAmount":1175,"paidAmount":0,'
    '"remainingAmount":1175,"status":"unpaid","roomName":"A101",'
    '"tenantName":"Tenant","payments":[]}';

void main() {
  test('me requests tenant/me and parses the data envelope', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"t1","fullName":"Tenant A",'
        '"phone":"0901","landlordId":"u1","landlordName":"Owner",'
        '"activeLease":{"id":"l1","roomId":"r1",'
        '"roomName":"A101","propertyId":"p1","propertyName":"Building",'
        '"monthlyRent":1000,"status":"active"}}}',
        200,
      ),
    );

    final profile = await _api(adapter).me();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/me');
    expect(profile.id, 't1');
    expect(profile.activeLease?.roomName, 'A101');
  });

  test('dashboard requests tenant/dashboard and parses nested data', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"profile":{"id":"t1","fullName":"Tenant A",'
        '"phone":"0901","landlordId":"u1","landlordName":"Owner",'
        '"activeLease":{"id":"l1","roomId":"r1",'
        '"roomName":"A101","propertyId":"p1","propertyName":"Building",'
        '"monthlyRent":1000,"status":"active"}},'
        '"outstandingAmount":1175,"openInvoiceCount":1,'
        '"overdueInvoiceCount":1,"dueSoonInvoiceCount":0,'
        '"openMaintenanceCount":2,"unreadNotificationCount":3,'
        '"nextInvoice":$_invoiceJson,'
        '"recentMaintenance":[{"id":"m1","propertyId":"p1",'
        '"roomId":"r1","status":"open","priority":"medium",'
        '"title":"Máy lạnh hỏng","comments":[]}]}}',
        200,
      ),
    );

    final dashboard = await _api(adapter).dashboard();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/dashboard');
    expect(dashboard.profile.fullName, 'Tenant A');
    expect(dashboard.outstandingAmount, 1175);
    expect(dashboard.nextInvoice?.id, 'i1');
    expect(dashboard.recentMaintenance.single.title, 'Máy lạnh hỏng');
  });

  test('invoices requests tenant/invoices and parses list responses', () async {
    final adapter = _RecordingAdapter(_json('{"data":[$_invoiceJson]}', 200));

    final invoices = await _api(adapter).invoices();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/invoices');
    expect(invoices.single.id, 'i1');
    expect(invoices.single.remainingAmount, 1175);
  });

  test('invoice requests tenant/invoices/:id and parses detail response',
      () async {
    final adapter = _RecordingAdapter(_json('{"data":$_invoiceJson}', 200));

    final invoice = await _api(adapter).invoice('i1');

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/invoices/i1');
    expect(invoice.id, 'i1');
    expect(invoice.status, InvoiceStatus.unpaid);
  });

  test('leases requests tenant/leases and parses tenant lease list', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"l1","roomId":"r1","roomName":"A101",'
        '"propertyId":"p1","propertyName":"Building",'
        '"propertyAddress":"12 Nguyen Trai","monthlyRent":2500000,'
        '"deposit":2500000,"status":"active",'
        '"startDate":"2026-08-01T00:00:00.000Z"}]}',
        200,
      ),
    );

    final leases = await _api(adapter).leases();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/leases');
    expect(leases.single, isA<TenantPortalLease>());
    expect(leases.single.roomName, 'A101');
    expect(leases.single.isActive, isTrue);
  });

  test('notifications requests tenant notifications and parses data list',
      () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"n1","kind":"invoice_due","title":"Hóa đơn",'
        '"body":"Thanh toán","invoiceId":"i1","read":false}]}',
        200,
      ),
    );

    final notifications = await _api(adapter).notifications();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/notifications');
    expect(notifications.single.id, 'n1');
    expect(notifications.single.read, isFalse);
  });

  test('markNotificationRead posts to the read endpoint', () async {
    final adapter = _RecordingAdapter(_json('{"data":{}}', 200));

    await _api(adapter).markNotificationRead('n1');

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/notifications/n1/read');
  });

  test('zaloMessages requests tenant Zalo inbox and parses logs', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"z1","channel":"zalo","purpose":"tenant_manual_message",'
        '"recipient":"0901","status":"sent",'
        '"payload":{"message_text":"Xin chào","sender_role":"tenant",'
        '"direction":"tenant_to_landlord"}}]}',
        200,
      ),
    );

    final messages = await _api(adapter).zaloMessages();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/zalo-messages');
    expect(messages.single.id, 'z1');
    expect(messages.single.isTenantMessage, isTrue);
  });

  test('createZaloMessage posts payload and unwraps nested data', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"z1","channel":"zalo","purpose":"tenant_manual_message",'
        '"recipient":"0901","status":"sent",'
        '"payload":{"message_text":"Xin chào","sender_role":"tenant",'
        '"direction":"tenant_to_landlord"}}}',
        201,
      ),
    );

    final result =
        await _api(adapter).createZaloMessage({'message': ' Xin chào '});

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/zalo-messages');
    expect(adapter.request.data, {'message': ' Xin chào '});
    expect(result.id, 'z1');
    expect(result.messageText(), 'Xin chào');
  });

  test('markZaloMessageRead posts to the read endpoint', () async {
    final adapter = _RecordingAdapter(_json('{"data":{}}', 200));

    await _api(adapter).markZaloMessageRead('z1');

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/zalo-messages/z1/read');
  });

  test('submitPaymentProof posts proof payload and parses response', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"proof1","invoiceId":"i1","tenantId":"t1",'
        '"amount":1175,"method":"bank_transfer","status":"pending",'
        '"proofImageUrls":["https://example.com/proof.jpg"]}}',
        201,
      ),
    );
    final payload = {
      'amount': 1175,
      'method': 'bank_transfer',
      'note': 'Đã chuyển khoản',
      'proofImageUrls': ['https://example.com/proof.jpg'],
    };

    final proof = await _api(adapter).submitPaymentProof('i1', payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/invoices/i1/payment-proofs');
    expect(adapter.request.data, payload);
    expect(proof.id, 'proof1');
    expect(proof.proofImageUrls, hasLength(1));
  });

  test('maintenance requests tenant/maintenance and parses list', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"m1","propertyId":"p1","roomId":"r1",'
        '"status":"open","priority":"medium","title":"Máy lạnh hỏng",'
        '"comments":[]}]}',
        200,
      ),
    );

    final tickets = await _api(adapter).maintenance();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenant/maintenance');
    expect(tickets.single.id, 'm1');
    expect(tickets.single.title, 'Máy lạnh hỏng');
  });

  test('createMaintenance posts payload and parses created ticket', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"m1","propertyId":"p1","roomId":"r1",'
        '"status":"open","priority":"urgent","title":"Máy lạnh hỏng",'
        '"description":"Không lạnh","comments":[]}}',
        201,
      ),
    );
    final payload = {
      'title': 'Máy lạnh hỏng',
      'description': 'Không lạnh',
      'priority': 'urgent',
      'imageUrls': ['https://example.com/photo.jpg'],
    };

    final ticket = await _api(adapter).createMaintenance(payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/maintenance');
    expect(adapter.request.data, payload);
    expect(ticket.id, 'm1');
    expect(ticket.priority, MaintenancePriority.urgent);
  });

  test('addMaintenanceComment posts comment and unwraps nested data', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"c1","ticketId":"m1","authorId":"u1",'
        '"authorRole":"tenant","body":"Đã kiểm tra",'
        '"imageUrls":["https://example.com/comment.jpg"]}}',
        201,
      ),
    );
    final payload = {
      'body': 'Đã kiểm tra',
      'imageUrls': ['https://example.com/comment.jpg'],
    };

    final comment = await _api(adapter).addMaintenanceComment('m1', payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/maintenance/m1/comments');
    expect(adapter.request.data, payload);
    expect(comment.id, 'c1');
    expect(comment.imageUrls, hasLength(1));
  });

  test('maps Dio failures to ApiFailure', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"error":{"code":"TENANT_PROFILE_NOT_FOUND",'
        '"message":"Tenant not found"}}',
        404,
      ),
    );

    await expectLater(
      _api(adapter).me(),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'statusCode', 404)
            .having(
                (failure) => failure.code, 'code', 'TENANT_PROFILE_NOT_FOUND'),
      ),
    );
  });
}
