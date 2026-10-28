import 'package:rental_room_management/features/admin/admin_overview_theme.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_overview_page.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_search_screen.dart';
import 'package:rental_room_management/features/admin/admin_workspace_screen.dart';
import 'package:rental_room_management/features/admin/admin_workspace_scaffold.dart';
import 'package:rental_room_management/features/admin/admin_workspace_action_queue.dart';
import 'package:rental_room_management/features/admin/admin_workspace_states.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/admin_workspace_models.dart';
import '/Users/hoang/Rental_room_management/test/fixtures/admin_overview_fixture.dart';

final _identity = StateProvider<String?>((ref) => 'admin-1');
final _permissions = StateProvider((ref) => [
      'admin.dashboard.view',
      'admin.support.read',
      'admin.notifications.view',
      'admin.operations.view',
      'admin.finance.read',
    ]);

AdminWorkspaceSummary _summary({bool partial = false, bool empty = false}) =>
    AdminWorkspaceSummary(
        items: [
          AdminWorkspaceItem(
              key: 'incidents',
              label: 'Sự cố chưa tiếp nhận',
              route: '/admin/operations',
              permission: 'admin.operations.view',
              priority: 0,
              count: partial
                  ? null
                  : empty
                      ? 0
                      : 1,
              available: !partial),
          AdminWorkspaceItem(
              key: 'support_overdue',
              label: 'Ticket quá SLA',
              route: '/admin/support-center',
              permission: 'admin.support.read',
              priority: 1,
              count: empty ? 0 : 2,
              available: true),
          AdminWorkspaceItem(
              key: 'finance',
              label: 'Giao dịch cần đối soát',
              route: '/admin/finance-reconciliation',
              permission: 'admin.finance.read',
              priority: 3,
              count: empty ? 0 : 4,
              available: true),
        ],
        updatedAt: DateTime.now(),
        partial: partial,
        pendingCount: empty
            ? 0
            : partial
                ? 6
                : 7,
        unreadCount: 3);

Map<String, dynamic> _overview() => adminOverviewFixture();

