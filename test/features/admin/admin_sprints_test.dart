import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_governance.dart';
import 'package:rental_room_management/features/admin/admin_moderation_v2.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_support_center.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

class _Api extends AdminApi {
  _Api() : super(Dio());
  final commands = <(String, Map<String, dynamic>, bool)>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> command(String path, Map<String, dynamic> data,
      {bool patch = false}) async {
    commands.add((path, data, patch));
    if (fail) throw Exception('409: Ticket đã thay đổi. Hãy tải lại.');
    return {
      'data': {'id': 'ticket-1'}
    };
  }
}

const _ticket = {
  'id': 'ticket-1',
  'subject': 'Hợp đồng cần kiểm tra lại',
  'status': 'IN_PROGRESS',
  'priority': 'HIGH',
  'version': 4,
  'firstResponseDueAt': '2026-10-25T10:00:00Z',
  'resolutionDueAt': '2026-10-26T10:00:00Z',
  'messages': [
    {
      'body': 'Nội dung hợp đồng cần xem xét lại.',
      'authorRole': 'TENANT',
      'author': {'fullName': 'Nguyễn An'},
      'internal': false,
      'createdAt': '2026-10-25T09:00:00Z'
    }
  ],
};
final _identity = StateProvider((ref) => 'user-1');

Map<String, dynamic> _response(AdminRequest request) {
  if (request.path == '/support/tickets') {
    return {
      'data': [_ticket],
      'meta': {'total': 1}
    };
  }
  if (request.path == '/support/tickets/ticket-1') {
    return {
      'data': _ticket,
      'messageMeta': {'total': 1}
    };
  }
  if (request.path == '/admin/feature-flags') {
    return {
      'data': [
        {
          'key': 'moderation.bulk',
          'enabled': true,
          'rollout': 100,
          'roles': <String>[],
          'version': 3
        }
      ]
    };
  }
  if (request.path == '/admin/moderation-v2/reports') {
    return {
      'data': {
        'decisions': [
          {'total': 12}
        ],
        'appeals': [
          {'total': 3}
        ],
        'escalations': 2,
        'queue': []
      }
    };
  }
  if (request.path == '/admin/finance/reconciliation') {
    return {
      'data': {
        'readOnly': true,
        'totals': {'billed': 15000000},
        'mismatches': []
      }
    };
  }
  return {
    'data': <Map<String, dynamic>>[],
    'meta': {'total': 0}
  };
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget screen,
    {Size size = const Size(390, 844),
    _Api? api,
    List<String> permissions = const [],
    List<AdminRequest>? requests,
    GlobalKey? boundary}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
        adminApiProvider.overrideWithValue(api ?? _Api()),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(permissions)),
        adminWorkspaceResourceProvider.overrideWith((ref, request) async {
          requests?.add(request);
          return _response(request);
        }),
      ],
      child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(theme: AppTheme.dark, home: screen))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  testWidgets(
      'requester can create a ticket without requesting admin capabilities',
      (tester) async {
    final api = _Api(), requests = <AdminRequest>[];
    await _pump(tester, const AdminSupportCenterScreen(userMode: true),
        api: api, requests: requests);
    await tester.tap(find.text('Tạo yêu cầu'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Yêu cầu kiểm tra hợp đồng');
    await tester.enterText(find.byType(TextFormField).at(1),
        'Tôi cần hỗ trợ kiểm tra nội dung hợp đồng thuê phòng.');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commands.single.$1, '/support/tickets');
    expect(api.commands.single.$2['category'], 'GENERAL');
    await tester.scrollUntilVisible(find.text('Gửi phản hồi'), 180,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Gửi phản hồi'), findsOneWidget);
    expect(
        requests.any((request) => request.path.startsWith('/admin/')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed replies preserve the draft and send optimistic version',
      (tester) async {
    final api = _Api()..fail = true;
    await _pump(
        tester,
        const AdminSupportCenterScreen(
            userMode: true, initialTicketId: 'ticket-1'),
        api: api);
    await tester.enterText(find.byType(TextField), 'Phản hồi chưa được gửi.');
    await tester.scrollUntilVisible(find.text('Gửi phản hồi'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(api.commands.single.$2['version'], 4);
    expect(find.text('Phản hồi chưa được gửi.'), findsOneWidget);
    expect(find.textContaining('409:'), findsOneWidget);
  });

  testWidgets('support detail fits mobile and desktop and captures both sizes',
      (tester) async {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      final boundary = GlobalKey();
      await _pump(
          tester,
          const AdminSupportCenterScreen(
              userMode: true, initialTicketId: 'ticket-1'),
          size: size,
          boundary: boundary);
      await tester.scrollUntilVisible(find.text('Gửi phản hồi'), 180,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Gửi phản hồi'), findsOneWidget);
      expect(find.text('Lưu ghi chú nội bộ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/admin234-support-${size.width.toInt()}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('feature flag update includes audit reason and expected version',
      (tester) async {
    final api = _Api();
    await _pump(tester, const AdminGovernanceScreen(),
        api: api, permissions: ['admin.flags.manage']);
    await tester.tap(find.byTooltip('Cấu hình rollout'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Giảm rollout để kiểm tra an toàn.');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commands.single.$1, '/admin/feature-flags/moderation.bulk');
    expect(api.commands.single.$2['version'], 3);
    expect(api.commands.single.$3, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance-only analyst never requests flag or team management',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, const AdminGovernanceScreen(section: 'finance'),
        permissions: ['admin.finance.read'], requests: requests);
    expect(find.text('15000000 đ'), findsOneWidget);
    expect(
        requests.every(
            (request) => const ['/admin/finance/reconciliation', '/admin/finance/transactions'].contains(request.path)),
        isTrue);
    expect(find.text('Feature flags'), findsNothing);
    expect(find.text('Tạo lịch báo cáo'), findsNothing);
  });

  testWidgets(
      'moderation report counts decisions rather than aggregation groups',
      (tester) async {
    await _pump(tester, const AdminModerationV2Screen(),
        permissions: ['admin.moderation.reports']);
    expect(find.text('12 quyết định · 3 khiếu nại · 2 escalation'),
        findsOneWidget);
    expect(find.text('Kiểm duyệt hàng loạt'), findsNothing);
  });

  testWidgets(
      'changing session hides old ticket data and disables stale commands',
      (tester) async {
    final api = _Api();
    final container = await _pump(
        tester,
        const AdminSupportCenterScreen(
            userMode: true, initialTicketId: 'ticket-1'),
        api: api);
    container.read(_identity.notifier).state = 'user-2';
    await tester.pumpAndSettle();
    expect(find.text('Hợp đồng cần kiểm tra lại'), findsNothing);
    expect(find.text('Gửi phản hồi'), findsNothing);
    expect(api.commands, isEmpty);
  });
}
