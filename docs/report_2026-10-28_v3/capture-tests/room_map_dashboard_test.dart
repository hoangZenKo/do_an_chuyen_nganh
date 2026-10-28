import 'capture_helper.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/dashboard/dashboard_providers.dart';
import 'package:rental_room_management/features/dashboard/room_map_dashboard.dart';
import 'package:rental_room_management/features/dashboard/widgets/room_floor_scene.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/dashboard.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';

import 'file:///Users/hoang/Rental_room_management/test/features/chatbot/chatbot_test_support.dart';

final _rooms = [
  for (var index = 1; index <= 7; index++)
    Room(
        id: 'r$index',
        propertyId: 'p1',
        name: 'P20$index',
        floor: 2,
        status: index == 2
            ? RoomStatus.maintenance
            : index == 7
                ? RoomStatus.vacant
                : RoomStatus.occupied,
        basePrice: index == 3 ? 3500000 : 3200000,
        tenantName: index == 4 ? 'Lý Thảo' : null),
  const Room(
      id: 'r101',
      propertyId: 'p1',
      name: 'P101',
      floor: 1,
      status: RoomStatus.vacant),
  const Room(
      id: 'unknown',
      propertyId: 'p1',
      name: 'Chưa gán',
      status: RoomStatus.vacant),
];

DashboardMetrics _metrics({bool overdue = true, String propertyId = 'p1'}) =>
    DashboardMetrics(
      propertyId: propertyId,
      generatedAt: DateTime.now(),
      roomStats: const DashboardRoomStats(
          total: 9, occupied: 5, vacant: 3, maintenance: 1, occupancyRate: 56),
      leaseStats: const DashboardLeaseStats(active: 5),
      currentMonth: const DashboardCurrentMonth(
          invoiceCount: 5,
          billedAmount: 16000000,
          receivedAmount: 12800000,
          outstandingInvoiceCount: 1,
          outstandingAmount: 3200000),
      revenueTrend: const [],
      recentInvoices: const [],
      attentionItems: overdue
          ? [
              DashboardAttentionItem(
                  kind: DashboardAttentionKind.overdueInvoice,
                  roomId: 'r4',
                  roomName: 'P204',
                  tenantName: 'Lý Thảo',
                  invoiceId: 'invoice4',
                  propertyId: propertyId,
                  dueDate: DateTime.now().subtract(const Duration(days: 12)))
            ]
          : [],
    );

