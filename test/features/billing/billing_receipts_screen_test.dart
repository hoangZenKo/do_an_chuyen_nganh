import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_receipts_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/billing_receipt.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
      user:
          LandlordUser(id: 'owner', fullName: 'Owner', email: 'owner@test.com'),
      accessToken: 'test',
      refreshToken: 'test'));
}

Invoice _invoice(String id, {int remaining = 100000}) => Invoice(
    id: id,
    leaseId: 'lease',
    roomId: 'room',
    tenantId: 'tenant',
    tenantName: 'Nguyễn Văn An',
    roomName: 'A101',
    billingMonth: DateTime(2026, 10),
    rentAmount: 100000,
    electricityAmount: 0,
    waterAmount: 0,
    otherAmount: 0,
    totalAmount: 100000,
    paidAmount: 100000 - remaining,
    remainingAmount: remaining,
    status: InvoiceStatus.unpaid);

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));
  final calls = <Map<String, dynamic>>[];
  bool failOnce = false;

  @override
  Future<List<Invoice>> invoices(
          {InvoiceStatus? status, String? month, String? propertyId}) async =>
      [_invoice('first'), _invoice('second')];

  @override
  Future<List<BillingReceipt>> receipts({String? tenantId}) async => [];

  @override
  Future<Map<String, dynamic>> createReceipt(
      {required String requestKey,
      required String tenantId,
      required int amount,
      required String reference,
      required List<Map<String, dynamic>> allocations,
      PaymentMethod method = PaymentMethod.bankTransfer,
      String? paidAt}) async {
    calls.add({
      'requestKey': requestKey,
      'amount': amount,
      'allocations': allocations
    });
    if (failOnce) {
      failOnce = false;
      throw const ApiFailure(message: 'Thử lại giao dịch');
    }
    return {};
  }
}

Future<void> _pump(WidgetTester tester, _Repository repository,
    {bool dialog = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        billingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
          home: dialog
              ? Scaffold(
                  body: Builder(
                      builder: (context) => TextButton(
                          onPressed: () => showDialog<bool>(
                              context: context,
                              builder: (_) => BillingReceiptCommandDialog(
                                      operation: ReceiptOperation.create,
                                      tenantId: 'tenant',
                                      invoices: [
                                        _invoice('first'),
                                        _invoice('second')
                                      ])),
                          child: const Text('Mở khoản thu'))))
              : const BillingReceiptsScreen(
                  tenantId: 'tenant', tenantName: 'Nguyễn Văn An'))));
  await tester.pumpAndSettle();
  if (dialog) {
    await tester.tap(find.text('Mở khoản thu'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
      'shows the empty receipt state without overflowing a mobile viewport',
      (tester) async {
    await _pump(tester, _Repository());
    expect(find.text('Khoản thu & phân bổ'), findsOneWidget);
    expect(find.text('Ghi nhận khoản thu'), findsOneWidget);
    expect(find.textContaining('Chưa có khoản thu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'prevents allocating more than the receipt and preserves one key across retries',
      (tester) async {
    final repository = _Repository()..failOnce = true;
    await _pump(tester, repository, dialog: true);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '150000');
    await tester.enterText(fields.at(1), 'BANK-TEST');
    await tester.ensureVisible(fields.at(2));
    await tester.enterText(fields.at(2), '100000');
    await tester.ensureVisible(fields.at(3));
    await tester.enterText(fields.at(3), '100000');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận khoản thu'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
    expect(find.text('Tổng phân bổ vượt số tiền có thể dùng.'), findsOneWidget);
    await tester.enterText(fields.at(3), '50000');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận khoản thu'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(1));
    expect(find.text('Thử lại giao dịch'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận khoản thu'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(2));
    expect(
        repository.calls[0]['requestKey'], repository.calls[1]['requestKey']);
    expect(repository.calls.last['allocations'], [
      {'invoiceId': 'first', 'amount': 100000},
      {'invoiceId': 'second', 'amount': 50000}
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'requires a refund reason and refuses a refund beyond available credit',
      (tester) async {
    final receipt = BillingReceipt(
        id: 'receipt',
        tenantId: 'tenant',
        amount: 100000,
        availableAmount: 20000,
        refundedAmount: 0,
        method: PaymentMethod.cash,
        reference: 'TEST',
        paidAt: DateTime(2026, 10));
    await tester.pumpWidget(ProviderScope(
        overrides: [sessionControllerProvider.overrideWith(_Session.new)],
        child: MaterialApp(
            home: Scaffold(
                body: BillingReceiptCommandDialog(
                    operation: ReceiptOperation.refund,
                    tenantId: 'tenant',
                    invoices: const [],
                    receipt: receipt)))));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '25000');
    await tester.enterText(fields.at(1), 'REFUND-TEST');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận hoàn tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Số tiền hoàn vượt tiền chưa phân bổ.'), findsOneWidget);
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
  });
}
