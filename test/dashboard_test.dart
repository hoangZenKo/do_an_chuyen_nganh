import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/features/dashboard/dashboard_providers.dart';
import 'package:rental_room_management/features/dashboard/dashboard_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/dashboard.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/reports.dart';
import 'package:rental_room_management/models/room.dart';

ProviderScope _harness({
  required DashboardMetrics metrics,
  double bottomInset = 0,
  AuthSession? session,
  List<Invoice> invoices = const [],
  List<BillingReminder> reminders = const [],
  List<Room>? roomData,
  List<Property> properties = const [
    Property(
      id: 'p1',
      name: 'Nhà trọ API',
      address: '123 Đường API',
      roomCount: 3,
      occupiedCount: 2,
    ),
  ],
}) {
  final activeSession = session ??
      const AuthSession(
        user: LandlordUser(
          id: 'landlord-test',
          fullName: 'Chủ trọ',
          email: 'landlord@example.com',
          role: 'landlord',
          permissions: [
            'property.view',
            'room.view',
            'tenant.view',
            'billing.view',
          ],
        ),
        accessToken: 'access',
        refreshToken: 'refresh',
      );
  return ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(
        () => _AuthenticatedSession(activeSession),
      ),
      selectedPropertyProvider.overrideWith((ref) => 'p1'),
      propertiesProvider.overrideWith((ref) async => properties),
      dashboardMetricsProvider.overrideWith((ref) async => metrics),
      invoicesProvider.overrideWith((ref) async => invoices),
      billingRemindersProvider.overrideWith((ref) async => reminders),
      roomsProvider.overrideWith((ref, propertyId) async =>
          roomData ??
          [
            const Room(
              id: 'r101',
              propertyId: 'p1',
              name: 'A01',
              status: RoomStatus.occupied,
              basePrice: 3000000,
              tenantName: 'Nguyễn Văn C',
            ),
            const Room(
              id: 'r102',
              propertyId: 'p1',
              name: 'B12',
              status: RoomStatus.vacant,
              basePrice: 2500000,
            ),
          ]),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: child!,
      ),
      home: const DashboardScreen(),
    ),
  );
}

class _AuthenticatedSession extends SessionController {
  _AuthenticatedSession(this.authSession);

  final AuthSession authSession;

  @override
  SessionState build() => SessionState.authenticated(authSession);
}

