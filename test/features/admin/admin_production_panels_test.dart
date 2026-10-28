import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_workspace_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

const _permissions = [
  'admin.dashboard.view',
  'admin.audit.view',
  'admin.audit.export',
  'admin.operations.view',
  'admin.operations.manage'
];
const _data = {
  'data': {
    'generatedAt': '2026-10-25T09:00:00Z',
    'database': 'ok',
    'metrics': {
      'requests': 100,
      'errors': 2,
      'errorRate': 0.02,
      'averageDurationMs': 40,
      'loginFailures': 2,
      'mfaFailures': 1
    },
    'workers': [
      {'name': 'billing', 'status': 'OK', 'lastRunAt': '2026-10-25T09:00:00Z'}
    ],
    'incidents': [
      {
        'id': 'incident-1',
        'title': 'Hàng đợi kiểm duyệt quá hạn xử lý cần được tiếp nhận',
        'status': 'OPEN',
        'severity': 'WARNING',
        'occurrences': 2,
        'lastSeenAt': '2026-10-25T09:00:00Z',
        'version': 1
      }
    ],
    'deliveries': [
      {'status': 'PENDING', 'total': 2}
    ],
    'migrations': [],
    'moderationOverdue': 3,
    'accountDeliveryConfigured': false,
    'alertDeliveryConfigured': false,
  }
};

class _AuditExportApi extends AdminApi {
  _AuditExportApi() : super(Dio());

  String? reason;
  Map<String, dynamic>? filters;

  @override
  Future<String> exportAudit(Map<String, dynamic> filters,
      {required String reason}) async {
    this.filters = filters;
    this.reason = reason;
    return 'id,summary\r\naudit-1,Account updated';
  }
}

Future<GoRouter> _pump(WidgetTester tester,
    {required Size size,
    String section = 'operations',
    Map<String, String> initialFilters = const {},
    List<String> permissions = _permissions,
    AdminApi? api,
    List<AdminRequest>? requests}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final route = section == 'audit' ? '/admin/audit-logs' : '/admin/operations';
  final router = GoRouter(initialLocation: route, routes: [
    GoRoute(
        path: route,
        builder: (_, __) => AdminWorkspaceScreen(
            section: section, initialFilters: initialFilters))
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        if (api != null) adminApiProvider.overrideWithValue(api),
        sessionIdentityProvider.overrideWithValue('admin-1'),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(permissions)),
        adminWorkspaceResourceProvider.overrideWith((ref, request) async {
          requests?.add(request);
          if (request.path == '/admin/operations/incidents') {
            return {
              'data': (_data['data'] as Map)['incidents'] ?? [],
              'meta': {'total': 0, 'pages': 0},
            };
          }
          return request.path.contains('audit-logs')
              ? {
                  'data': [],
                  'meta': {'total': 0}
                }
              : _data;
        }),
      ],
      child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width < 500 ? 1.3 : 1)),
              child: RepaintBoundary(
                  key: const ValueKey('qa-boundary'), child: child!)))));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  final directory = Platform.environment['ADMIN_QA_OUTPUT'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('qa-boundary')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('audit deep links apply only supported resource filters',
      (tester) async {
    final requests = <AdminRequest>[];
    const resourceId = '11111111-1111-4111-8111-111111111111';
    await _pump(tester,
        size: const Size(1200, 1000),
        section: 'audit',
        initialFilters: const {
          'resourceId': resourceId,
          'unsupported': 'ignored'
        },
        requests: requests);
    final request =
        requests.lastWhere((request) => request.path == '/admin/audit-logs');
    expect(request.query['resourceId'], resourceId);
    expect(request.query, isNot(contains('unsupported')));
    expect(find.text(resourceId), findsOneWidget);
  });

  testWidgets('audit CSV requires a reason and copies the exported data',
      (tester) async {
    final api = _AuditExportApi();
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pump(tester,
        size: const Size(1200, 1000), section: 'audit', api: api);
    await tester.ensureVisible(find.text('Sao chép CSV'));
    await tester.tap(find.text('Sao chép CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.reason, isNull);
    expect(copied, isNull);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lý do (tối thiểu 10 ký tự)'),
        'Kiểm tra thao tác quản trị');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.reason, 'Kiểm tra thao tác quản trị');
    expect(api.filters?.keys, containsAll(['from', 'to']));
    expect(copied, 'id,summary\r\naudit-1,Account updated');
    expect(find.text('Đã sao chép audit CSV vào clipboard.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operations fits a phone with enlarged text and desktop sidebar',
      (tester) async {
    await _pump(tester, size: const Size(390, 844));
    expect(find.text('Tỷ lệ lỗi máy chủ'), findsOneWidget);
    expect(find.text('2.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'admin-operations-mobile');
  });
  testWidgets('desktop operations exposes the capability-filtered navigation',
      (tester) async {
    await _pump(tester, size: const Size(1440, 1000));
    expect(find.text('Vận hành hệ thống'), findsWidgets);
    expect(find.text('Nhật ký'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'admin-operations-desktop');
  });
  testWidgets('restricted admin does not fetch operations data',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester,
        size: const Size(390, 844),
        permissions: const ['admin.dashboard.view'],
        requests: requests);
    expect(find.text('Bạn không có quyền mở chức năng này.'), findsOneWidget);
    expect(requests, isEmpty);
  });
  testWidgets(
      'audit filters validate identifiers and keep date bounds in the request',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester,
        size: const Size(1200, 1000), section: 'audit', requests: requests);
    expect(
        requests.last.query.keys, containsAll(['from', 'to', 'page', 'limit']));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'ID người thực hiện'), 'not-a-uuid');
    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập UUID hợp lệ.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _screenshot(tester, 'admin-audit-desktop');
  });
}
