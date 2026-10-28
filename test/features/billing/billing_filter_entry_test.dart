import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_screen.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';

import '../chatbot/chatbot_test_support.dart';

Invoice _invoice(String name, {bool overdue = false}) => Invoice(
      id: name,
      leaseId: 'lease-$name',
      roomId: name,
      roomName: name,
      tenantId: 'tenant-$name',
      billingMonth: DateTime(2026, 10),
      rentAmount: 1000000,
      electricityAmount: 0,
      waterAmount: 0,
      otherAmount: 0,
      totalAmount: 1000000,
      paidAmount: 0,
      remainingAmount: 1000000,
      status: InvoiceStatus.unpaid,
      isOverdue: overdue,
      dueDate: overdue ? DateTime(2020) : DateTime(2099),
    );

Future<void> _pump(WidgetTester tester, String? filter) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      invoicesProvider.overrideWith((ref) async => [
            _invoice('OVERDUE', overdue: true),
            _invoice('CURRENT'),
          ]),
      billingRemindersProvider.overrideWith((ref) async => const []),
      pendingPaymentProofsProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      home: Scaffold(body: BillingScreen(initialFilter: filter)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overdue entry filters out current invoices', (tester) async {
    await _pump(tester, 'overdue');
    expect(find.text('Phòng OVERDUE'), findsOneWidget);
    expect(find.text('Phòng CURRENT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final filter in <String?>[null, 'unknown']) {
    testWidgets('unrecognized entry $filter uses the normal all-invoice list',
        (tester) async {
      await _pump(tester, filter);
      expect(find.text('Phòng OVERDUE'), findsOneWidget);
      expect(find.text('Phòng CURRENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