void main() {
  for (final bottomInset in [0.0, 34.0]) {
    testWidgets(
        'dashboard scrolls behind the taskbar and reveals its end with inset $bottomInset',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester
          .pumpWidget(_harness(metrics: _metrics(), bottomInset: bottomInset));
      await tester.pumpAndSettle();
      final scrollView = find.byType(CustomScrollView);
      final taskbar = find.byType(LiquidBubbleNavigation);
      final taskbarBefore = tester.getRect(taskbar);

      expect(tester.getRect(scrollView).bottom, 932);
      expect(
          tester.getRect(scrollView).bottom, greaterThan(taskbarBefore.bottom));

      await tester.drag(scrollView, const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(tester.getRect(taskbar), taskbarBefore);
      final statisticsHeading =
          find.text('Thống kê khu trọ', skipOffstage: false);
      expect(statisticsHeading, findsOneWidget);
      expect(tester.getRect(statisticsHeading).bottom,
          lessThan(taskbarBefore.top));
      final clearance = tester
          .getRect(find.byKey(const ValueKey('dashboard-bottom-clearance')));
      expect(clearance.top, lessThan(taskbarBefore.top));
      expect(clearance.height,
          greaterThanOrEqualTo(taskbarBefore.height + 16 + bottomInset));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard overview renders API-backed metrics', (tester) async {
    await tester.pumpWidget(_harness(metrics: _metrics()));
    await tester.pumpAndSettle();

    expect(find.text('Nhà trọ API'), findsWidgets);
    expect(find.text('32', skipOffstage: false), findsOneWidget);
    expect(find.text('26', skipOffstage: false), findsOneWidget);
    expect(find.text('6', skipOffstage: false), findsOneWidget);
    expect(find.text('12.500.000 đ', skipOffstage: false), findsOneWidget);
    expect(find.text('56.250.000 đ', skipOffstage: false), findsOneWidget);
    expect(find.text('Nhà trọ An Bình'), findsNothing);
    expect(find.text('68.750k'), findsNothing);

    final taskbar = tester.getRect(find.byType(LiquidBubbleNavigation));
    final bubble = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('liquid-navigation-bubble')));
    expect((bubble.decoration as BoxDecoration).color, Colors.white);
    expect(
        tester
            .widget<LiquidBubbleNavigation>(find.byType(LiquidBubbleNavigation))
            .activeColor,
        const Color(0xFFFF6B1A));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(LiquidBubbleNavigation)), taskbar);
    expect(find.text('Đã thu'), findsWidgets);
  });

  testWidgets('dashboard overview shows empty attention and invoices',
      (tester) async {
    await tester.pumpWidget(_harness(metrics: _metrics(emptyLists: true)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Không có phòng hoặc hóa đơn cần chú ý.'), findsOneWidget);
    expect(find.text('Chưa có hóa đơn nào.'), findsOneWidget);
  });

  testWidgets('compact room pill matrix switches inline dock when room tapped',
      (tester) async {
    await tester.pumpWidget(_harness(metrics: _metrics()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sơ đồ 3D'));
    await tester.pumpAndSettle();
    expect(find.text('Sơ đồ phòng', skipOffstage: false), findsWidgets);
    expect(find.byKey(const ValueKey('floor-3d-viewport')), findsOneWidget);
  });

  testWidgets('rooms and billing tabs reveal their final content above taskbar',
      (tester) async {
    tester.view.physicalSize = const Size(600, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const session = AuthSession(
      user: LandlordUser(
        id: 'landlord-1',
        fullName: 'Chủ trọ',
        email: 'landlord@example.com',
        role: 'staff',
        permissions: ['room.view', 'billing.view', 'billing.record_payment'],
      ),
      accessToken: 'access',
      refreshToken: 'refresh',
    );
    final rooms = [
      for (var index = 1; index <= 20; index++)
        Room(
          id: 'room-$index',
          propertyId: 'p1',
          name: 'R$index',
          status: index.isEven ? RoomStatus.vacant : RoomStatus.occupied,
          basePrice: 2500000,
        ),
    ];
    final invoices = [
      for (var index = 1; index <= 12; index++)
        Invoice(
          id: 'invoice-$index',
          leaseId: 'lease-$index',
          roomId: 'room-$index',
          tenantId: 'tenant-$index',
          billingMonth: DateTime(2026, 8),
          rentAmount: 2500000,
          electricityAmount: 100000,
          waterAmount: 50000,
          otherAmount: 0,
          totalAmount: 2650000,
          paidAmount: 0,
          remainingAmount: 2650000,
          status: InvoiceStatus.unpaid,
          roomName: 'R$index',
          tenantName: 'Khách $index',
          dueDate: DateTime(2026, 8, 15),
        ),
    ];

    await tester.pumpWidget(_harness(
      metrics: _metrics(),
      session: session,
      invoices: invoices,
      roomData: rooms,
      properties: const [
        Property(
          id: 'p1',
          name: 'Nhà trọ API',
          address: '123 Đường API',
          roomCount: 20,
          occupiedCount: 10,
        ),
      ],
    ));
    await tester.pumpAndSettle();

    final taskbar = find.byType(LiquidBubbleNavigation);
    final taskbarRect = tester.getRect(taskbar);

    await tester.tap(find.text('Phòng').last);
    await tester.pumpAndSettle();
    final roomsList = find.byType(ListView).last;
    await tester.drag(roomsList, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final lastRoom = tester.getRect(find.text('R20'));
    expect(lastRoom.bottom, lessThanOrEqualTo(taskbarRect.top - 16));
    expect(tester.getRect(roomsList).bottom, 932);

    await tester.tap(find.text('Hóa đơn').last);
    await tester.pumpAndSettle();
    final invoicesList = find.byType(CustomScrollView).last;
    await tester.drag(invoicesList, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final lastPaymentAction = tester.getRect(
      find
          .ancestor(
            of: find.text('Ghi nhận thanh toán').last,
            matching:
                find.byWidgetPredicate((widget) => widget is ElevatedButton),
          )
          .first,
    );
    expect(lastPaymentAction.bottom, lessThanOrEqualTo(taskbarRect.top - 16));
    expect(find.text('Phòng R12'), findsOneWidget);
    expect(tester.getRect(invoicesList).bottom, 932);
    expect(tester.getRect(taskbar), taskbarRect);
    expect(tester.takeException(), isNull);
  });
}

DashboardMetrics _metrics({bool emptyLists = false}) {
  return DashboardMetrics(
    propertyId: 'p1',
    generatedAt: DateTime.utc(2026, 8, 6, 10),
    roomStats: const DashboardRoomStats(
      total: 32,
      occupied: 26,
      vacant: 6,
      maintenance: 1,
      occupancyRate: 81,
    ),
    leaseStats: const DashboardLeaseStats(active: 26),
    currentMonth: const DashboardCurrentMonth(
      invoiceCount: 26,
      billedAmount: 68750000,
      receivedAmount: 56250000,
      outstandingInvoiceCount: 5,
      outstandingAmount: 12500000,
    ),
    revenueTrend: [
      RevenuePoint(month: DateTime.utc(2026, 7), amount: 0),
      RevenuePoint(month: DateTime.utc(2026, 8), amount: 56250000),
    ],
    attentionItems: emptyLists
        ? const []
        : [
            DashboardAttentionItem(
              kind: DashboardAttentionKind.overdueInvoice,
              roomId: 'r201',
              roomName: '201',
              tenantName: 'Nguyễn Văn A',
              invoiceId: 'i1',
              remainingAmount: 3500000,
              dueDate: DateTime.utc(2026, 8),
            ),
            DashboardAttentionItem(
              kind: DashboardAttentionKind.maintenanceRoom,
              roomId: 'r302',
              roomName: '302',
              propertyId: 'p1',
              propertyName: 'Nhà trọ API',
              updatedAt: DateTime.utc(2026, 8, 4),
            ),
          ],
    recentInvoices: emptyLists
        ? const []
        : [
            DashboardRecentInvoice(
              id: 'i2',
              roomId: 'r101',
              roomName: '101',
              tenantId: 't2',
              tenantName: 'Nguyễn Văn B',
              billingMonth: DateTime.utc(2026, 8),
              totalAmount: 3500000,
              paidAmount: 3500000,
              remainingAmount: 0,
              status: InvoiceStatus.paid,
              dueDate: DateTime.utc(2026, 8, 10),
              issuedAt: DateTime.utc(2026, 8, 5),
            ),
          ],
  );
}
