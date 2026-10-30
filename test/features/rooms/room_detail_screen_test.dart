import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';

import 'package:rental_room_management/features/rooms/room_detail_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_providers.dart';
import 'package:rental_room_management/models/lease.dart';
import 'package:rental_room_management/models/room.dart';

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

  testWidgets('room detail renders vacant room with no leases', (tester) async {
    const room = Room(
      id: 'r-vacant',
      propertyId: 'p1',
      name: 'A01',
      status: RoomStatus.vacant,
      basePrice: 2500000,
    );

    await tester.pumpWidget(_roomDetailApp(room));

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chưa có hợp đồng'), findsOneWidget);
    expect(find.text('Phòng trống'), findsWidgets);
  });

  for (final width in [320.0, 375.0, 430.0, 800.0]) {
    testWidgets('room detail tabs fit at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const room = Room(
        id: 'r-vacant',
        propertyId: 'p1',
        name: 'A01',
        status: RoomStatus.vacant,
        basePrice: 2500000,
      );
      await tester.pumpWidget(_roomDetailApp(room));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Chi tiết phòng'));
      await tester.pumpAndSettle();

      for (final label in ['Info', 'Ảnh', 'Lịch', 'Hợp đồng']) {
        final bounds = tester.getRect(find.text(label));
        expect(bounds.left, greaterThanOrEqualTo(20));
        expect(bounds.right, lessThanOrEqualTo(width - 20));
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Tab: $label');
        if (label == 'Ảnh') {
          expect(find.text('ẢNH CHI TIẾT'), findsOneWidget);
        } else if (label == 'Lịch') {
          expect(find.text('Chưa có lịch kiểm tra.'), findsOneWidget);
        } else if (label == 'Hợp đồng') {
          expect(find.text('Chưa có hợp đồng'), findsWidgets);
        }
      }
    });
  }
  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('occupied contract stays readable at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const room = Room(
          id: 'r-occupied',
          propertyId: 'p1',
          name: 'A101',
          status: RoomStatus.occupied,
          basePrice: 3000000);
      final lease = Lease(
          id: 'lease-1',
          roomId: room.id,
          tenantId: 'tenant-1',
          tenantName: 'Nguyễn Hoàng Phạm Văn Minh',
          status: LeaseStatus.active,
          monthlyRent: 3000000,
          deposit: 2000000,
          startDate: DateTime(2026, 10, 30));
      await tester
          .pumpWidget(_roomDetailApp(room, leases: [lease], initialTab: 3));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('NGƯỜI THUÊ HIỆN TẠI'));
      await tester.pumpAndSettle();

      for (final label in [
        'NGƯỜI THUÊ HIỆN TẠI',
        'Nguyễn Hoàng Phạm Văn Minh',
        'Giá thuê',
        'Tiền cọc',
        'Ngày bắt đầu',
        '2.000.000 đ',
        '30/10/2026',
      ]) {
        final finder = find.descendant(
          of: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_ContractTab'),
          matching: find.text(label),
        );
        final text = tester.widget<Text>(finder);
        final color = text.style?.color ??
            DefaultTextStyle.of(tester.element(finder)).style.color!;
        final luminances = [
          color.computeLuminance(),
          Colors.white.computeLuminance(),
        ]..sort();
        expect((luminances.last + 0.05) / (luminances.first + 0.05),
            greaterThanOrEqualTo(4.5),
            reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _roomDetailApp(Room room,
        {List<Lease> leases = const [], int initialTab = 0}) =>
    ProviderScope(
      overrides: [
        roomDetailProvider.overrideWith((ref, roomId) async => room),
        roomLeasesProvider.overrideWith(
          (ref, roomId) async => leases,
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
      child: MaterialApp(
        theme: AppTheme.dark,
        home: RoomDetailScreen(roomId: room.id, initialTab: initialTab),
      ),
    );
