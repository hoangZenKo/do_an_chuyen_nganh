import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_overview_page.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/admin_workspace_models.dart';
import 'package:rental_room_management/models/auth_models.dart';

import '../test/fixtures/admin_overview_fixture.dart';

const permissions = [
  'admin.dashboard.view',
  'admin.accounts.view',
  'admin.properties.view',
  'admin.properties.manage',
  'admin.finance.read',
  'admin.notifications.view',
  'admin.support.read',
  'admin.reports.manage'
];

class OverviewPreviewSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
      user: LandlordUser(
          id: 'admin-preview',
          fullName: 'Admin · QA minh họa',
          email: 'preview@example.test',
          role: 'admin',
          permissions: permissions),
      accessToken: 'preview',
      refreshToken: 'preview'));
}

void main() {
  final router = GoRouter(routes: [
    GoRoute(path: '/', redirect: (_, __) => '/admin'),
    GoRoute(path: '/admin', builder: (_, __) => const AdminOverviewPage()),
    GoRoute(
        path: '/admin/reports/overview',
        builder: (_, __) => const AdminOverviewPage(reports: true)),
    for (final route in [
      '/admin/accounts',
      '/admin/properties',
      '/admin/notifications',
      '/admin/security',
      '/admin/report-schedules',
      '/admin/support-center'
    ])
      GoRoute(
          path: route,
          builder: (context, __) => Scaffold(
              appBar: AppBar(title: const Text('QA · tuyến ngoài Phase 1')),
              body: Center(
                  child: TextButton(
                      onPressed: () => context.go('/admin'),
                      child: const Text('Về tổng quan'))))),
  ]);
  runApp(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(OverviewPreviewSession.new),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(permissions)),
        adminWorkspaceResourceProvider.overrideWith((ref, request) async =>
            adminOverviewFixture(days: request.query['days'] as int? ?? 30)),
        adminWorkspaceSummaryProvider.overrideWith((ref) async =>
            AdminWorkspaceSummary(
                items: const [
                  AdminWorkspaceItem(
                      key: 'support_overdue',
                      label: 'Ticket quá SLA',
                      route: '/admin/support-center',
                      permission: 'admin.support.read',
                      priority: 1,
                      count: 2,
                      available: true)
                ],
                updatedAt: DateTime.utc(2026, 10, 27, 12),
                partial: false,
                pendingCount: 2,
                unreadCount: 3)),
      ],
      child: MaterialApp.router(
          routerConfig: router, debugShowCheckedModeBanner: false)));
}
