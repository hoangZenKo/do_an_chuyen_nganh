import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/invoice_replacement_screen.dart';
import 'package:rental_room_management/models/billing.dart';

Invoice _invoice({int paid = 0, List<InvoiceLineItem> lines = const []}) =>
    Invoice(
      id: 'original',
      leaseId: 'lease',
      roomId: 'room',
      tenantId: 'tenant',
      roomName: 'A101',
      billingMonth: DateTime(2026, 10),
      rentAmount: 100000,
      electricityAmount: 0,
      waterAmount: 0,
      otherAmount: 0,
      totalAmount: 100000,
      paidAmount: paid,
      remainingAmount: 100000 - paid,
      status: InvoiceStatus.unpaid,
      lineItems: lines,
    );

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));
  final calls = <Map<String, dynamic>>[];
  int failures = 0;

  @override
  Future<Invoice> replaceInvoice(
      {required String invoiceId,
      required String requestKey,
      required String reason,
      required List<Map<String, dynamic>> lines,
      String? dueDate}) async {
    calls.add({
      'invoiceId': invoiceId,
      'requestKey': requestKey,
      'reason': reason,
      'lines': lines,
      'dueDate': dueDate
    });
    if (failures > 0) {
      failures--;
      throw const ApiFailure(message: 'Lỗi mạng. Thử lại.');
    }
    return _invoice();
  }
}

Future<void> _pump(WidgetTester tester, _Repository repository,
    {Invoice? invoice}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
        home: InvoiceReplacementScreen(invoice: invoice ?? _invoice())),
  ));
  await tester.pumpAndSettle();
}

Finder _field(int index) => find.byType(TextFormField).at(index);

Future<void> _submit(WidgetTester tester) async {
  final button = find.text('Hủy bản gốc và phát hành bản thay thế');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requires reason and retains the original invoice snapshot',
      (tester) async {
    final repository = _Repository();
    final original = _invoice();
    await _pump(tester, repository, invoice: original);
    await _submit(tester);
    expect(repository.calls, isEmpty);
    await tester.ensureVisible(_field(0));
    expect(find.text('Nhập lý do thay thế.'), findsOneWidget);
    await tester.enterText(_field(0), 'Sai tiền phòng');
    await tester.ensureVisible(_field(4));
    await tester.enterText(_field(4), '120000');
    await _submit(tester);
    expect(repository.calls.single['invoiceId'], 'original');
    expect(repository.calls.single['reason'], 'Sai tiền phòng');
    expect(repository.calls.single['lines'], [
      {
        'kind': 'RENT',
        'description': 'Tiền phòng',
        'quantity': 1,
        'unit': 'lan',
        'unitPrice': 120000
      },
    ]);
    expect(original.totalAmount, 100000);
    expect(original.status, InvoiceStatus.unpaid);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'keeps the key across retries but rotates it when payload changes',
      (tester) async {
    final repository = _Repository()..failures = 2;
    await _pump(tester, repository);
    await tester.enterText(_field(0), 'Sai số liệu');
    await _submit(tester);
    await _submit(tester);
    expect(repository.calls, hasLength(2));
    expect(repository.calls[0], repository.calls[1]);
    await tester.ensureVisible(_field(4));
    await tester.enterText(_field(4), '110000');
    await _submit(tester);
    expect(repository.calls[2]['requestKey'],
        isNot(repository.calls[1]['requestKey']));
  });

  testWidgets('rejects negative non-discount prices and integer overflow',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.enterText(_field(0), 'Sai tiền phòng');
    await tester.ensureVisible(_field(4));
    await tester.enterText(_field(4), '-1');
    await _submit(tester);
    expect(repository.calls, isEmpty);
    expect(find.text('Chỉ dòng giảm giá được có đơn giá âm.'), findsOneWidget);
    await tester.enterText(_field(4), '2147483648');
    await _submit(tester);
    expect(repository.calls, isEmpty);
    expect(find.text('Đơn giá/thành tiền ngoài giới hạn.'), findsOneWidget);
  });

  testWidgets('blocks invoices with collected money', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository, invoice: _invoice(paid: 100));
    expect(
        find.textContaining('Không thể thay thế hóa đơn này.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
      'normalizes zero-usage and adjustment lines without changing totals',
      (tester) async {
    final repository = _Repository();
    final invoice = _invoice(lines: const [
      InvoiceLineItem(
          id: 'rent',
          kind: 'rent',
          description: 'Thuê',
          quantity: 1,
          unit: 'thang',
          unitPrice: 100000,
          amount: 100000,
          source: 'lease'),
      InvoiceLineItem(
          id: 'power',
          kind: 'electricity',
          description: 'Điện',
          quantity: 0,
          unit: 'kWh',
          unitPrice: 4000,
          amount: 0,
          source: 'meter'),
      InvoiceLineItem(
          id: 'note',
          kind: 'credit_note',
          description: 'Giảm',
          quantity: 1,
          unit: 'lan',
          unitPrice: -1000,
          amount: -1000,
          source: 'adjustment_note'),
    ]);
    await _pump(tester, repository, invoice: invoice);
    await tester.enterText(_field(0), 'Điều chỉnh nội dung');
    await _submit(tester);
    final lines = repository.calls.single['lines'] as List;
    expect(lines[1], containsPair('quantity', 1));
    expect(lines[1], containsPair('unitPrice', 0));
    expect(lines[2], containsPair('kind', 'DISCOUNT'));
    expect(invoice.lineItems[1].quantity, 0);
    expect(tester.takeException(), isNull);
  });
}
