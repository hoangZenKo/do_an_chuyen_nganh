import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/maintenance/maintenance_providers.dart';
import 'package:rental_room_management/features/maintenance/maintenance_screen.dart';
import 'package:rental_room_management/features/rooms/room_detail_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/maintenance.dart';
import 'package:rental_room_management/models/room.dart';

void main() {
  testWidgets('targeted maintenance bypasses unrelated selected property',
      (tester) async {
    final loadedIds = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        selectedPropertyProvider.overrideWith((ref) => 'other-property'),
        maintenanceListProvider.overrideWith(
            (ref, query) async => throw StateError('Should not load list')),
        maintenanceDetailProvider.overrideWith((ref, id) async {
          loadedIds.add(id);
          return const MaintenanceTicket(
            id: 'm1',
            propertyId: 'p1',
            roomId: 'r1',
            title: 'Vỡ ống nước',
            status: MaintenanceStatus.open,
            priority: MaintenancePriority.urgent,
          );
        }),
      ],
      child: MaterialApp(
          theme: AppTheme.dark, home: const MaintenanceScreen(ticketId: 'm1')),
    ));
    await tester.pumpAndSettle();
    expect(loadedIds, ['m1']);
    expect(find.text('Chi tiết sửa chữa'), findsOneWidget);
    expect(find.text('Vỡ ống nước'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inspection destination opens calendar tab rather than room information',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roomDetailProvider.overrideWith((ref, id) async => const Room(
              id: 'r1',
              propertyId: 'p1',
              name: 'A101',
              status: RoomStatus.vacant,
              basePrice: 3500000,
            )),
        roomInspectionsProvider.overrideWith((ref, id) async => [
              RoomInspection(
                id: 'i1',
                roomId: 'r1',
                title: 'Kiểm tra điện an toàn',
                dueAt: DateTime.utc(2026, 10, 25),
              )
            ]),
      ],
      child: MaterialApp(
          theme: AppTheme.dark,
          home: const RoomDetailScreen(roomId: 'r1', initialTab: 2)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Lịch kiểm tra phòng'), findsOneWidget);
    expect(find.text('Kiểm tra điện an toàn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
