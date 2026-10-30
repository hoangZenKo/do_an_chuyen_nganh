import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/maintenance/maintenance_form_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';
import 'package:rental_room_management/features/tenants/widgets/form_widgets.dart';

Future<void> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: [
    selectedPropertyProvider.overrideWith((_) => 'property-b'),
    propertiesProvider.overrideWith((_) async => [
          const Property(id: 'property-a', name: 'Property A', address: 'QA'),
          const Property(id: 'property-b', name: 'Property B', address: 'QA'),
        ]),
    roomsProvider.overrideWith((ref, id) async => [
          Room(
            id: 'room-$id',
            propertyId: id,
            name: 'A101',
            status: RoomStatus.vacant,
            basePrice: 1000,
          )
        ]),
  ], child: const MaterialApp(home: MaintenanceFormScreen())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('new repair uses the currently selected property',
      (tester) async {
    await mount(tester);
    final dropdown = tester.widget<DropdownButtonFormField<Property>>(
        find.byType(DropdownButtonFormField<Property>));
    expect(dropdown.initialValue?.id, 'property-b');
  });
  testWidgets('rejects impossible dates and overflowing costs before API calls',
      (tester) async {
    await mount(tester);
    await tester.enterText(
        find.descendant(
            of: find.widgetWithText(AppTextField, 'Ngày báo'),
            matching: find.byType(TextFormField)),
        '2026-02-30');
    await tester.enterText(
        find.descendant(
            of: find.widgetWithText(AppTextField, 'Chi phí dự kiến (đ)'),
            matching: find.byType(TextFormField)),
        '2147483648');
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pump();
    expect(find.text('Nhập ngày hợp lệ (YYYY-MM-DD).'), findsOneWidget);
    expect(find.text('Chi phí phải từ 0 đến 2.147.483.647 đ.'), findsOneWidget);
  });
}
