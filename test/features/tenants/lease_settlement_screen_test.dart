import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/tenants/lease_settlement_api.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/tenants/lease_settlement_screen.dart';
import 'package:rental_room_management/models/lease.dart';

final _identity = StateProvider<String?>((ref) => 'owner');
const _lease = Lease(
    id: 'lease',
    roomId: 'room',
    tenantId: 'tenant',
    status: LeaseStatus.active,
    monthlyRent: 3100000,
    roomName: 'A101');

Map<String, dynamic> _summary() => {
      'id': 'settlement',
      'version': 1,
      'refundStatus': 'PENDING',
      'previewFingerprint': List.filled(64, 'a').join(),
      'rentAmount': 1500000,
      'electricityAmount': 0,
      'waterAmount': 0,
      'otherCharges': 0,
      'totalCharges': 1500000,
      'depositBalance': 2000000,
      'depositApplied': 1500000,
      'refundAmount': 500000,
      'balanceDue': 0,
      'outstandingInvoiceAmount': 0,
      'lines': [
        {'description': 'Tiền thuê', 'amount': 1500000}
      ],
      'snapshot': {
        'warnings': ['Công nợ hóa đơn cũ hiển thị riêng.']
      },
    };

class _Api extends LeaseSettlementApi {
  _Api() : super(Dio(), ownerId: 'owner');
  Map<String, dynamic>? existing;
  Completer<Map<String, dynamic>?>? pendingLoad;
  bool failConfirmation = false;
  final confirmations = <Map<String, dynamic>>[];
  final refunds = <Map<String, dynamic>>[];
  int loads = 0;
  int previews = 0;

  @override
  Future<Map<String, dynamic>?> get(String leaseId) async {
    loads++;
    return pendingLoad == null ? existing : pendingLoad!.future;
  }

  @override
  Future<Map<String, dynamic>> preview(
      String leaseId, Map<String, dynamic> input) async {
    previews++;
    return _summary();
  }

  @override
  Future<Map<String, dynamic>> confirm(
      String leaseId, Map<String, dynamic> input) async {
    confirmations.add(Map.of(input));
    if (failConfirmation) {
      throw const ApiFailure(message: 'Mất kết nối, thử lại.');
    }
    return _summary();
  }

  @override
  Future<Map<String, dynamic>> refund(
      String leaseId, Map<String, dynamic> input) async {
    refunds.add(Map.of(input));
    return {
      ..._summary(),
      'version': 2,
      'refundStatus': 'PAID',
      'refundReference': input['reference']
    };
  }
}

Future<ProviderContainer> _mount(WidgetTester tester, _Api api,
    {bool access = true}) async {
  final container = ProviderContainer(overrides: [
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
    leaseSettlementAccessProvider.overrideWith((ref) => access),
    leaseSettlementApiProvider.overrideWith((ref) => api),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: AppTheme.dark,
          home: const LeaseSettlementScreen(lease: _lease))));
  await tester.pump();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _preview(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('moveOutDate')), '2026-08-15');
  await tester.ensureVisible(find.byKey(const ValueKey('note')));
  await tester.enterText(
      find.byKey(const ValueKey('note')), 'Khách trả phòng theo thỏa thuận.');
  await _tap(tester, find.text('Xem trước quyết toán'));
}

Future<void> _confirm(WidgetTester tester) async {
  await _tap(tester, find.text('Xác nhận trả phòng'));
  await tester.tap(find.text('Xác nhận trả phòng').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requires valid input before requesting a preview',
      (tester) async {
    final api = _Api();
    await _mount(tester, api);
    await _tap(tester, find.text('Xem trước quyết toán'));
    expect(api.previews, 0);
    expect(find.text('Nêu lý do và các chi phí, tối thiểu 10 ký tự.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms on mobile without implicitly refunding the deposit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _Api();
    await _mount(tester, api);
    await _preview(tester);
    expect(api.previews, 1);
    await _confirm(tester);
    expect(api.confirmations.single['previewFingerprint'],
        _summary()['previewFingerprint']);
    expect(api.confirmations.single['idempotencyKey'],
        matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(find.text('Quyết toán đã xác nhận'), findsOneWidget);
    expect(api.refunds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reuses the same confirmation key after a network error',
      (tester) async {
    final api = _Api()..failConfirmation = true;
    await _mount(tester, api);
    await _preview(tester);
    await _confirm(tester);
    expect(api.confirmations, hasLength(1));
    expect(find.text('Xác nhận trả phòng'), findsOneWidget);
    expect(find.text('Mất kết nối, thử lại.'), findsWidgets);
    api.failConfirmation = false;
    await _confirm(tester);
    expect(api.confirmations, hasLength(2));
    expect(api.confirmations.first, api.confirmations.last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing input invalidates the previous preview', (tester) async {
    final api = _Api();
    await _mount(tester, api);
    await _preview(tester);
    expect(find.text('Xác nhận trả phòng'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('damage')));
    await tester.enterText(find.byKey(const ValueKey('damage')), '100000');
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận trả phòng'), findsNothing);
    expect(api.confirmations, isEmpty);
  });

  testWidgets(
      'records the refund only after receipt details and explicit confirmation',
      (tester) async {
    final api = _Api()..existing = _summary();
    await _mount(tester, api);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Ghi nhận đã hoàn cọc'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã chuyển khoản / biên nhận'),
        'BANK-123');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Ghi chú xác nhận'),
        'Khách đã nhận lại tiền cọc.');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
    await tester.pumpAndSettle();
    expect(api.refunds.single, containsPair('version', 1));
    expect(api.refunds.single, containsPair('reference', 'BANK-123'));
    expect(find.text('Đã ghi nhận hoàn cọc · BANK-123'), findsOneWidget);
    expect(find.text('Ghi nhận đã hoàn cọc'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not query the API without landlord access', (tester) async {
    final api = _Api();
    await _mount(tester, api, access: false);
    expect(api.loads, 0);
    expect(find.text('Phiên đăng nhập hoặc quyền truy cập đã thay đổi.'),
        findsOneWidget);
  });

  testWidgets('discards a late response after switching accounts',
      (tester) async {
    final api = _Api()..pendingLoad = Completer<Map<String, dynamic>?>();
    final container = await _mount(tester, api);
    container.read(_identity.notifier).state = 'another-owner';
    await tester.pump();
    api.pendingLoad!.complete(_summary());
    await tester.pumpAndSettle();
    expect(find.text('Phiên đăng nhập hoặc quyền truy cập đã thay đổi.'),
        findsOneWidget);
    expect(find.text('Quyết toán đã xác nhận'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
