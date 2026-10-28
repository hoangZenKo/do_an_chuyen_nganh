import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_delivery_jobs_panel.dart';
import 'package:rental_room_management/features/admin/admin_lifecycle_panel.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

const _permissions = ['admin.dashboard.view', 'admin.admins.manage', 'admin.sessions.revoke', 'admin.operations.view'];
final _owner = StateProvider<String?>((ref) => 'reviewer');
final _rights = StateProvider<List<String>>((ref) => _permissions);

class _Api extends AdminApi {
  _Api() : super(Dio());
  final calls = <(String, Map<String, dynamic>)>[];
  Completer<Map<String, dynamic>>? pending;
  ApiFailure? failure;
  @override
  Future<Map<String, dynamic>> authorizedCommand(String path, Map<String, dynamic> data, {bool patch = false, required AdminStepUpPrompt prompt}) async {
    calls.add((path, data));
    if (failure != null) throw failure!;
    return pending?.future ?? {'data': {'updated': true}};
  }
}

Map<String, dynamic> _lifecycle({String status = 'PENDING'}) => {
  'data': {
    'id': 'target', 'isActive': true, 'version': 7, 'activeSessions': 2,
    'lastActiveAt': '2026-10-27T01:00:00Z',
    'invitation': {'status': status, 'expiresAt': '2026-10-27T02:00:00Z'},
    'history': [{'summary': 'Evidence reference OPS-42', 'action': 'admin.profile_update', 'createdAt': '2026-10-27T00:00:00Z'}],
  },
};

Future<ProviderContainer> _pump(WidgetTester tester, Widget widget, {
  List<String> permissions = _permissions, String? owner = 'reviewer', _Api? api,
  String status = 'PENDING', List<AdminRequest>? requests, Size size = const Size(1200, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() { tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio(); });
  final container = ProviderContainer(overrides: [
    _owner.overrideWith((ref) => owner), _rights.overrideWith((ref) => permissions),
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_owner)),
    adminCapabilitiesProvider.overrideWith((ref) async => AdminCapabilities(ref.watch(_rights))),
    if (api != null) adminApiProvider.overrideWithValue(api),
    adminResourceProvider.overrideWith((ref, request) async {
      requests?.add(request);
      if (request.path.endsWith('/lifecycle')) return _lifecycle(status: status);
      return {'data': [{'id': 'job-safe-id', 'kind': 'ACCOUNT_ACCESS', 'status': 'DEAD', 'attempts': 6, 'lastError': 'NETWORK_ERROR'}], 'meta': {'total': 1}};
    }),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(size.width < 500 ? 1.5 : 1)), child: child!),
    home: RepaintBoundary(key: const ValueKey('milestone-qa'), child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: widget))),
  )));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openLifecycle(WidgetTester tester) async {
  await tester.tap(find.text('Lời mời, session và lịch sử'));
  await tester.pumpAndSettle();
}

