import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/models/billing.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Object body;
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

BillingRepository _repository(_Adapter adapter) => BillingRepository(BillingApi(
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter));

void main() {
  test('loads tenant receipts with allocation and refund history', () async {
    final adapter = _Adapter({
      'data': [
        {
          'id': 'receipt',
          'tenantId': 'tenant',
          'amount': 200000,
          'availableAmount': 50000,
          'refundedAmount': 25000,
          'method': 'BANK_TRANSFER',
          'reference': 'BANK-1',
          'paidAt': '2026-10-26T00:00:00Z',
          'allocations': [
            {
              'id': 'allocation',
              'amount': 125000,
              'payment': {'invoiceId': 'invoice'}
            }
          ],
          'refunds': [
            {
              'amount': 25000,
              'reason': 'Trả dư',
              'reference': 'REFUND-1',
              'createdAt': '2026-10-26T01:00:00Z'
            }
          ],
        }
      ]
    });
    final receipts = await _repository(adapter).receipts(tenantId: 'tenant');
    expect(adapter.request.path, '/billing/receipts');
    expect(adapter.request.queryParameters, {'tenantId': 'tenant'});
    expect(receipts.single.method, PaymentMethod.bankTransfer);
    expect(receipts.single.availableAmount, 50000);
    expect(receipts.single.allocations.single.invoiceId, 'invoice');
    expect(receipts.single.refunds.single.reference, 'REFUND-1');
  });

  test('releases allocations with a reason and stable command key', () async {
    final adapter = _Adapter({
      'data': {'id': 'receipt'}
    });
    await _repository(adapter).releaseAllocation(
        receiptId: 'receipt',
        allocationId: 'allocation',
        requestKey: 'stable-key',
        reason: '  Sửa phân bổ  ');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path,
        '/billing/receipts/receipt/allocations/allocation/release');
    expect(adapter.request.data,
        {'requestKey': 'stable-key', 'reason': 'Sửa phân bổ'});
  });

  test('posts refunds without deleting the receipt or its payments', () async {
    final adapter = _Adapter({
      'data': {'id': 'receipt'}
    });
    await _repository(adapter).refundReceipt(
        receiptId: 'receipt',
        requestKey: 'stable-key',
        amount: 50000,
        reference: '  BANK-REFUND  ',
        reason: '  Trả dư  ');
    expect(adapter.request.path, '/billing/receipts/receipt/refunds');
    expect(adapter.request.data, {
      'requestKey': 'stable-key',
      'amount': 50000,
      'reference': 'BANK-REFUND',
      'reason': 'Trả dư'
    });
  });
}
