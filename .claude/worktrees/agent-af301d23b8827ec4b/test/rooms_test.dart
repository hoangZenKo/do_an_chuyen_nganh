import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_room_management/core/utils/format.dart';
import 'package:rental_room_management/data/rooms/property_api.dart';
import 'package:rental_room_management/data/rooms/room_api.dart';
import 'package:rental_room_management/data/rooms/room_repository.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/rooms/rooms_list_screen.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';

class _MockPropertyApi extends Mock implements PropertyApi {}

class _MockRoomApi extends Mock implements RoomApi {}

ProviderScope _harness({
  required RoomRepository repository,
  Widget child = const RoomsListScreen(),
}) {
  return ProviderScope(
    overrides: [roomRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('Room.fromJson', () {
    test('parses a bare object', () {
      final room = Room.fromJson({
        'id': 'r1',
        'propertyId': 'p1',
        'name': 'P.201',
        'floor': 2,
        'areaSqm': 25.5,
        'basePrice': 3500000,
        'status': 'occupied',
        'tenantName': 'Nguyễn Văn A',
        'isActive': false,
      });

      expect(room.id, 'r1');
      expect(room.name, 'P.201');
      expect(room.floor, 2);
      expect(room.areaSqm, 25.5);
      expect(room.basePrice, 3500000);
      expect(room.status, RoomStatus.occupied);
      expect(room.isActive, isFalse);
      expect(room.tenantName, 'Nguyễn Văn A');
    });

    test('parses a data envelope and maps unknown status to vacant', () {
      final room = Room.fromJson({
        'data': {
          'id': 'r2',
          'propertyId': 'p1',
          'name': 'P.105',
          'basePrice': '3000000',
          'status': 'something-else',
        },
      });

      expect(room.id, 'r2');
      expect(room.basePrice, 3000000);
      expect(room.status, RoomStatus.vacant);
      expect(room.tenantName, isNull);
    });

    test('empty tenantName becomes null', () {
      final room = Room.fromJson({
        'id': 'r3',
        'name': 'P.302',
        'status': 'maintenance',
        'tenantName': '   ',
      });
      expect(room.tenantName, isNull);
      expect(room.status, RoomStatus.maintenance);
    });

    test('copyWith keeps lifecycle fields', () {
      const room = Room(
        id: 'r4',
        propertyId: 'p1',
        name: 'P.401',
        status: RoomStatus.vacant,
        isActive: false,
      );

      final updated = room.copyWith(name: 'P.402');

      expect(updated.name, 'P.402');
      expect(updated.isActive, isFalse);
    });
  });

  group('formatCurrencyVnd', () {
    test('inserts dot separators', () {
      expect(formatCurrencyVnd(3500000), '3.500.000 đ');
      expect(formatCurrencyVnd(0), '0 đ');
      expect(formatCurrencyVnd(999), '999 đ');
    });
  });

  group('RoomsListScreen', () {
    late _MockPropertyApi propertyApi;
    late _MockRoomApi roomApi;
    late RoomRepository repository;

    setUp(() {
      propertyApi = _MockPropertyApi();
      roomApi = _MockRoomApi();
      repository = RoomRepository(propertyApi: propertyApi, roomApi: roomApi);
    });

    testWidgets('renders rooms once loaded', (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const [
                Property(
                  id: 'p1',
                  name: 'Nhà trọ An Bình',
                  address: '123',
                  roomCount: 2,
                  occupiedCount: 1,
                ),
              ]);
      when(() =>
              roomApi.listByProperty('p1', lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const [
                Room(
                  id: 'r1',
                  propertyId: 'p1',
                  name: 'P.201',
                  status: RoomStatus.occupied,
                  basePrice: 3500000,
                ),
                Room(
                  id: 'r2',
                  propertyId: 'p1',
                  name: 'P.202',
                  status: RoomStatus.vacant,
                  basePrice: 3000000,
                ),
              ]);

      await tester.pumpWidget(_harness(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('P.201'), findsOneWidget);
      expect(find.text('P.202'), findsOneWidget);
      expect(find.text('3.500.000 đ'), findsOneWidget);
    });

    testWidgets('shows empty state when a property has no rooms',
        (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const [
                Property(id: 'p1', name: 'Khu A', address: '1'),
              ]);
      when(() =>
              roomApi.listByProperty('p1', lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const <Room>[]);

      await tester.pumpWidget(_harness(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Không có phòng'), findsOneWidget);
    });

    testWidgets('shows error state and retry when loading fails',
        (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenThrow(Exception('boom'));

      await tester.pumpWidget(_harness(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