Future<void> _submitReason(WidgetTester tester, String button) async {
  await tester.ensureVisible(find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Lý do (ghi vào audit)'), 'Reviewed independent operational evidence');
  await tester.tap(find.text('Xác nhận'));
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['ADMIN_QA_OUTPUT'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('milestone-qa')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('lifecycle does not fetch without permission or session', (tester) async {
    for (final owner in <String?>['reviewer', null]) {
      final requests = <AdminRequest>[];
      await _pump(tester, AdminLifecyclePanel(key: ValueKey(owner), userId: 'target'), owner: owner, permissions: [], requests: requests);
      expect(find.text('Lời mời, session và lịch sử'), findsNothing);
      expect(requests, isEmpty);
    }
  });

  testWidgets('resend binds the current target version and does not double submit; old-session result is discarded', (tester) async {
    final api = _Api()..pending = Completer<Map<String, dynamic>>();
    final container = await _pump(tester, const AdminLifecyclePanel(userId: 'target'), api: api);
    await _openLifecycle(tester);
    await _submitReason(tester, 'Gửi lại lời mời');
    expect(api.calls.single.$1, '/admin/admins/target/resend-invite');
    expect(api.calls.single.$2['version'], 7);
    await tester.pump(const Duration(milliseconds: 100));
    final resendButton = find.ancestor(of: find.text('Gửi lại lời mời'), matching: find.byWidgetPredicate((widget) => widget is OutlinedButton));
    expect(tester.widget<OutlinedButton>(resendButton).onPressed, isNull);
    container.read(_owner.notifier).state = 'another-admin';
    await tester.pump();
    api.pending!.complete({'data': {'queued': true}});
    await tester.pumpAndSettle();
    expect(find.textContaining('Evidence reference'), findsNothing);
    expect(find.textContaining('Session hợp lệ'), findsNothing);
    expect(api.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('capability revocation hides details and actions immediately', (tester) async {
    final container = await _pump(tester, const AdminLifecyclePanel(userId: 'target'));
    await _openLifecycle(tester);
    expect(find.text('Session hợp lệ: 2'), findsOneWidget);
    container.read(_rights.notifier).state = [];
    await tester.pumpAndSettle();
    expect(find.text('Session hợp lệ: 2'), findsNothing);
    expect(find.text('Gửi lại lời mời'), findsNothing);
  });

  testWidgets('self action is absent', (tester) async {
    await _pump(tester, const AdminLifecyclePanel(userId: 'reviewer'));
    await _openLifecycle(tester);
    expect(find.text('Gửi lại lời mời'), findsNothing);
    expect(find.text('Thu hồi session'), findsNothing);
  });

  testWidgets('activated invites cannot be resent and revoke requires its own capability', (tester) async {
    await _pump(tester, const AdminLifecyclePanel(key: ValueKey('activated'), userId: 'target'), status: 'ACTIVATED', permissions: ['admin.admins.manage']);
    await _openLifecycle(tester);
    expect(find.text('Đã kích hoạt'), findsOneWidget);
    expect(find.text('Gửi lại lời mời'), findsNothing);
    expect(find.text('Thu hồi session'), findsNothing);
  });

  testWidgets('409 refreshes the read model without automatically replaying the mutation', (tester) async {
    final api = _Api()..failure = const ApiFailure(message: 'Admin đã thay đổi. Tải lại trước khi tiếp tục.', statusCode: 409);
    final requests = <AdminRequest>[];
    await _pump(tester, const AdminLifecyclePanel(userId: 'target'), api: api, requests: requests);
    await _openLifecycle(tester);
    await _submitReason(tester, 'Thu hồi session');
    await tester.pumpAndSettle();
    expect(find.textContaining('Admin đã thay đổi'), findsOneWidget);
    expect(api.calls, hasLength(1));
    expect(requests.where((request) => request.path.endsWith('/lifecycle')).length, greaterThan(1));
  });

  for (final size in [const Size(390, 1100), const Size(1200, 1000)]) {
    testWidgets('lifecycle and safe delivery metadata fit ${size.width} with large phone text', (tester) async {
      final requests = <AdminRequest>[];
      await _pump(tester, const Column(children: [AdminLifecyclePanel(userId: 'target'), AdminDeliveryJobsPanel()]), requests: requests, size: size);
      await _openLifecycle(tester);
      await _capture(tester, 'lifecycle-${size.width.toInt()}');
      await tester.ensureVisible(find.text('Email và cảnh báo: job cần điều tra'));
      await tester.tap(find.text('Email và cảnh báo: job cần điều tra'));
      await tester.pumpAndSettle();
      expect(requests.last.query, {'jobStatus': 'DEAD', 'page': 1, 'limit': 20});
      await tester.ensureVisible(find.text('job-safe-id'));
      await _capture(tester, 'delivery-${size.width.toInt()}');
      expect(find.text('job-safe-id'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
