import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_sessions_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

class _Api extends AdminApi {
  _Api() : super(Dio());
  final commands = <String>[];
  @override
  Future<Map<String, dynamic>> command(String path, Map<String, dynamic> data,
      {bool patch = false}) async {
    commands.add(path);
    return {
      'data': {'revoked': true}
    };
  }
}

void main() {
  final identity = StateProvider((ref) => 'admin-1');
  final response = {
    'data': [
      {
        'id': 'current-1',
        'device': 'Flutter iOS',
        'ip': '127.0.0.0',
        'lastSeenAt': '2026-10-25T10:00:00Z',
        'current': true
      },
      {
        'id': 'other-1',
        'device': 'Browser desktop',
        'ip': '127.0.0.0',
        'lastSeenAt': '2026-10-25T10:00:00Z',
        'current': false
      },
    ]
  };

  Future<ProviderContainer> pump(
      WidgetTester tester, _Api api, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWith((ref) => ref.watch(identity)),
      adminCapabilitiesProvider
          .overrideWith((_) async => const AdminCapabilities([])),
      adminApiProvider.overrideWithValue(api),
      adminResourceProvider.overrideWith((ref, request) async => response),
    ], child: const MaterialApp(home: AdminSessionsScreen())));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
        tester.element(find.byType(AdminSessionsScreen)));
  }

  testWidgets(
      'confirms individual revocation and never offers current-session revocation',
      (tester) async {
    final api = _Api();
    await pump(tester, api, const Size(390, 844));
    expect(find.text('Thiết bị hiện tại'), findsOneWidget);
    expect(find.text('Thu hồi phiên này'), findsOneWidget);
    await tester.tap(find.text('Thu hồi phiên này'));
    await tester.pumpAndSettle();
    expect(api.commands, isEmpty);
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(api.commands, ['/auth/sessions/other-1/revoke']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bulk revoke retains the current session and fits desktop',
      (tester) async {
    final api = _Api();
    await pump(tester, api, const Size(1280, 900));
    await tester.tap(find.text('Đăng xuất thiết bị khác'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(api.commands, ['/auth/sessions/revoke-all']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides old device information when the account changes',
      (tester) async {
    final api = _Api();
    final container = await pump(tester, api, const Size(390, 844));
    container.read(identity.notifier).state = 'admin-2';
    await tester.pumpAndSettle();
    expect(find.textContaining('Phiên đăng nhập đã thay đổi'), findsOneWidget);
    expect(find.text('Thiết bị hiện tại'), findsNothing);
  });
}
