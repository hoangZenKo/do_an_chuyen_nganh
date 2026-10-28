import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/operations/p1_operations_api.dart';
import 'package:rental_room_management/models/p1_operations.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Object? body;
  final int status;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

P1OperationsApi _api(_Adapter adapter) =>
    P1OperationsApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter);

Map<String, dynamic> _turnover({String stage = 'INSPECTION'}) => {
      'id': 'turnover-1',
      'roomId': 'room-1',
      'room': {'name': 'A101'},
      'property': {'name': 'Property A'},
      'stage': stage,
      'status': 'ACTIVE',
      'version': 3,
      'steps': [
        {
          'stage': 'RETURNED',
          'title': 'Return keys',
          'completedAt': '2026-10-24T01:00:00Z'
        }
      ],
    };

void main() {
  test('turnovers forwards pagination and parses stage and step completion',
      () async {
    final adapter = _Adapter({
      'data': [_turnover()],
      'total': 41,
      'page': 2,
      'limit': 20,
    });
    final result = await _api(adapter).turnovers(page: 2);
    expect(adapter.request.path, '/operations/turnovers');
    expect(adapter.request.queryParameters, {'page': 2, 'limit': 20});
    expect(result.hasNext, isTrue);
    expect(result.items.single.roomName, 'A101');
    expect(result.items.single.stage, TurnoverStage.inspection);
    expect(result.items.single.steps.single.completedAt,
        DateTime.utc(2026, 10, 24, 1));
  });

  test('advance sends the current stage and version without skipping',
      () async {
    final adapter = _Adapter({'data': _turnover(stage: 'REPAIR')});
    final result = await _api(adapter)
        .advanceTurnover(RoomTurnover.fromJson(_turnover()), 'Checked');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/operations/turnovers/turnover-1/advance');
    expect(adapter.request.data,
        {'stage': 'INSPECTION', 'version': 3, 'note': 'Checked'});
    expect(result.stage, TurnoverStage.repair);
  });

  test('checklist update includes version and parses completion', () async {
    final adapter = _Adapter({
      'data': {
        'id': 'task-1',
        'title': 'Read meter',
        'status': 'COMPLETED',
        'version': 5,
        'checklist': [
          {'title': 'Water', 'done': true}
        ],
      }
    });
    final task = OperationTask.fromJson({'id': 'task-1', 'version': 4});
    final result = await _api(adapter).checkTask(task, 0, true);
    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/operations/tasks/task-1/checklist');
    expect(adapter.request.data, {'version': 4, 'index': 0, 'done': true});
    expect(result.status, 'completed');
    expect(result.checklist.single.done, isTrue);
  });

  test('recurring schedule creation forwards its complete payload', () async {
    final adapter = _Adapter({'data': <String, dynamic>{}});
    final payload = {
      'propertyId': 'property-1',
      'title': 'Read meters',
      'kind': 'meter_reading',
      'frequency': 'MONTHLY',
      'interval': 1,
      'nextRunAt': '2026-11-01T01:00:00Z',
      'checklist': ['Water', 'Electricity'],
    };
    await _api(adapter).createRecurring(payload);
    expect(adapter.request.path, '/operations/recurring');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.data, payload);
  });

  test('recurring schedules can be paused', () async {
    final adapter = _Adapter({'data': <String, dynamic>{}});
    await _api(adapter).toggleRecurring('schedule-1', false);
    expect(adapter.request.path, '/operations/recurring/schedule-1');
    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.data, {'isEnabled': false});
  });

  test('tenant feed parses its own acknowledgement', () async {
    final adapter = _Adapter({
      'data': [
        {
          'id': 'announcement-1',
          'title': 'Notice',
          'body': 'Details',
          'status': 'SENT',
          'sendAt': '2026-10-24T01:00:00Z',
          'recipients': [
            {'readAt': '2026-10-24T02:00:00Z'}
          ],
        }
      ],
    });
    final result = await _api(adapter).announcements(tenant: true);
    expect(adapter.request.path, '/tenant/announcements');
    expect(result.single.isRead, isTrue);
    expect(result.single.readAt, DateTime.utc(2026, 10, 24, 2));
  });

  test('landlord feed counts recipients and acknowledgements', () async {
    final adapter = _Adapter({
      'data': [
        {
          'id': 'announcement-1',
          'recipients': [
            {'tenantId': 'tenant-1', 'readAt': '2026-10-24T02:00:00Z'},
            {'tenantId': 'tenant-2', 'readAt': null},
          ],
        }
      ],
    });
    final result = await _api(adapter).announcements();
    expect(adapter.request.path, '/announcements');
    expect(result.single.recipientCount, 2);
    expect(result.single.readCount, 1);
  });

  test('acknowledgement posts only to the tenant endpoint', () async {
    final adapter = _Adapter({'data': <String, dynamic>{}});
    await _api(adapter).markAnnouncementRead('announcement-1');
    expect(adapter.request.path, '/tenant/announcements/announcement-1/read');
    expect(adapter.request.method, 'POST');
  });

  test('group creation sends the selected tenant IDs', () async {
    final adapter = _Adapter({'data': <String, dynamic>{}});
    await _api(adapter).createGroup('Group A', ['tenant-1', 'tenant-2']);
    expect(adapter.request.path, '/announcements/groups');
    expect(adapter.request.data, {
      'name': 'Group A',
      'tenantIds': ['tenant-1', 'tenant-2']
    });
  });

  test('payment creation parses QR, amount, expiry and pending status',
      () async {
    final adapter = _Adapter({
      'data': {
        'status': 'PENDING',
        'provider': 'DEMO_CARD',
        'demo': true,
        'invoice': {'isDemo': true},
        'checkoutUrl':
            'http://localhost:3000/api/v1/payments/demo/checkout/test',
        'qrCode': 'test-qr-payload',
        'amount': 3500000,
        'bankBin': '970422',
        'accountName': 'TEST BANK',
        'accountNumber': '123456789',
        'description': 'HD123',
        'expiresAt': '2026-10-24T02:00:00Z',
      },
    });
    final result = await _api(adapter).paymentLink('invoice-1');
    expect(adapter.request.path, '/tenant/invoices/invoice-1/payment-link');
    expect(adapter.request.method, 'POST');
    expect(result.status, 'pending');
    expect(result.provider, 'DEMO_CARD');
    expect(result.demo, isTrue);
    expect(result.invoiceIsDemo, isTrue);
    expect(result.amount, 3500000);
    expect(result.qrCode, 'test-qr-payload');
    expect(result.bankBin, '970422');
    expect(result.accountName, 'TEST BANK');
    expect(result.accountNumber, '123456789');
    expect(result.description, 'HD123');
    expect(result.expiresAt, DateTime.utc(2026, 10, 24, 2));
  });

  test('creates a separate demo invoice with an explicit POST', () async {
    final adapter = _Adapter({
      'data': {'id': 'demo-copy', 'isDemo': true}
    });
    expect(await _api(adapter).createDemoInvoice('original'), 'demo-copy');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/tenant/invoices/original/demo-invoice');
  });

  test('rejects a malformed demo invoice creation response', () async {
    final adapter = _Adapter({
      'data': {'isDemo': true}
    });
    await expectLater(_api(adapter).createDemoInvoice('original'),
        throwsA(isA<ApiFailure>()));
  });

  test('payment status permits an invoice without an existing link', () async {
    final adapter = _Adapter({'data': null});
    expect(await _api(adapter).paymentStatus('invoice-1'), isNull);
    expect(adapter.request.method, 'GET');
  });

  test('payment status uses invoice balance rather than paid link status',
      () async {
    final adapter = _Adapter({
      'data': {
        'status': 'PAID',
        'invoice': {
          'status': 'PARTIAL',
          'paidAmount': 500000,
          'remainingAmount': 1000000
        },
        'canPay': false,
        'canCreateLink': true,
        'reviewRequired': false,
      }
    });
    final result = (await _api(adapter).paymentStatus('invoice-1'))!;
    expect(result.invoicePaid, isFalse);
    expect(result.remainingAmount, 1000000);
    expect(result.paidAmount, 500000);
    expect(result.canPay, isFalse);
    expect(result.canCreateLink, isTrue);
  });

  test('payment status supports settled invoices without a payment link',
      () async {
    final adapter = _Adapter({
      'data': {
        'status': 'NOT_CREATED',
        'invoice': {
          'status': 'PAID',
          'paidAmount': 3500000,
          'remainingAmount': 0
        },
        'canPay': false,
        'canCreateLink': false,
      }
    });
    final result = (await _api(adapter).paymentStatus('invoice-1'))!;
    expect(result.invoicePaid, isTrue);
    expect(result.canPay, isFalse);
  });

  test('missing invoice summary cannot falsely mark a link as fully paid', () {
    expect(PaymentLinkInfo.fromJson({'status': 'PAID'}).invoicePaid, isFalse);
  });

  test('reconciliation uses the explicit invoice and event endpoint', () async {
    final adapter = _Adapter({'data': <String, dynamic>{}});
    await _api(adapter).reconcilePaymentEvent('invoice-1', 'event-1');
    expect(adapter.request.path,
        '/billing/invoices/invoice-1/payment-events/event-1/reconcile');
    expect(adapter.request.method, 'POST');
  });

  test('disabled demo retains the actionable 503', () async {
    final adapter = _Adapter({
      'message': 'Demo payments are disabled',
    }, status: 503);
    await expectLater(
        _api(adapter).paymentLink('invoice-1'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 503)
            .having((error) => error.message, 'message',
                'Demo payments are disabled')));
  });

  test('version conflict retains the backend error message', () async {
    final adapter = _Adapter({
      'error': {'code': 'CONFLICT', 'message': 'Reload the operation'}
    }, status: 409);
    await expectLater(
        _api(adapter).advanceTurnover(RoomTurnover.fromJson(_turnover()), 'OK'),
        throwsA(isA<ApiFailure>().having(
            (error) => error.message, 'message', 'Reload the operation')));
  });

  test('malformed pagination is a retryable API failure', () async {
    final adapter = _Adapter({'data': 'invalid'});
    await expectLater(_api(adapter).tasks(), throwsA(isA<ApiFailure>()));
  });

  test('malformed object responses do not escape as type errors', () async {
    final adapter = _Adapter({'data': []});
    await expectLater(_api(adapter).options(), throwsA(isA<ApiFailure>()));
  });
}
