import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_overview_chart.dart';
import 'package:rental_room_management/features/admin/admin_overview_theme.dart';
import 'package:rental_room_management/models/admin_dashboard.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<AdminDailyTrend> rows) =>
      tester.pumpWidget(MaterialApp(
          theme: AdminOverviewTheme.light,
          home: Scaffold(
              body: SizedBox(
                  width: 320,
                  child:
                      AdminOverviewChart(data: rows, metric: 'rentalNet')))));

  AdminDailyTrend row(int day, int value) => AdminDailyTrend(
      day: DateTime(2026, 10, day),
      accounts: 0,
      properties: 0,
      rooms: 0,
      listings: 0,
      rentalNet: value);

  testWidgets('empty chart describes missing data', (tester) async {
    await pump(tester, []);
    expect(find.text('Chưa có dữ liệu theo ngày.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero series reports no activity rather than fake growth',
      (tester) async {
    await pump(tester, [row(26, 0), row(27, 0)]);
    expect(find.text('Không phát sinh trong kỳ này.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negative series supports touch and accessible day controls',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, [row(26, -1000000), row(27, 2000000)]);
    expect(find.text('27/10/2026: 2000000 đ tiền thuê ròng'), findsOneWidget);
    await tester.tap(find.byTooltip('Ngày trước'));
    await tester.pump();
    expect(find.text('26/10/2026: -1000000 đ tiền thuê ròng'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Biểu đồ theo ngày. 26/10')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-chart-plot')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a single negative point does not divide by zero',
      (tester) async {
    await pump(tester, [row(27, -500000)]);
    expect(find.text('27/10/2026: -500000 đ tiền thuê ròng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('malformed overview envelope fails instead of showing false zero totals',
      () {
    expect(
        () => AdminDashboardData.fromJson({'data': []}), throwsFormatException);
  });
}
