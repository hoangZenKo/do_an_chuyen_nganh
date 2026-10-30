import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/data/tenants/tenant_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/lease.dart';
import 'package:rental_room_management/models/tenant.dart';

class _Repository extends Mock implements TenantRepository {}

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
          id: 'landlord-test',
          fullName: 'Landlord',
          email: 'landlord@example.test',
          role: 'landlord',
        ),
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
      ));
}

const _tenant = Tenant(id: 'tenant-test', fullName: 'Deposit Test');
const _lease = Lease(
  id: 'lease-test',
  roomId: 'room-test',
  roomName: 'P.201',
  tenantId: 'tenant-test',
  status: LeaseStatus.active,
  monthlyRent: 3000000,
);

Future<_Repository> _openDeposit(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Repository();
  final container = ProviderContainer(overrides: [
    sessionControllerProvider.overrideWith(_Session.new),
    tenantRepositoryProvider.overrideWithValue(repository),
    tenantDetailProvider.overrideWith((_, __) async => _tenant),
    tenantLeasesProvider.overrideWith((_, __) async => [_lease]),
    tenantOverviewProvider
        .overrideWith((_, __) async => TenantOverview.fromJson({})),
  ]);
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(tenantDetailPath(_tenant.id));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const RentalRoomApp(),
  ));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Cọc'), 250);
  await tester.drag(find.byType(ListView).first, const Offset(0, -250));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cọc'));
  await tester.pumpAndSettle();
  expect(find.text('Ghi nhận tiền cọc'), findsOneWidget);
  expect(tester.takeException(), isNull);
  return repository;
}

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
    }
  });
  testWidgets(
      'deposit opens and cancels after editing without lifecycle errors',
      (tester) async {
    final repository = await _openDeposit(tester);
    await tester.enterText(find.byType(TextField).first, '1000000');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ghi nhận tiền cọc'), findsNothing);
    verifyNever(() => repository.createDepositTransaction(any(),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        note: any(named: 'note')));
  });

  for (final entry in {
    'collected': 'Thu cọc',
    'refunded': 'Hoàn cọc',
    'deducted': 'Khấu trừ',
    'adjustment': 'Điều chỉnh tăng',
  }.entries) {
    testWidgets('saves ${entry.key} once and survives the provider refresh',
        (tester) async {
      final repository = await _openDeposit(tester);
      when(() => repository.createDepositTransaction(
            _lease.id,
            type: entry.key,
            amount: 1000000,
            note: 'Deposit QA',
          )).thenAnswer((_) async => DepositTransaction(
            id: 'transaction-test',
            leaseId: _lease.id,
            type: entry.key,
            amount: 1000000,
          ));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1000000');
      await tester.enterText(find.byType(TextField).last, 'Deposit QA');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Đã ghi nhận giao dịch cọc.'), findsOneWidget);
      verify(() => repository.createDepositTransaction(
            _lease.id,
            type: entry.key,
            amount: 1000000,
            note: 'Deposit QA',
          )).called(1);
    });
  }

  testWidgets('validates amount and remains usable with the keyboard open',
      (tester) async {
    final repository = await _openDeposit(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số tiền hợp lệ.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi nhận tiền cọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    verifyNever(() => repository.createDepositTransaction(any(),
        type: any(named: 'type'),
        amount: any(named: 'amount'),
        note: any(named: 'note')));
  });

  testWidgets('barrier dismissal and reopening creates fresh controllers',
      (tester) async {
    await _openDeposit(tester);
    await tester.enterText(find.byType(TextField).first, '1000000');
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cọc'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ghi nhận tiền cọc'), findsNothing);
  });

  testWidgets('server failure shows feedback without a dialog lifecycle crash',
      (tester) async {
    final repository = await _openDeposit(tester);
    when(() => repository.createDepositTransaction(any(),
            type: any(named: 'type'),
            amount: any(named: 'amount'),
            note: any(named: 'note')))
        .thenThrow(Exception('Deposit request failed'));
    await tester.enterText(find.byType(TextField).first, '1000000');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Deposit request failed'), findsOneWidget);
  });
}
