import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/billing/billing_form_screen.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/models/billing.dart';

const _leases = [
  BillingLease(
      id: 'lease-1',
      roomId: 'room-1',
      roomName: 'A101',
      tenantId: 'tenant-1',
      tenantName: 'Nguyễn An',
      monthlyRent: 2500000),
  BillingLease(
      id: 'lease-2',
      roomId: 'room-2',
      roomName: 'A102',
      tenantId: 'tenant-2',
      tenantName: 'Trần Bình',
      monthlyRent: 3000000),
];

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));

  @override
  Future<List<MeterReading>> meterReadings(
          {String? roomId, String? month}) async =>
      [];
}

double _contrast(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance()
  ]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
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
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final viewport in [
    (width: 390.0, scale: 1.0, dark: true),
    (width: 320.0, scale: 1.5, dark: true),
    (width: 800.0, scale: 1.0, dark: false),
  ]) {
    testWidgets(
        'room menu stays light and selects the correct lease at $viewport',
        (tester) async {
      tester.view.physicalSize = Size(viewport.width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            billingLeasesForMonthProvider
                .overrideWith((ref, month) async => _leases),
            billingRepositoryProvider.overrideWithValue(_Repository()),
          ],
          child: MaterialApp(
            theme: viewport.dark ? AppTheme.dark : ThemeData.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(viewport.scale)),
                child: child!),
            home: const BillingFormScreen(),
          )));
      await tester.pumpAndSettle();
      final selector = find.byType(DropdownButtonFormField<BillingLease>);
      await tester.tap(selector);
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<BillingLease>>(
          find.byType(DropdownButton<BillingLease>));
      final menuColor = dropdown.dropdownColor ??
          Theme.of(tester.element(selector)).canvasColor;
      expect(menuColor, Colors.white);
      final option = find.text('Phòng A102 - Trần Bình').last;
      expect(option.hitTestable(), findsOneWidget);
      final textColor =
          DefaultTextStyle.of(tester.element(option)).style.color!;
      expect(_contrast(textColor, menuColor), greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);

      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DropdownButton<BillingLease>>(
                  find.byType(DropdownButton<BillingLease>))
              .value,
          _leases[1]);
      expect(find.text('Phòng A102'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
