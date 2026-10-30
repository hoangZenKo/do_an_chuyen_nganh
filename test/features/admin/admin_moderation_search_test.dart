import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_moderation_screen.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import '../../fixtures/admin_accounts_capture.dart';

final _identity = StateProvider<String?>((ref) => 'admin-1');

Future<ProviderContainer> _pump(
    WidgetTester tester, List<AdminRequest> requests,
    {String initialSearch = '',
    Size size = const Size(1440, 1400),
    double scale = 1,
    Future<Map<String, dynamic>>? pendingSearch}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/admin/moderation', routes: [
    GoRoute(
        path: '/admin/moderation',
        builder: (_, __) =>
            AdminModerationScreen(initialFilters: {'search': initialSearch})),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
        adminCapabilitiesProvider
            .overrideWith((ref) async => const AdminCapabilities([
                  'admin.dashboard.view',
                  'admin.listings.moderate',
                  'admin.reviews.moderate',
                ])),
        adminResourceProvider.overrideWith((ref, request) async {
          requests.add(request);
          if (request.path.startsWith('/admin/moderation/items/')) {
            return {
              'data': {
                'id': 'listing-1',
                'title': 'Phòng A101',
                'status': 'PENDING'
              }
            };
          }
          if (request.query['search'] == 'slow' && pendingSearch != null) {
            return pendingSearch;
          }
          return {
            'data': request.query['search'] == 'missing'
                ? []
                : [
                    {
                      'id': 'listing-1',
                      'kind': 'LISTING',
                      'title': 'Phòng A101 — Khu trọ An',
                      'version': 1,
                      'workVersion': 0,
                      'priority': 'NORMAL',
                      'dueAt': '2026-10-31T09:00:00.000Z',
                      'assigneeId': null
                    }
                  ],
            'meta': {
              'page': request.query['page'] ?? 1,
              'limit': 20,
              'total': request.query['search'] == 'missing' ? 0 : 40,
            }
          };
        }),
      ],
      child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                  key: adminAccountsCaptureKey, child: child!)))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
      tester.element(find.byKey(adminAccountsCaptureKey)));
}

AdminRequest _lastQueue(List<AdminRequest> requests) =>
    requests.lastWhere((request) => request.path == '/admin/moderation/queue');

void main() {
  setUpAll(loadAdminAccountsCaptureFonts);

  testWidgets('moderation search debounces, retains filters and resets page',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, requests);
    await tester.tap(find.text('Quá hạn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(_lastQueue(requests).query['page'], 2);

    await tester.enterText(
        find.byKey(const ValueKey('moderation-search')), '  Khu trọ An  ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_lastQueue(requests).query['search'], '');
    await tester.pumpAndSettle(const Duration(milliseconds: 60));
    expect(_lastQueue(requests).query, containsPair('search', 'Khu trọ An'));
    expect(_lastQueue(requests).query, containsPair('page', 1));
    expect(_lastQueue(requests).query, containsPair('overdue', 'true'));
    expect(find.byTooltip('Xóa tìm kiếm'), findsOneWidget);
    await captureAdminAccounts(tester, 'moderation-search-desktop');
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear cancels pending debounce and keeps the active filter',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, requests, initialSearch: 'listing-1');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('moderation-search')))
            .controller!
            .text,
        'listing-1');
    await tester.tap(find.text('Quá hạn'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('moderation-search')), 'late keyword');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    expect(_lastQueue(requests).query, containsPair('search', ''));
    expect(_lastQueue(requests).query, containsPair('page', 1));
    expect(_lastQueue(requests).query, containsPair('overdue', 'true'));
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('moderation-search')))
            .controller!
            .text,
        '');
    expect(
        requests.where((request) => request.query['search'] == 'late keyword'),
        isEmpty);
    expect(find.byTooltip('Xóa tìm kiếm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search empty state explains the pending queue scope',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, requests);
    await tester.enterText(
        find.byKey(const ValueKey('moderation-search')), 'missing');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
        find.text(
            'Không tìm thấy nội dung chờ duyệt phù hợp. Thử từ khóa khác hoặc thay đổi bộ lọc.'),
        findsOneWidget);
    expect(find.text('Tìm trong hàng đợi chờ xử lý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear ignores results from an older in-flight search',
      (tester) async {
    final requests = <AdminRequest>[];
    final pending = Completer<Map<String, dynamic>>();
    await _pump(tester, requests, pendingSearch: pending.future);
    await tester.enterText(
        find.byKey(const ValueKey('moderation-search')), 'slow');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_lastQueue(requests).query['search'], 'slow');
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    pending.complete({
      'data': [],
      'meta': {'page': 1, 'limit': 20, 'total': 999}
    });
    await tester.pumpAndSettle();
    expect(_lastQueue(requests).query['search'], '');
    expect(find.text('40 kết quả · Trang 1'), findsOneWidget);
    expect(find.textContaining('999 kết quả'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session changes cancel a pending debounced search',
      (tester) async {
    final requests = <AdminRequest>[];
    final container = await _pump(tester, requests);
    await tester.enterText(
        find.byKey(const ValueKey('moderation-search')), 'late keyword');
    container.read(_identity.notifier).state = null;
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
        requests.where((request) => request.query['search'] == 'late keyword'),
        isEmpty);
    expect(find.text('Phiên đã thay đổi. Vui lòng mở lại trang quản trị.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    (width: 320.0, scale: 1.0),
    (width: 320.0, scale: 1.5),
    (width: 390.0, scale: 1.0),
    (width: 390.0, scale: 1.5),
  ]) {
    testWidgets('moderation search fits mobile at $viewport', (tester) async {
      final requests = <AdminRequest>[];
      await _pump(tester, requests,
          initialSearch: 'A101',
          size: Size(viewport.width, 844),
          scale: viewport.scale);
      await tester
          .ensureVisible(find.byKey(const ValueKey('moderation-search')));
      await tester.pumpAndSettle();
      final bounds =
          tester.getRect(find.byKey(const ValueKey('moderation-search')));
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(viewport.width));
      expect(find.byTooltip('Xóa tìm kiếm'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureAdminAccounts(tester,
          'moderation-search-mobile-${viewport.width}-${viewport.scale}');
    });
  }
}