Future<({ProviderContainer container, GoRouter router})> _pump(
    WidgetTester tester,
    {Size size = const Size(390, 844),
    double textScale = 1,
    Future<AdminWorkspaceSummary> Function()? summary,
    List<AdminRequest>? requests,
    bool settle = true,
    bool dashboard = false,
    bool reports = false,
    List<String>? permissions,
    Future<Map<String, dynamic>> Function(AdminRequest request)?
        overview}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final router = GoRouter(initialLocation: '/admin', routes: [
    GoRoute(
        path: '/admin',
        builder: (_, __) => reports
            ? const AdminOverviewPage(reports: true)
            : dashboard
                ? const AdminWorkspaceScreen()
                : const AdminWorkspaceScaffold(
                    title: 'Tổng quan',
                    location: '/admin',
                    body: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: AdminWorkspaceActionQueue()))),
    GoRoute(
        path: '/admin/reports/overview',
        builder: (_, __) => const AdminOverviewPage(reports: true)),
    GoRoute(
        path: '/admin/search',
        builder: (_, state) =>
            AdminSearchScreen(initialQuery: state.uri.queryParameters['q'])),
    for (final route in [
      '/admin/support-center',
      '/admin/operations',
      '/admin/notifications'
    ])
      GoRoute(
          path: route,
          builder: (_, __) => AdminWorkspaceScaffold(
              title: 'Chi tiết', location: route, body: Text('Đã mở $route'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
        adminCapabilitiesProvider.overrideWith((ref) async =>
            AdminCapabilities(permissions ?? ref.watch(_permissions))),
        adminWorkspaceSummaryProvider.overrideWith(
            (ref) async => summary == null ? _summary() : await summary()),
        adminWorkspaceResourceProvider.overrideWith((ref, request) async {
          requests?.add(request);
          if (request.path == '/admin/search') {
            return {
              'data': [
                {
                  'kind': 'ACCOUNT',
                  'items': [
                    {
                      'id': 'user-1',
                      'fullName': 'Kết quả kiểm tra',
                      'email': 'a***@example.com'
                    }
                  ]
                }
              ]
            };
          }
          if (request.path == '/admin/analytics/summary') {
            return {
              'data': {
                'newAccounts': 3,
                'previousAccounts': 2,
                'newListings': 5,
                'previousListings': 4,
                'queue': [],
                'trends': []
              }
            };
          }
          if (request.path == '/admin/analytics/overview') {
            return overview == null ? _overview() : await overview(request);
          }
          if (request.path == '/admin/overview') {
            return {
              'data': {
                'landlords': {'total': 10},
                'properties': {'total': 20},
                'rooms': {'total': 100},
                'tenants': {'total': 90},
                'leases': {'active': 85}
              }
            };
          }
          return {'data': []};
        }),
      ],
      child: MaterialApp.router(
          theme: AdminOverviewTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: RepaintBoundary(
                  key: const ValueKey('workspace-qa'), child: child!)))));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (
    container:
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp))),
    router: router
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['ADMIN_QA_OUTPUT'];
  if (directory == null) return;
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('workspace-qa')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
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
    for (final family in ['Ahem', 'Arial', '.SF UI Text', '.SF UI Display']) {
      await (FontLoader(family)..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf').readAsBytes().then(ByteData.sublistView))).load();
    }
    await icons.load();
  });
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('real dashboard fits ${size.width} with enlarged mobile text',
        (tester) async {
      await _pump(tester,
          size: size, textScale: size.width < 500 ? 1.3 : 1, dashboard: true);
      expect(find.text('Tổng quan hệ thống'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
          tester, size.width < 500 ? 'workspace-phone' : 'workspace-desktop');
      await tester.scrollUntilVisible(find.text('Hàng đợi điều hành'), 250,
          scrollable: find
              .descendant(
                  of: find.byType(RefreshIndicator),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('Hàng đợi điều hành'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'partial data remains actionable without reporting a false empty queue',
      (tester) async {
    await _pump(tester,
        summary: () async => _summary(partial: true, empty: true));
    expect(
        find.textContaining('Không coi số chưa tải được là 0'), findsOneWidget);
    expect(find.text('Chưa tải được số liệu; mở để kiểm tra.'), findsOneWidget);
    expect(find.text('Không có việc tồn đọng cần xử lý ngay.'), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('admin-action-incidents')));
    await tester.tap(find.byKey(const ValueKey('admin-action-incidents')));
    await tester.pumpAndSettle();
    expect(find.text('Đã mở /admin/operations'), findsOneWidget);
  });

  testWidgets('full dashboard fits a 320px phone with 200 percent text',
      (tester) async {
    await _pump(tester,
        size: const Size(320, 800),
        textScale: 2,
        dashboard: true,
        permissions: [
          'admin.dashboard.view',
          'admin.accounts.view',
          'admin.properties.view',
          'admin.properties.manage',
          'admin.notifications.view',
          'admin.finance.read'
        ]);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Tình trạng phòng'), 200,
        scrollable: find
            .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Tài chính hệ thống'), 200,
        scrollable: find
            .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed source can retry and recover', (tester) async {
    var attempts = 0;
    await _pump(tester, summary: () async {
      if (++attempts == 1) {
        throw const ApiFailure(message: 'network unavailable', statusCode: 503);
      }
      return _summary();
    });
    expect(find.textContaining('Kiểm tra kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Ticket quá SLA'), findsOneWidget);
  });

  testWidgets('loading resolves to an empty state without stale results',
      (tester) async {
    final completer = Completer<AdminWorkspaceSummary>();
    await _pump(tester, summary: () => completer.future, settle: false);
    await tester.pump();
    expect(find.text('Đang tải dữ liệu…'), findsOneWidget);
    completer.complete(_summary(empty: true));
    await tester.pumpAndSettle();
    expect(find.text('Không có việc tồn đọng cần xử lý ngay.'), findsOneWidget);
    await tester.tap(find.text('Hiện cả nhóm không tồn đọng'));
    await tester.pumpAndSettle();
    expect(find.text('Ticket quá SLA'), findsOneWidget);
  });

  testWidgets(
      'revoked finance permission hides both navigation and stale queue data',
      (tester) async {
    final state = await _pump(tester, size: const Size(1440, 1000));
    expect(find.text('Giao dịch cần đối soát'), findsOneWidget);
    state.container.read(_permissions.notifier).state = [
      'admin.dashboard.view',
      'admin.support.read'
    ];
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch cần đối soát'), findsNothing);
    expect(
        find.byKey(const ValueKey('admin-nav-/admin/finance-reconciliation')),
        findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
  });

  testWidgets('session change suppresses old counts and command results',
      (tester) async {
    final state = await _pump(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    state.container.read(_identity.notifier).state = 'admin-2';
    await tester.pumpAndSettle();
    expect(find.text('Ticket quá SLA'), findsNothing);
    expect(find.text('Không có chức năng phù hợp với quyền hiện tại.'),
        findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(state.router.routeInformationProvider.value.uri.path, '/admin');
    expect(find.textContaining('Phiên đã thay đổi'), findsOneWidget);
  });

  testWidgets('dashboard switches periods and exposes chart point details',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester,
        size: const Size(390, 844), dashboard: true, requests: requests);
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    expect(
        requests.any((request) =>
            request.path == '/admin/analytics/overview' &&
            request.query['days'] == 7),
        isTrue);
    final plot = find.byKey(const ValueKey('overview-chart-plot'));
    await tester.scrollUntilVisible(plot, 200,
        scrollable: find
            .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(plot);
    await tester.pumpAndSettle();
    await tester.tap(plot);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-chart-detail')), findsOneWidget);
    expect(find.textContaining('/2026:'), findsOneWidget);
  });

  testWidgets('new overview removes finance metrics when rights are revoked',
      (tester) async {
    final state =
        await _pump(tester, dashboard: true, size: const Size(1440, 1000));
    expect(find.text('Doanh thu nền tảng'), findsOneWidget);
    state.container.read(_permissions.notifier).state = [
      'admin.dashboard.view'
    ];
    await tester.pumpAndSettle();
    expect(find.text('Doanh thu nền tảng'), findsNothing);
    expect(find.text('Tài khoản hoạt động'), findsOneWidget);
    state.container.read(_identity.notifier).state = 'another-admin';
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản hoạt động'), findsNothing);
    expect(find.textContaining('Phiên đã thay đổi'), findsOneWidget);
  });

  testWidgets('report overview is separate from scheduled reports',
      (tester) async {
    String? csv;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        csv = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester, size: const Size(390, 844), reports: true);
    expect(find.text('Báo cáo vận hành'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sao chép CSV'), 250,
        scrollable: find
            .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Sao chép CSV'), findsOneWidget);
    expect(find.text('Báo cáo định kỳ'), findsNothing);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sao chép CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sao chép CSV'));
    await tester.pumpAndSettle();
    expect(csv, contains('Tien thue rong'));
    expect(
        find.text('Đã sao chép dữ liệu CSV của kỳ đang xem.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'global search carries the encoded query and responds to query changes',
      (tester) async {
    final requests = <AdminRequest>[];
    final state = await _pump(tester, requests: requests);
    state.container.read(_permissions.notifier).state = [
      ...state.container.read(_permissions),
      'admin.accounts.view'
    ];
    await tester.pumpAndSettle();
    final search =
        find.widgetWithText(TextField, 'Tra cứu tên, mã ticket, hóa đơn…');
    await tester.enterText(search, 'Phòng A & B');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(state.router.routeInformationProvider.value.uri.queryParameters['q'],
        'Phòng A & B');
    expect(requests.last.query['search'], 'Phòng A & B');
    expect(find.text('Kết quả kiểm tra'), findsOneWidget);
    state.router.go('/admin/search?q=tenant-2');
    await tester.pumpAndSettle();
    expect(requests.last.query['search'], 'tenant-2');
  });

  testWidgets(
      'notification badge navigates to the existing notification center',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Thông báo: 3 chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mở /admin/notifications'), findsOneWidget);
  });

  testWidgets(
      'command palette supports keyboard selection and respects permissions',
      (tester) async {
    final state = await _pump(tester);
    state.container.read(_permissions.notifier).state = [
      'admin.dashboard.view',
      'admin.support.read'
    ];
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chuyển nhanh chức năng (Ctrl/Cmd K)'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Tìm chức năng'), 'Support Center');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(state.router.routeInformationProvider.value.uri.path,
        '/admin/support-center');
    expect(tester.takeException(), isNull);
  });

  for (final status in [401, 403, 409]) {
    testWidgets(
        'renders an actionable $status state without raw server details',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: Scaffold(
                  body: AdminFailureState(
                      error: ApiFailure(
                          message: 'private diagnostic',
                          statusCode: status,
                          requestId: 'request-123'),
                      retry: () {})))));
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(find.text('Mã yêu cầu: request-123'), findsOneWidget);
      expect(
          find.text(status == 401
              ? 'Đăng nhập lại'
              : status == 409
                  ? 'Tải dữ liệu mới'
                  : 'Thử lại'),
          findsOneWidget);
    });
  }
}
