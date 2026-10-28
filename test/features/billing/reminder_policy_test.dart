import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/reports/reports_screen.dart';

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));

  final calls = <Map<String, dynamic>>[];
  bool failOnce = false;

  @override
  Future<Map<String, dynamic>> updateReminderPolicy({
    required String requestKey,
    required int expectedVersion,
    String? propertyId,
    required bool enabled,
    required List<int> beforeDays,
    required bool onDueDate,
    required List<int> overdueDays,
    required List<String> channels,
  }) async {
    calls.add({
      'requestKey': requestKey,
      'expectedVersion': expectedVersion,
      'propertyId': propertyId,
      'enabled': enabled,
      'beforeDays': beforeDays,
      'onDueDate': onDueDate,
      'overdueDays': overdueDays,
      'channels': channels,
    });
    if (failOnce) {
      failOnce = false;
      throw const ApiFailure(message: 'Mất kết nối. Thử lại.');
    }
    return {};
  }
}

const _payload = <String, dynamic>{
  'policy': {
    'version': 0,
    'enabled': false,
    'beforeDays': [3, 1],
    'onDueDate': true,
    'overdueDays': [1, 7, 30],
    'channels': ['APP'],
  },
  'inherited': {
    'version': 9,
    'enabled': true,
    'beforeDays': [5],
    'onDueDate': false,
    'overdueDays': [8, 31],
    'channels': ['APP', 'EMAIL'],
  },
};

Future<void> _open(WidgetTester tester, _Repository repository,
    {bool dark = false, double textScale = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [billingRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const Scaffold(
          body: SingleChildScrollView(
        child: ReminderPolicyCard(payload: _payload, propertyId: 'property-a'),
      )),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Đang bật'), findsOneWidget);
  expect(find.textContaining('5 ngày'), findsOneWidget);
  await tester.tap(find.text('Cấu hình'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edits inherited values with the local scope and version zero',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(repository.calls.single, containsPair('propertyId', 'property-a'));
    expect(repository.calls.single, containsPair('expectedVersion', 0));
    expect(repository.calls.single, containsPair('enabled', true));
    expect(repository.calls.single, containsPair('beforeDays', [5]));
    expect(repository.calls.single, containsPair('overdueDays', [8, 31]));
    expect(repository.calls.single, containsPair('onDueDate', false));
    expect(repository.calls.single, containsPair('channels', ['APP', 'EMAIL']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry retains the same idempotency key and expected version',
      (tester) async {
    final repository = _Repository()..failOnce = true;
    await _open(tester, repository);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối. Thử lại.'), findsOneWidget);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(2));
    expect(repository.calls[0], repository.calls[1]);
  });

  testWidgets('validates duplicate and out-of-range days; permits empty lists',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    final fields = find.byType(TextField);
    for (final invalid in ['2, 2', '366', 'a', '0', '1,']) {
      await tester.enterText(fields.at(0), invalid);
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(repository.calls, isEmpty);
      expect(find.textContaining('Mỗi danh sách tối đa'), findsOneWidget);
    }
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(repository.calls.single['beforeDays'], isEmpty);
    expect(repository.calls.single['overdueDays'], isEmpty);
  });

  testWidgets('supports dark mode and larger text on mobile', (tester) async {
    await _open(tester, _Repository(), dark: true, textScale: 1.4);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('ZALO'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
