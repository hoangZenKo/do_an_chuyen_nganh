import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/core/utils/format.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/tenants/lease_form_screen.dart';
import 'package:rental_room_management/models/room.dart';

const _room = Room(
  id: 'room',
  propertyId: 'property',
  name: 'A101',
  status: RoomStatus.vacant,
  basePrice: 3500000,
);

Future<void> _mount(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      selectedPropertyProvider.overrideWith((ref) => 'property'),
      roomsProvider('property').overrideWith((ref) async => [_room]),
    ],
    child: MaterialApp(
      theme: theme,
      home: const LeaseFormScreen(tenantId: 'tenant'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in [AppTheme.dark, ThemeData.light(useMaterial3: true)]) {
    testWidgets('lease controls follow the ${theme.brightness.name} theme',
        (tester) async {
      await _mount(tester, theme);
      final scheme = theme.colorScheme;

      final rentInput = tester.widget<TextField>(find.byType(TextField).first);
      expect(rentInput.style?.color, scheme.onSurface);
      expect(
        rentInput.decoration?.fillColor,
        theme.inputDecorationTheme.fillColor,
      );
      final label = tester.widget<Text>(find.text('Chọn phòng trống'));
      expect(label.style?.color, scheme.onSurface);

      final roomInput = find.ancestor(
        of: find.byType(DropdownButton<Room>),
        matching: find.byType(InputDecorator),
      );
      expect(roomInput, findsOneWidget);

      final dateInput = find.ancestor(
        of: find.text(formatDate(DateTime.now())),
        matching: find.byType(InputDecorator),
      );
      expect(dateInput, findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.backgroundColor?.resolve({}), scheme.primary);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('room selection, validation and date picking remain usable',
      (tester) async {
    await _mount(tester, AppTheme.dark);
    await tester.tap(find.byType(DropdownButton<Room>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A101 · ${formatCurrencyVnd(3500000)}').last);
    await tester.pumpAndSettle();
    final rentInput =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(rentInput.controller?.text, '3500000');

    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo hợp đồng'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập giá thuê hợp lệ'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lease error banner uses semantic theme colors', (tester) async {
    final theme = AppTheme.dark;
    await _mount(tester, theme);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo hợp đồng'));
    await tester.pumpAndSettle();
    final banner = tester.widget<Container>(find.ancestor(
      of: find.text('Vui lòng chọn phòng.'),
      matching: find.byType(Container),
    ));
    expect((banner.decoration as BoxDecoration).color,
        theme.colorScheme.errorContainer);
    final message = tester.widget<Text>(find.text('Vui lòng chọn phòng.'));
    expect(message.style?.color, theme.colorScheme.onErrorContainer);
  });

  testWidgets('lease form fits a small phone with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _mount(tester, AppTheme.dark);
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Tạo hợp đồng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
