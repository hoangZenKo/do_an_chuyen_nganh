import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/invoice_adjustment_dialog.dart';
import 'package:rental_room_management/models/billing.dart';

const _invoice = Invoice(
  id: 'invoice',
  leaseId: 'lease',
  roomId: 'room',
  tenantId: 'tenant',
  billingMonth: null,
  rentAmount: 100001,
  electricityAmount: 0,
  waterAmount: 0,
  otherAmount: 0,
  totalAmount: 100001,
  paidAmount: 90000,
  remainingAmount: 10001,
  status: InvoiceStatus.partial,
);

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));
  bool failOnce = false;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Invoice> adjustInvoice(
      {required String invoiceId,
      required String requestKey,
      required String kind,
      required String category,
      required String reason,
      int? amount,
      int? basisPoints}) async {
    calls.add({
      'requestKey': requestKey,
      'invoiceId': invoiceId,
      'kind': kind,
      'category': category,
      'amount': amount,
      'basisPoints': basisPoints,
      'reason': reason
    });
    if (failOnce) {
      failOnce = false;
      throw const ApiFailure(message: 'Mất kết nối');
    }
    return _invoice;
  }
}

Future<void> _pump(WidgetTester tester, _Repository repository) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [billingRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
          home: Scaffold(body: InvoiceAdjustmentDialog(invoice: _invoice)))));
  await tester.pumpAndSettle();
}

Future<void> _field(WidgetTester tester, int index, String value) async {
  final field = find.byType(TextFormField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('Phát hành phiếu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'discount percentage uses basis points and one idempotency key across retries',
      (tester) async {
    final repository = _Repository()..failOnce = true;
    await _pump(tester, repository);
    await tester.tap(find.text('Điều chỉnh chung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giảm giá').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await _field(tester, 0, '10,00');
    await _field(tester, 1, 'Giảm giá tháng này');
    await _submit(tester);
    expect(repository.calls.single, containsPair('kind', 'CREDIT'));
    expect(repository.calls.single, containsPair('category', 'DISCOUNT'));
    expect(repository.calls.single, containsPair('basisPoints', 1000));
    expect(repository.calls.single['amount'], isNull);
    await _submit(tester);
    expect(repository.calls[0], repository.calls[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'percentage credit cannot exceed remaining balance or have over two decimals',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await _field(tester, 1, 'Lý do');
    for (final percentage in ['11', '0', '100.01', '1.001']) {
      await _field(tester, 0, percentage);
      await _submit(tester);
      expect(repository.calls, isEmpty);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed tenant waiver sends an independent adjustment category',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.tap(find.text('Điều chỉnh chung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Miễn giảm theo người thuê').last);
    await tester.pumpAndSettle();
    await _field(tester, 0, '5000');
    await _field(tester, 1, 'Hỗ trợ người thuê');
    await _submit(tester);
    expect(repository.calls.single, containsPair('category', 'TENANT_WAIVER'));
    expect(repository.calls.single, containsPair('amount', 5000));
    expect(repository.calls.single['basisPoints'], isNull);
  });
}
