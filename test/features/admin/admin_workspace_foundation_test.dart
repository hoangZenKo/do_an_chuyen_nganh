import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_workspace_scaffold.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/admin_workspace_models.dart';

const _permissions = [
  'admin.dashboard.view',
  'admin.support.read',
  'admin.notifications.view',
];

AdminWorkspaceSummary _summary() => AdminWorkspaceSummary(
      items: const [
        AdminWorkspaceItem(
            key: 'support_overdue',
            label: 'Ticket quá SLA',
            route: '/admin/support-center',
            permission: 'admin.support.read',
            priority: 1,
            count: 2,
            available: true),
        AdminWorkspaceItem(
            key: 'notifications',
            label: 'Thông báo chưa đọc',
            route: '/admin/notifications',
            permission: 'admin.notifications.view',
            priority: 4,
            count: 3,
            available: true),
      ],
      updatedAt: DateTime(2026, 10, 26, 10),
      partial: false,
      pendingCount: 2,
      unreadCount: 3,
    );

void main() {
  testWidgets('renders grouped navigation, counts and refresh action',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(initialLocation: '/admin', routes: [
      GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminWorkspaceScaffold(
              title: 'Tổng quan', location: '/admin', body: SizedBox())),
      GoRoute(path: '/admin/search', builder: (_, __) => const SizedBox()),
      GoRoute(
          path: '/admin/support-center',
          builder: (_, __) => const AdminWorkspaceScaffold(
              title: 'Support Center',
              location: '/admin/support-center',
              body: SizedBox())),
      GoRoute(
          path: '/admin/notifications', builder: (_, __) => const SizedBox()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWithValue('admin-1'),
      adminCapabilitiesProvider
          .overrideWith((_) async => const AdminCapabilities(_permissions)),
      adminWorkspaceSummaryProvider.overrideWith((_) async => _summary()),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    expect(find.text('Rental Admin'), findsOneWidget);
    expect(find.text('Support Center'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('admin-nav-/admin/support-center')),
            matching: find.text('2')),
        findsOneWidget);
    expect(
        find.byTooltip('Chuyển nhanh chức năng (Ctrl/Cmd K)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not fetch workspace summary without dashboard permission',
      (tester) async {
    var fetched = false;
    final router = GoRouter(initialLocation: '/admin/support-center', routes: [
      GoRoute(
          path: '/admin/support-center',
          builder: (_, __) => const AdminWorkspaceScaffold(
              title: 'Support Center',
              location: '/admin/support-center',
              body: SizedBox())),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWithValue('admin-1'),
      adminCapabilitiesProvider.overrideWith(
          (_) async => const AdminCapabilities(['admin.support.read'])),
      adminWorkspaceSummaryProvider.overrideWith((_) async {
        fetched = true;
        return _summary();
      }),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(fetched, isFalse);
    expect(find.text('Support Center'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
