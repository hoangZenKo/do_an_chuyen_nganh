import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/features/rooms/room_detail_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_providers.dart';
import 'package:rental_room_management/models/lease.dart';
import 'package:rental_room_management/models/room.dart';

void main() {
  testWidgets('room detail renders vacant room with no leases', (tester) async {
    const room = Room(
      id: 'r-vacant',
      propertyId: 'p1',
      name: 'A01',
      status: RoomStatus.vacant,
      basePrice: 2500000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomDetailProvider.overrideWith((ref, roomId) async => room),
          roomLeasesProvider.overrideWith(
            (ref, roomId) async => const <Lease>[],
          ),
          roomServiceFeesProvider.overrideWith(
            (ref, roomId) async => const <RoomServiceFee>[],
          ),
          roomAssetsProvider.overrideWith(
            (ref, roomId) async => const <RoomAsset>[],
          ),
          roomInspectionsProvider.overrideWith(
            (ref, roomId) async => const <RoomInspection>[],
          ),
        ],
        child: const MaterialApp(
          home: RoomDetailScreen(roomId: 'r-vacant'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chưa có hợp đồng'), findsOneWidget);
    expect(find.text('Phòng trống'), findsWidgets);
  });
}
