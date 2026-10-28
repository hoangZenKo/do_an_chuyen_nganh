import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/rooms/room_api.dart';
import 'package:rental_room_management/features/billing/widgets/invoice_line_items.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/rooms/service_tariff_dialog.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/room.dart';

class _RoomApi extends RoomApi {
  _RoomApi() : super(Dio());
  Map<String, dynamic>? payload;
  String? feeId;
  ApiFailure? failure;
  Completer<void>? pending;
  int calls = 0;

  Future<RoomServiceFee> _result(Map<String, dynamic> input) async {
    payload = input;
    calls++;
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return const RoomServiceFee(
        id: 'fee',
        roomId: 'room',
        name: 'Internet',
        amount: 100000,
        isActive: true);
  }

  @override
  Future<RoomServiceFee> createServiceFee(
          String roomId, Map<String, dynamic> payload) =>
      _result(payload);

  @override
  Future<RoomServiceFee> updateServiceFee(
      String roomId, String feeId, Map<String, dynamic> payload) {
    this.feeId = feeId;
    return _result(payload);
  }
}

Future<void> _open(WidgetTester tester, _RoomApi api,
    {RoomServiceFee? fee}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [roomApiProvider.overrideWithValue(api)],
    child: MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              ServiceTariffDialog(roomId: 'room', fee: fee)),
                      child: const Text('Mở'),
                    )))),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Internet');
  await tester.enterText(find.byType(TextFormField).at(1), '150000');
}

void main() {
  test(
      'parses invoice line provenance and remains compatible with old payloads',
      () {
    final invoice = Invoice.fromJson({
      'id': 'invoice',
      'lineItems': [
        {
          'id': 'line',
          'kind': 'SERVICE',
          'description': 'Internet',
          'quantity': 1,
          'unit': 'thang',
          'unitPrice': 100000,
          'amount': 100000,
          'source': 'SERVICE_TARIFF',
          'tariffVersionId': 'version',
          'tariffVersion': 3
        },
      ]
    });
    expect(invoice.lineItems.single.tariffVersion, 3);
    expect(invoice.lineItems.single.unitLabel, 'tháng');
    expect(invoice.lineItems.single.source, 'service_tariff');
    expect(Invoice.fromJson({'id': 'legacy'}).lineItems, isEmpty);
  });

  test(
      'parses service tariff history and inclusive/exclusive period boundaries',
      () {
    final fee = RoomServiceFee.fromJson({
      'id': 'fee',
      'version': 2,
      'versions': [
        {
          'id': 'v2',
          'version': 2,
          'effectiveFrom': '2026-11-01T00:00:00Z',
          'amount': 120000
        },
        {
          'id': 'v1',
          'version': 1,
          'effectiveFrom': '2026-10-01T00:00:00Z',
          'effectiveTo': '2026-11-01T00:00:00Z',
          'amount': 100000
        },
      ]
    });
    expect(fee.version, 2);
    expect(fee.versions.last.effectiveTo, fee.versions.first.effectiveFrom);
  });

  testWidgets(
      'rejects blank names and invalid effective months before API writes',
      (tester) async {
    final api = _RoomApi();
    await _open(tester, api);
    await tester.tap(find.text('Lưu biểu phí'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên dịch vụ'), findsOneWidget);
    await _fill(tester);
    await tester.enterText(find.byType(TextFormField).at(3), '2026-13');
    await tester.tap(find.text('Lưu biểu phí'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tháng theo YYYY-MM'), findsOneWidget);
    expect(api.calls, 0);
  });

  testWidgets('creates a versioned fee with an explicit first-of-month date',
      (tester) async {
    final api = _RoomApi();
    await _open(tester, api);
    await _fill(tester);
    await tester.enterText(find.byType(TextFormField).at(3), '2027-02');
    await tester.tap(find.text('Lưu biểu phí'));
    await tester.pumpAndSettle();
    expect(api.payload, containsPair('effectiveFrom', '2027-02-01'));
    expect(api.payload, containsPair('amount', 150000));
    expect(find.byType(ServiceTariffDialog), findsNothing);
  });

  testWidgets('sends expectedVersion and preserves editor on conflict',
      (tester) async {
    final api = _RoomApi()
      ..failure =
          const ApiFailure(message: 'Stale', code: 'TARIFF_VERSION_CHANGED');
    const fee = RoomServiceFee(
        id: 'fee',
        roomId: 'room',
        name: 'Internet',
        amount: 100000,
        isActive: true,
        version: 4);
    await _open(tester, api, fee: fee);
    await tester.tap(find.text('Lưu biểu phí'));
    await tester.pumpAndSettle();
    expect(api.payload, containsPair('expectedVersion', 4));
    expect(api.feeId, 'fee');
    expect(find.textContaining('Biểu phí đã thay đổi'), findsOneWidget);
    expect(find.byType(ServiceTariffDialog), findsOneWidget);
  });

  testWidgets('disables duplicate submit while a write is pending',
      (tester) async {
    final api = _RoomApi()..pending = Completer<void>();
    await _open(tester, api);
    await _fill(tester);
    await tester.tap(find.text('Lưu biểu phí'));
    await tester.pump();
    await tester.tap(find.text('Đang lưu…'));
    expect(api.calls, 1);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hủy'))
            .onPressed,
        isNull);
    api.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ServiceTariffDialog), findsNothing);
  });

  testWidgets('line details wrap on narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: Scaffold(
          body: Padding(
              padding: EdgeInsets.all(16),
              child: InvoiceLineItems(items: [
                InvoiceLineItem(
                    id: 'line',
                    kind: 'service',
                    description: 'Dịch vụ vệ sinh và bảo dưỡng khu vực chung',
                    quantity: 1,
                    unit: 'thang',
                    unitPrice: 150000,
                    amount: 150000,
                    source: 'service_tariff',
                    tariffVersion: 2),
              ]))),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Biểu phí v2'), findsOneWidget);
  });
}
