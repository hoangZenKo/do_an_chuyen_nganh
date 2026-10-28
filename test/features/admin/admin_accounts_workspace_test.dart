import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/data/admin/admin_repository.dart';
import 'package:rental_room_management/features/admin/admin_accounts_screen.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_workspace_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_account_detail.dart';
import 'package:rental_room_management/models/admin_models.dart';

const _customer = AdminAccount(
    id: 'customer',
    fullName: 'Workspace customer',
    email: 'w***@example.test',
    role: 'LANDLORD',
    isActive: true,
    createdAt: null,
    version: 3);

class _Repository extends AdminRepository {
  _Repository() : super(api: AdminApi(Dio()));
  int listReads = 0;
  int detailReads = 0;
  @override
  Future<AdminPagedResponse<AdminAccount>> accounts(
      {int page = 1,
      int limit = 20,
      String? search,
      String? role,
      String status = 'all',
      String? from,
      String? to}) async {
    listReads++;
    return AdminPagedResponse(
        data: const [_customer], page: page, limit: limit, total: 1, pages: 1);
  }

  @override
  Future<AdminAccountDetail> account(String id) async {
    detailReads++;
    return const AdminAccountDetail(
        account: _customer, properties: 2, tenants: 4, history: []);
  }
}

void main() {
  for (final size in [const Size(1440, 1000), const Size(320, 1000)]) {
    testWidgets(
        'workspace list/detail routes use typed repository at width ${size.width}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _Repository();
      final dynamicReads = <String>[];
      final router = GoRouter(initialLocation: '/admin/accounts', routes: [
        GoRoute(
            path: '/admin/accounts',
            builder: (_, __) => const AdminAccountsScreen()),
        GoRoute(
            path: '/admin/accounts/:id',
            builder: (_, state) => AdminWorkspaceScreen(
                section: 'accounts', accountId: state.pathParameters['id'])),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionIdentityProvider.overrideWith((ref) => 'operator'),
            adminCapabilitiesProvider.overrideWith((ref) async =>
                const AdminCapabilities(['admin.accounts.view'])),
            adminRepositoryProvider.overrideWithValue(repository),
            adminResourceProvider.overrideWith((ref, request) async {
              dynamicReads.add(request.path);
              return {'data': []};
            }),
          ],
          child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.dark,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(size.width < 500 ? 2 : 1)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(find.text('Workspace customer'), findsOneWidget);
      expect(repository.listReads, 1);
      await tester.tap(find.byTooltip('Làm mới workspace'));
      await tester.pumpAndSettle();
      expect(repository.listReads, 2);
      await tester.ensureVisible(find.text('Workspace customer'));
      await tester.tap(find.text('Workspace customer'));
      await tester.pumpAndSettle();
      expect(find.text('2 khu trọ · 4 hồ sơ người thuê'), findsOneWidget);
      expect(repository.detailReads, 1);
      expect(
          dynamicReads
              .where((resource) => resource.startsWith('/admin/accounts')),
          isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
