import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_screen.dart';
import 'package:rental_room_management/features/billing/invoice_detail_screen.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/tenant_portal.dart';
import '../chatbot/chatbot_test_support.dart';

class Reviewer extends BillingPaymentController {
  int calls = 0;
  @override
  Future<Invoice?> build() async => null;
  @override
  Future<void> reviewPaymentProof(
      {required String proofId,
      required String invoiceId,
      required String status,
      String? note}) async {
    calls++;
  }
}

void main() {
  for (final scenario in [
    (detail: false, switchAccount: false),
    (detail: false, switchAccount: true),
    (detail: true, switchAccount: false),
    (detail: true, switchAccount: true),
  ]) {
    final switchAccount = scenario.switchAccount;
    testWidgets(
        '${scenario.detail ? 'invoice detail' : 'billing list'}: ${switchAccount ? 'old review cannot write after switching account' : 'approval requires confirmation of actual funds received'}',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = ChatTestSession();
      final reviewer = Reviewer();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith(() => session),
            billingPaymentControllerProvider.overrideWith(() => reviewer),
            invoicesProvider.overrideWith((ref) async => []),
            invoiceProvider.overrideWith((ref, id) async => Invoice(
                id: id,
                leaseId: 'lease',
                roomId: 'room',
                tenantId: 'tenant',
                billingMonth: DateTime(2026, 10),
                rentAmount: 10000,
                electricityAmount: 0,
                waterAmount: 0,
                otherAmount: 0,
                totalAmount: 10000,
                paidAmount: 0,
                remainingAmount: 10000,
                status: InvoiceStatus.unpaid)),
            billingRemindersProvider.overrideWith((ref) async => []),
            pendingPaymentProofsProvider.overrideWith((ref) async => const [
                  PaymentProof(
                      id: 'proof',
                      invoiceId: 'invoice',
                      tenantId: 'tenant',
                      amount: 10000,
                      method: 'bank_transfer',
                      status: 'pending')
                ]),
          ],
          child: MaterialApp(
              home: scenario.detail
                  ? const InvoiceDetailScreen(invoiceId: 'invoice')
                  : const Scaffold(body: BillingScreen()))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Duyệt'));
      await tester.tap(find.text('Duyệt'));
      await tester.pumpAndSettle();
      final approve = find.widgetWithText(ElevatedButton, 'Duyệt');
      expect(tester.widget<ElevatedButton>(approve).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(approve).onPressed, isNotNull);
      if (switchAccount) {
        session.change(chatSession('other'));
        await tester.pumpAndSettle();
      }
      await tester.tap(approve);
      await tester.pumpAndSettle();
      expect(reviewer.calls, switchAccount ? 0 : 1);
    });
  }
}
