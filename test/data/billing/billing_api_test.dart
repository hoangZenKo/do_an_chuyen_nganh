import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/models/billing.dart';

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

BillingApi _api(_RecordingAdapter adapter) {
  return BillingApi(
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
  test('activeLeases requests endpoint and parses data envelope', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"l1","roomId":"r1","roomName":"A101",'
        '"tenantId":"t1","tenantName":"Tenant","monthlyRent":1000,'
        '"startDate":"2026-01-01T00:00:00.000Z"}]}',
        200,
      ),
    );

    final leases = await _api(adapter).activeLeases();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/billing/active-leases');
    expect(leases.single.roomName, 'A101');
    expect(leases.single.monthlyRent, 1000);
  });

  test('invoices serializes filters and parses bare list responses', () async {
    final adapter = _RecordingAdapter(_json('[$_invoiceJson]', 200));

    final invoices = await _api(adapter).invoices(
      status: InvoiceStatus.partial,
      month: '2026-08',
      propertyId: 'p1',
    );

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/billing/invoices');
    expect(adapter.request.queryParameters, {
      'status': 'partial',
      'month': '2026-08',
      'propertyId': 'p1',
    });
    expect(invoices.single.status, InvoiceStatus.unpaid);
    expect(invoices.single.totalAmount, 1175);
  });

  test('invoice requests detail endpoint and parses cancellation metadata',
      () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"i1","leaseId":"l1","roomId":"r1",'
        '"tenantId":"t1","billingMonth":"2026-08-01T00:00:00.000Z",'
        '"rentAmount":1000,"electricityAmount":100,"waterAmount":50,'
        '"otherAmount":25,"totalAmount":1175,"paidAmount":0,'
        '"remainingAmount":1175,"status":"cancelled",'
        '"cancelledAt":"2026-08-09T00:00:00.000Z",'
        '"cancelledNote":"Lập nhầm","payments":[]}}',
        200,
      ),
    );

    final invoice = await _api(adapter).invoice('i1');

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/billing/invoices/i1');
    expect(invoice.status, InvoiceStatus.cancelled);
    expect(invoice.cancelledNote, 'Lập nhầm');
  });

  test('meterReadings serializes room and month filters', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"m1","roomId":"r1","utilityType":"water",'
        '"billingMonth":"2026-08-01T00:00:00.000Z",'
        '"previousReading":1,"currentReading":5,"unitPrice":1000,'
        '"usage":4,"amount":4000}]}',
        200,
      ),
    );

    final readings = await _api(adapter).meterReadings(
      roomId: 'r1',
      month: '2026-08-01',
    );

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/billing/meter-readings');
    expect(adapter.request.queryParameters, {
      'roomId': 'r1',
      'month': '2026-08-01',
    });
    expect(readings.single.utilityType, UtilityType.water);
  });

  test('createMeterReading posts payload and parses response', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"m1","roomId":"r1","utilityType":"electricity",'
        '"billingMonth":"2026-08-01T00:00:00.000Z",'
        '"previousReading":10,"currentReading":20,"unitPrice":3,'
        '"usage":10,"amount":30,"note":"ok"}}',
        201,
      ),
    );
    final payload = {
      'roomId': 'r1',
      'utilityType': 'electricity',
      'billingMonth': '2026-08',
      'previousReading': 10,
      'currentReading': 20,
      'unitPrice': 3,
    };

    final reading = await _api(adapter).createMeterReading(payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/meter-readings');
    expect(adapter.request.data, payload);
    expect(reading.usage, 10);
    expect(reading.amount, 30);
  });

  test('createInvoice posts payload and parses response', () async {
    final adapter = _RecordingAdapter(_json('{"data":$_invoiceJson}', 201));
    final payload = {
      'leaseId': 'l1',
      'billingMonth': '2026-08',
      'otherAmount': 25,
    };

    final invoice = await _api(adapter).createInvoice(payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/invoices');
    expect(adapter.request.data, payload);
    expect(invoice.id, 'i1');
  });

  test('aging requests scoped debt buckets', () async {
    final adapter = _RecordingAdapter(
      _json('{"data":{"summary":{"notDue":100},"groups":[]}}', 200),
    );
    final aging = await _api(adapter).aging(propertyId: 'p1', groupBy: 'room');
    expect(adapter.request.path, '/billing/aging');
    expect(adapter.request.queryParameters,
        {'propertyId': 'p1', 'groupBy': 'room'});
    expect(aging['summary'], isA<Map<String, dynamic>>());
  });

  test('creates a replacement invoice without exposing line item edits',
      () async {
    final adapter = _RecordingAdapter(_json('{"data":$_invoiceJson}', 201));
    final invoice = await _api(adapter).replaceInvoice('i1', {
      'requestKey': '00000000-0000-4000-8000-000000000001',
      'reason': 'Sai tiền thuê',
      'lines': [
        {
          'kind': 'RENT',
          'description': 'Tiền phòng',
          'quantity': 1,
          'unit': 'thang',
          'unitPrice': 1000
        },
      ],
    });
    expect(adapter.request.path, '/billing/invoices/i1/replacement');
    expect(adapter.request.method, 'POST');
    expect(invoice.id, 'i1');
  });

  test('posts a multi-invoice receipt allocation', () async {
    final adapter = _RecordingAdapter(
        _json('{"data":{"id":"r1","availableAmount":500}}', 201));
    final receipt = await _api(adapter).createReceipt({
      'requestKey': '00000000-0000-4000-8000-000000000002',
      'tenantId': 't1',
      'amount': 1500,
      'method': 'bank_transfer',
      'reference': 'bank-1',
      'allocations': [
        {'invoiceId': 'i1', 'amount': 1000},
      ],
    });
    expect(adapter.request.path, '/billing/receipts');
    expect(receipt['id'], 'r1');
  });

  test('bulkInvoicePreflight posts scope and parses readiness items', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"propertyId":"p1",'
        '"billingMonth":"2026-08-01T00:00:00.000Z",'
        '"totalCount":2,"readyCount":1,"existingCount":1,'
        '"items":[{"leaseId":"l1","roomId":"r1","roomName":"A101",'
        '"tenantId":"t1","tenantName":"Tenant","monthlyRent":1000,'
        '"status":"ready","invoice":null,'
        '"meterReadings":{"electricity":{"id":"m1","roomId":"r1",'
        '"utilityType":"electricity",'
        '"billingMonth":"2026-08-01T00:00:00.000Z",'
        '"previousReading":10,"currentReading":20,"unitPrice":3,'
        '"usage":10,"amount":30},"water":null},'
        '"suggestedMeterReadings":{"electricity":null,'
        '"water":{"id":"m0","roomId":"r1","utilityType":"water",'
        '"billingMonth":"2026-07-01T00:00:00.000Z",'
        '"previousReading":2,"currentReading":5,"unitPrice":10,'
        '"usage":3,"amount":30}}},'
        '{"leaseId":"l2","roomId":"r2","roomName":"A102",'
        '"tenantId":"t2","tenantName":"Tenant 2","monthlyRent":1200,'
        '"status":"existing","invoice":$_invoiceJson,'
        '"meterReadings":{"electricity":null,"water":null},'
        '"suggestedMeterReadings":{"electricity":null,"water":null}}]}}',
        200,
      ),
    );
    final payload = {'propertyId': 'p1', 'billingMonth': '2026-08-01'};

    final preflight = await _api(adapter).bulkInvoicePreflight(payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/invoices/bulk/preflight');
    expect(adapter.request.data, payload);
    expect(preflight.readyCount, 1);
    expect(preflight.existingCount, 1);
    expect(preflight.items.first.status, BulkInvoiceItemStatus.ready);
    expect(preflight.items.first.meterReadings.electricity?.amount, 30);
    expect(
        preflight.items.first.suggestedMeterReadings.water?.currentReading, 5);
    expect(preflight.items.last.invoice?.id, 'i1');
  });

  test('createBulkInvoices posts readings and parses result summary', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"propertyId":"p1",'
        '"billingMonth":"2026-08-01T00:00:00.000Z",'
        '"totalCount":2,"createdCount":1,"existingCount":1,'
        '"results":[{"leaseId":"l1","status":"created",'
        '"invoice":$_invoiceJson},{"leaseId":"l2","status":"existing",'
        '"invoice":$_invoiceJson}]}}',
        201,
      ),
    );
    final payload = {
      'propertyId': 'p1',
      'billingMonth': '2026-08-01',
      'dueDate': '2026-08-10',
      'readings': [
        {
          'leaseId': 'l1',
          'meterReadings': [
            {
              'utilityType': 'electricity',
              'previousReading': 10,
              'currentReading': 20,
              'unitPrice': 3,
            }
          ],
        }
      ],
    };

    final result = await _api(adapter).createBulkInvoices(payload);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/invoices/bulk');
    expect(adapter.request.data, payload);
    expect(result.createdCount, 1);
    expect(result.existingCount, 1);
    expect(result.results.first.status, BulkInvoiceItemStatus.created);
    expect(result.results.last.status, BulkInvoiceItemStatus.existing);
  });

  test('updateInvoice patches editable invoice fields', () async {
    final adapter = _RecordingAdapter(_json('{"data":$_invoiceJson}', 200));
    final invoice = await _api(adapter).updateInvoice('i1', {
      'dueDate': '2026-08-10',
      'note': 'Cập nhật',
    });

    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/billing/invoices/i1');
    expect(invoice.id, 'i1');
  });

  test('recordPayment posts payload to invoice payments endpoint', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"i1","leaseId":"l1","roomId":"r1",'
        '"tenantId":"t1","billingMonth":"2026-08-01T00:00:00.000Z",'
        '"rentAmount":1000,"electricityAmount":100,"waterAmount":50,'
        '"otherAmount":25,"totalAmount":1175,"paidAmount":1175,'
        '"remainingAmount":0,"status":"paid","payments":[{"id":"pay1",'
        '"invoiceId":"i1","amount":1175,"method":"cash"}]}}',
        201,
      ),
    );

    final invoice = await _api(adapter).recordPayment('i1', {
      'amount': 1175,
      'method': 'cash',
    });

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/invoices/i1/payments');
    expect(adapter.request.data, {'amount': 1175, 'method': 'cash'});
    expect(invoice.status, InvoiceStatus.paid);
    expect(invoice.payments.single.amount, 1175);
    expect(invoice.payments.single.method, PaymentMethod.cash);
  });

  test('cancelInvoice posts note to cancel endpoint', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"i1","leaseId":"l1","roomId":"r1",'
        '"tenantId":"t1","billingMonth":"2026-08-01T00:00:00.000Z",'
        '"rentAmount":1000,"electricityAmount":0,"waterAmount":0,'
        '"otherAmount":0,"totalAmount":1000,"paidAmount":0,'
        '"remainingAmount":1000,"status":"cancelled",'
        '"cancelledNote":"Lập nhầm","payments":[]}}',
        201,
      ),
    );

    final invoice = await _api(adapter).cancelInvoice('i1', {
      'note': 'Lập nhầm',
    });

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/invoices/i1/cancel');
    expect(adapter.request.data, {'note': 'Lập nhầm'});
    expect(invoice.status, InvoiceStatus.cancelled);
  });

  test('reversePayment posts note to reverse endpoint', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"i1","leaseId":"l1","roomId":"r1",'
        '"tenantId":"t1","billingMonth":"2026-08-01T00:00:00.000Z",'
        '"rentAmount":1000,"electricityAmount":0,"waterAmount":0,'
        '"otherAmount":0,"totalAmount":1000,"paidAmount":0,'
        '"remainingAmount":1000,"status":"unpaid","payments":[{"id":"p2",'
        '"invoiceId":"i1","amount":-1000,"method":"cash",'
        '"type":"reversal","reversalOfPaymentId":"p1"}]}}',
        201,
      ),
    );

    final invoice = await _api(adapter).reversePayment('i1', 'p1', {
      'note': 'Nhập nhầm',
    });

    expect(adapter.request.method, 'POST');
    expect(
      adapter.request.path,
      '/billing/invoices/i1/payments/p1/reverse',
    );
    expect(adapter.request.data, {'note': 'Nhập nhầm'});
    expect(invoice.payments.single.type, PaymentType.reversal);
  });

  test('paymentProofs requests pending proofs and parses response', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"proof1","invoiceId":"i1","tenantId":"t1",'
        '"tenantName":"Tenant","roomName":"A101","amount":1175,'
        '"method":"bank_transfer","status":"pending",'
        '"proofImageUrls":["https://example.com/proof.jpg"],'
        '"submittedAt":"2026-08-10T00:00:00.000Z"}]}',
        200,
      ),
    );

    final proofs = await _api(adapter).paymentProofs(status: 'pending');

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/billing/payment-proofs');
    expect(adapter.request.queryParameters, {'status': 'pending'});
    expect(proofs.single.id, 'proof1');
    expect(proofs.single.proofImageUrls, hasLength(1));
  });

  test('runInvoiceReminders posts query params and parses send result',
      () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"total":2,"sent":1,"failed":0,"skipped":1}}',
        201,
      ),
    );

    final result = await _api(adapter).runInvoiceReminders({
      'propertyId': 'p1',
      'dueSoonDays': '14',
    });

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/reminders/run');
    expect(adapter.request.queryParameters, {
      'propertyId': 'p1',
      'dueSoonDays': '14',
    });
    expect(result.total, 2);
    expect(result.sent, 1);
    expect(result.skipped, 1);
  });

  test('reviewPaymentProof posts decision payload', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"proof1","invoiceId":"i1","tenantId":"t1",'
        '"amount":1175,"method":"bank_transfer","status":"approved"}}',
        201,
      ),
    );

    final proof = await _api(adapter).reviewPaymentProof('proof1', {
      'status': 'approved',
      'note': 'Đã nhận tiền',
    });

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/billing/payment-proofs/proof1/review');
    expect(adapter.request.data, {
      'status': 'approved',
      'note': 'Đã nhận tiền',
    });
    expect(proof.status, 'approved');
  });

  test('maps Dio failures to ApiFailure', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"error":{"code":"DUPLICATE_INVOICE",'
        '"message":"Invoice already exists"}}',
        409,
      ),
    );

    await expectLater(
      _api(adapter).createInvoice({
        'leaseId': 'l1',
        'billingMonth': '2026-08',
      }),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'statusCode', 409)
            .having((failure) => failure.code, 'code', 'DUPLICATE_INVOICE'),
      ),
    );
  });
}
