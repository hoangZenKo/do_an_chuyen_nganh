import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/features/dashboard/dashboard_providers.dart';
import 'package:rental_room_management/features/dashboard/dashboard_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/dashboard.dart';
import 'package:rental_room_management/models/property.dart';

ProviderScope _harness({
  required DashboardMetrics metrics,
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
  return ProviderScope(
    overrides: [
      selectedPropertyProvider.overrideWith((ref) => 'p1'),
      propertiesProvider.overrideWith((ref) async => properties),
      dashboardMetricsProvider.overrideWith((ref) async => metrics),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  );
}

void main() {
  testWidgets('dashboard overview renders API-backed metrics', (tester) async {
    await tester.pumpWidget(_harness(metrics: _metrics()));
    await tester.pumpAndSettle();

    expect(find.text('Nhà trọ API'), findsWidgets);
    expect(find.text('32'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('12.500.000 đ'), findsOneWidget);
    expect(find.text('56.250.000 đ'), findsOneWidget);
    expect(find.text('Nhà trọ An Bình'), findsNothing);
    expect(find.text('68.750k'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Đã thu'), findsOneWidget);
  });

  testWidgets('dashboard overview shows empty attention and invoices',
      (tester) async {
    await tester.pumpWidget(_harness(metrics: _metrics(emptyLists: true)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Không có phòng hoặc hóa đơn cần chú ý.'), findsOneWidget);
    expect(find.text('Chưa có hóa đơn nào.'), findsOneWidget);
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
