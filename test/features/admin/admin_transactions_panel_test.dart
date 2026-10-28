import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_transactions_panel.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

void main() {
  testWidgets('transaction investigation fits mobile with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <AdminRequest>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionIdentityProvider.overrideWithValue('operator'),
          adminCapabilitiesProvider.overrideWith(
              (_) async => const AdminCapabilities(['admin.finance.read'])),
          adminResourceProvider.overrideWith((ref, request) async {
            requests.add(request);
            return {
              'data': [
                {
                  'id': '11111111-1111-4111-8111-111111111111',
                  'amount': 3500000,
                  'status': 'FAILED',
                  'provider': 'DEMO_CARD',
                  'orderCode': 123
                }
              ],
              'meta': {'total': 1}
            };
          }),
        ],
        child: MaterialApp(
            home: const Scaffold(
                body: SingleChildScrollView(child: AdminTransactionsPanel())),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(requests.single.query, containsPair('kind', 'LINK'));
    final end = DateTime.parse(requests.single.query['to'] as String).toLocal();
    expect(
        [end.hour, end.minute, end.second, end.millisecond], [23, 59, 59, 999]);
    expect(find.textContaining('3500000 VND'), findsOneWidget);
    expect(
        find.textContaining('không phải doanh thu nền tảng'), findsOneWidget);
    await tester.ensureVisible(find.text('Thu / hoàn'));
    await tester.tap(find.text('Thu / hoàn'));
    await tester.pumpAndSettle();
    expect(requests.last.query, containsPair('kind', 'PAYMENT'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction panel never fetches without finance read permission',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionIdentityProvider.overrideWithValue('operator'),
          adminCapabilitiesProvider
              .overrideWith((_) async => const AdminCapabilities([])),
          adminResourceProvider.overrideWith((ref, request) async {
            reads++;
            return {'data': []};
          }),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body:
                    SingleChildScrollView(child: AdminTransactionsPanel())))));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.textContaining('không có quyền'), findsOneWidget);
  });
}
