import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_finance_workflow.dart';
import 'package:rental_room_management/features/admin/admin_notification_queue.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

void main() {
  final identity = StateProvider<String?>((ref) => 'admin-1');
  final permissions = StateProvider<List<String>>((ref) => const [
        'admin.finance.reconcile',
        'admin.operations.manage',
      ]);
  final panels = [
    (
      name: 'finance',
      widget: const AdminFinanceWorkflow(),
      title: 'Đối soát sao kê ngân hàng',
      action: 'Nhập sao kê CSV',
    ),
    (
      name: 'notifications',
      widget: const AdminNotificationQueue(),
      title: 'Hàng đợi thông báo và dead letters',
      action: 'Thử lại thông báo',
    ),
  ];

  Future<ProviderContainer> pumpPanel(
    WidgetTester tester,
    Widget panel,
    List<AdminRequest> requests, {
    bool authenticated = true,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        if (!authenticated) identity.overrideWith((ref) => null),
        sessionIdentityProvider.overrideWith((ref) => ref.watch(identity)),
        adminCapabilitiesProvider.overrideWith(
            (ref) async => AdminCapabilities(ref.watch(permissions))),
        adminWorkspaceResourceProvider.overrideWith((ref, request) async {
          requests.add(request);
          if (request.path.endsWith('notification-delivery')) {
            return {
              'data': {
                'counts': [],
                'dead': [
                  {
                    'id': 'delivery-1',
                    'channel': 'EMAIL',
                    'lastError': 'delivery unavailable',
                    'attempts': 3,
                    'createdAt': '2026-10-26T08:00:00Z',
                  }
                ],
              }
            };
          }
          return {'data': []};
        }),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: panel)),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  for (final panel in panels) {
    Finder action() => panel.name == 'finance'
        ? find.text(panel.action)
        : find.byTooltip(panel.action);

    for (final nextIdentity in <String?>['admin-2', null]) {
      testWidgets('${panel.name} hides stale data on session $nextIdentity',
          (tester) async {
        final requests = <AdminRequest>[];
        final container = await pumpPanel(tester, panel.widget, requests);
        expect(find.text(panel.title), findsOneWidget);
        final requestCount = requests.length;

        container.read(identity.notifier).state = nextIdentity;
        await tester.pumpAndSettle();

        expect(find.text(panel.title), findsNothing);
        expect(action(), findsNothing);
        expect(requests.length, requestCount);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${panel.name} updates actions when permissions change',
        (tester) async {
      final requests = <AdminRequest>[];
      final container = await pumpPanel(tester, panel.widget, requests);
      expect(action(), findsOneWidget);

      container.read(permissions.notifier).state = [];
      await tester.pumpAndSettle();

      expect(find.text(panel.title), findsOneWidget);
      expect(action(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${panel.name} never fetches without a session',
        (tester) async {
      final requests = <AdminRequest>[];
      await pumpPanel(tester, panel.widget, requests, authenticated: false);

      expect(find.text(panel.title), findsNothing);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