Future<void> _show(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  List<Room>? rooms,
  Future<List<Room>> Function()? loadRooms,
  DashboardMetrics? metrics,
  VoidCallback? onStatistics,
  ValueChanged<int>? onTab,
  List<Property> properties = const [
    Property(id: 'p1', name: 'Khu trọ Atrium', address: '')
  ],
  Future<DashboardMetrics> Function()? loadMetrics,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
            backgroundColor: const Color(0xFFF3F5F8),
            body: RoomMapDashboard(
                onNavigateTab: onTab ?? (_) {},
                onShowStatistics: onStatistics ?? () {}))),
    GoRoute(
        path: '/billing/:id',
        builder: (_, state) =>
            Scaffold(body: Text('invoice:${state.pathParameters['id']}'))),
    GoRoute(
        path: '/rooms/:id',
        builder: (_, state) =>
            Scaffold(body: Text('room:${state.pathParameters['id']}'))),
  ]);
  addTearDown(router.dispose);
  await reportPumpWidget(tester, ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(ChatTestSession.new),
        selectedPropertyProvider.overrideWith((ref) => 'p1'),
        propertiesProvider.overrideWith((ref) async => properties),
        roomsProvider.overrideWith((ref, propertyId) async =>
            loadRooms != null ? loadRooms() : rooms ?? _rooms),
        dashboardMetricsProvider.overrideWith((ref) async =>
            loadMetrics != null ? loadMetrics() : metrics ?? _metrics()),
      ],
      child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: RepaintBoundary(
                  key: const ValueKey('preview-boundary'), child: child!)))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async {
    await reportPumpWidget(tester, const SizedBox());
  });
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Roboto')
      ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await font.load();
    await icons.load();
  });
  test('reference artwork hotspots align with all seven room positions', () {
    for (var index = 0; index < 7; index++) {
      final outline = RoomFloorScene.roomOutlines[index];
      final center = outline.reduce((first, second) => first + second) /
          outline.length.toDouble();
      expect(RoomFloorScene.hitRoom(center, 7), index);
      if (index > 0) expect(RoomFloorScene.hitRoom(center, 1), isNull);
    }
    expect(RoomFloorScene.hitRoom(Offset.zero, 7), isNull);
  });

  testWidgets('loads real floor data and selects the overdue room',
      (tester) async {
    await _show(tester); await reportCapture(tester, 'landlord-dashboard');
    final scene = tester.widget<RoomFloorScene>(find.byType(RoomFloorScene));
    expect(scene.rooms.length, 7);
    expect(scene.selectedId, 'r4');
    expect(scene.overdueIds, contains('r4'));
    expect(find.text('P101'), findsNothing);
    expect(find.text('P204 · Lý Thảo'), findsOneWidget);
    expect(find.text('Quá hạn thanh toán 12 ngày'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floor picker filters real floors including unassigned rooms',
      (tester) async {
    await _show(tester); await reportCapture(tester, 'landlord-dashboard');
    await tester.tap(find.byTooltip('Chọn tầng'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(find.text('Tầng 4'), findsNothing);
    await tester.tap(find.text('Tầng 1'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(
        tester
            .widget<RoomFloorScene>(find.byType(RoomFloorScene))
            .rooms
            .single
            .id,
        'r101');
    await tester.tap(find.byTooltip('Chọn tầng'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    await tester.tap(find.text('Chưa gán tầng'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(
        tester
            .widget<RoomFloorScene>(find.byType(RoomFloorScene))
            .rooms
            .single
            .id,
        'unknown');
  });

  testWidgets(
      'selecting a label updates detail instead of using a hardcoded tenant',
      (tester) async {
    await _show(tester); await reportCapture(tester, 'landlord-dashboard');
    final label = find.descendant(
        of: find.byType(RoomFloorScene), matching: find.text('P202'));
    await tester.tap(label);
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(
        tester.widget<RoomFloorScene>(find.byType(RoomFloorScene)).selectedId,
        'r2');
    expect(find.text('P204 · Lý Thảo'), findsNothing);
    await tester.ensureVisible(find.text('Chi tiết'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    await tester.tap(find.text('Chi tiết'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(find.text('room:r2'), findsOneWidget);
  });

  testWidgets('overdue action opens the actual invoice', (tester) async {
    await _show(tester); await reportCapture(tester, 'landlord-dashboard');
    await tester.ensureVisible(find.text('Xử lý'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    await tester.tap(find.text('Xử lý'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(find.text('invoice:invoice4'), findsOneWidget);
  });

  testWidgets('architectural artwork and labels use the same room selection',
      (tester) async {
    await _show(tester); await reportCapture(tester, 'landlord-dashboard');
    final scene = find.byType(RoomFloorScene);
    final image = tester.widget<Image>(
        find.descendant(of: scene, matching: find.byType(Image)));
    expect((image.image as AssetImage).assetName, RoomFloorScene.imageAsset);
    final origin = tester.getTopLeft(scene);
    final scale = tester.getSize(scene).width / 821;
    await tester.tapAt(origin + const Offset(275, 510) * scale);
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(tester.widget<RoomFloorScene>(scene).selectedId, 'r1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination does not hide rooms beyond seven', (tester) async {
    await _show(tester, rooms: [
      for (var index = 0; index < 18; index++)
        Room(
            id: '$index',
            propertyId: 'p1',
            name: 'P${200 + index}',
            status: RoomStatus.occupied,
            floor: 2)
    ]);
    await tester.ensureVisible(find.byTooltip('Nhóm phòng sau'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    await tester.tap(find.byTooltip('Nhóm phòng sau'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(
        tester
            .widget<RoomFloorScene>(find.byType(RoomFloorScene))
            .rooms
            .first
            .id,
        '7');
    await tester.tap(find.byTooltip('Nhóm phòng sau'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(
        tester
            .widget<RoomFloorScene>(find.byType(RoomFloorScene))
            .rooms
            .last
            .id,
        '17');
  });

  testWidgets('unused illustration slots are disabled instead of fake rooms',
      (tester) async {
    await _show(tester,
        rooms: [_rooms.first], metrics: _metrics(overdue: false));
    final scene = find.byType(RoomFloorScene);
    expect(find.descendant(of: scene, matching: find.text('Chưa gán')),
        findsNWidgets(6));
    expect(
        find.descendant(of: scene, matching: find.text('P204')), findsNothing);
    await tester
        .tap(find.descendant(of: scene, matching: find.text('Chưa gán')).first);
    await tester.pump();
    expect(tester.widget<RoomFloorScene>(scene).selectedId, 'r1');
  });

  testWidgets(
      'poll updates room data and clears paid overdue markers without losing selection',
      (tester) async {
    var paid = false;
    var requests = 0;
    await _show(tester,
        loadRooms: () async {
          requests++;
          return [
            for (final room in _rooms)
              if (room.id == 'r2' && paid)
                const Room(
                    id: 'r2',
                    propertyId: 'p1',
                    name: 'P202',
                    floor: 2,
                    status: RoomStatus.occupied,
                    basePrice: 4200000)
              else
                room
          ];
        },
        loadMetrics: () async => _metrics(overdue: !paid));
    await tester.tap(find.descendant(
        of: find.byType(RoomFloorScene), matching: find.text('P202')));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    paid = true;
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    final scene = tester.widget<RoomFloorScene>(find.byType(RoomFloorScene));
    expect(requests, 2);
    expect(scene.selectedId, 'r2');
    expect(scene.rooms[1].basePrice, 4200000);
    expect(scene.overdueIds, isEmpty);
    expect(find.text('4.200.000 đ/tháng'), findsOneWidget);
  });

  testWidgets('polling pauses in background and resumes with a fresh request',
      (tester) async {
    var requests = 0;
    await _show(tester, loadRooms: () async {
      requests++;
      return _rooms;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(requests, 2);
    await reportPumpWidget(tester, const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(requests, 2);
  });

  testWidgets(
      'slow refresh retains scene and does not create overlapping requests',
      (tester) async {
    var requests = 0;
    final pending = Completer<List<Room>>();
    await _show(tester, loadRooms: () {
      requests++;
      return requests == 1 ? Future.value(_rooms) : pending.future;
    });
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.byType(RoomFloorScene), findsOneWidget);
    await tester.pump(const Duration(seconds: 15));
    expect(requests, 2);
    pending.complete(_rooms);
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
  });

  testWidgets('empty properties and empty rooms never show demo data',
      (tester) async {
    await _show(tester, properties: []);
    expect(find.byType(RoomFloorScene), findsNothing);
    expect(find.textContaining('Chưa có khu trọ.'), findsOneWidget);
    await reportPumpWidget(tester, const SizedBox());
    await _show(tester, rooms: []);
    expect(find.byType(RoomFloorScene), findsNothing);
    expect(find.textContaining('Chưa có phòng.'), findsOneWidget);
    expect(find.text('Lý Thảo'), findsNothing);
  });

  testWidgets('room load errors support retry and loading has no fake rooms',
      (tester) async {
    var attempts = 0;
    await _show(tester, loadRooms: () async {
      if (attempts++ == 0) throw StateError('offline');
      return _rooms;
    });
    expect(find.text('Không thể tải danh sách phòng.'), findsOneWidget);
    expect(find.byType(RoomFloorScene), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
    expect(find.byType(RoomFloorScene), findsOneWidget);
    await reportPumpWidget(tester, const SizedBox());
    final pending = Completer<List<Room>>();
    await _show(tester, loadRooms: () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(RoomFloorScene), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
  });

  testWidgets('notes and another property cannot create overdue markers',
      (tester) async {
    await _show(tester,
        rooms: [
          const Room(
              id: 'r4',
              propertyId: 'p1',
              name: 'P204',
              floor: 2,
              note: 'Không quá hạn',
              status: RoomStatus.occupied,
              basePrice: 0)
        ],
        metrics: _metrics(propertyId: 'other'));
    expect(
        tester.widget<RoomFloorScene>(find.byType(RoomFloorScene)).overdueIds,
        isEmpty);
    expect(find.text('0 đ/tháng'), findsOneWidget);
    expect(find.text('Quá hạn thanh toán 12 ngày'), findsNothing);
  });

  testWidgets('statistics and list controls invoke their real destinations',
      (tester) async {
    var statistics = false;
    int? tab;
    await _show(tester,
        onStatistics: () => statistics = true, onTab: (value) => tab = value);
    await tester.tap(find.text('Thống kê'));
    expect(statistics, isTrue);
    await tester.tap(find.text('Danh sách'));
    expect(tab, 1);
  });

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1100, 900)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('layout ${size.width} with text scale $scale',
          (tester) async {
        await _show(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('RENDER_DASHBOARD') && scale == 1) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview-boundary')));
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await File('/tmp/room-dashboard-${size.width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final scrollable = tester.state<ScrollableState>(find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle(); await reportCapture(tester, 'room_map_dashboard_test');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
