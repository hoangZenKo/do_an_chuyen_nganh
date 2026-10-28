import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/data/admin/admin_repository.dart';
import 'package:rental_room_management/features/admin/admin_accounts_panel.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import '../../fixtures/admin_accounts_capture.dart';

final _owner = StateProvider<String?>((ref) => 'admin-1');
final _rights = StateProvider<List<String>>((ref) => ['admin.accounts.view']);

class _Repository extends AdminRepository {
  _Repository() : super(api: AdminApi(Dio()));
  final queries = <AdminAccountsQuery>[];
  Object? failure;
  Completer<AdminPagedResponse<AdminAccount>>? pending;

  @override
  Future<AdminPagedResponse<AdminAccount>> accounts(
      {int page = 1,
      int limit = 20,
      String? search,
      String? role,
      String status = 'all',
      String? from,
      String? to}) async {
    queries.add(AdminAccountsQuery(
        page: page,
        limit: limit,
        search: search,
        role: role,
        status: status,
        from: from,
        to: to));
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return AdminPagedResponse(data: [
      AdminAccount(
          id: 'customer-$page',
          fullName: 'Customer $page',
          email: 'c***@example.test',
          role: 'LANDLORD',
          isActive: true,
          createdAt: DateTime.utc(2026, 10, 27))
    ], page: page, limit: limit, total: 21, pages: 2);
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _Repository repository,
    {List<String>? rights,
    String? owner = 'admin-1',
    Size size = const Size(1000, 900),
    double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
      overrides: [
        _owner.overrideWith((ref) => owner),
        if (rights != null) _rights.overrideWith((ref) => rights),
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_owner)),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(ref.watch(_rights))),
        adminRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: const RepaintBoundary(
              key: adminAccountsCaptureKey,
              child: Scaffold(
                  body: SingleChildScrollView(child: AdminAccountsPanel()))))));
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  setUpAll(loadAdminAccountsCaptureFonts);
  testWidgets('search debounces; role filter resets pagination',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Customer 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.page, 2);
    await tester.enterText(
        find.byKey(const ValueKey('account-search')), '  Owner  ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.queries.last.search, isNull);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'Owner');
    expect(repository.queries.last.page, 1);
    await tester.tap(find.byKey(const ValueKey('account-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người thuê').last);
    await tester.pumpAndSettle();
    expect(repository.queries.last.role, 'TENANT');
    await captureAdminAccounts(tester, 'accounts-desktop');
  });

  testWidgets('no request without capability or authenticated owner',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository, rights: []);
    await tester.pumpAndSettle();
    expect(repository.queries, isEmpty);
    expect(find.text('Customer 1'), findsNothing);
  });

  testWidgets('logout hides loaded data and does not request another page',
      (tester) async {
    final repository = _Repository();
    final container = await _pump(tester, repository);
    await tester.pumpAndSettle();
    final count = repository.queries.length;
    container.read(_owner.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.text('Customer 1'), findsNothing);
    expect(repository.queries.length, count);
  });

  testWidgets('unauthenticated panel never starts an account request',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository, owner: null);
    await tester.pumpAndSettle();
    expect(repository.queries, isEmpty);
  });

  testWidgets('late list response cannot render after a session change',
      (tester) async {
    final repository = _Repository()
      ..pending = Completer<AdminPagedResponse<AdminAccount>>();
    final container = await _pump(tester, repository);
    container.read(_owner.notifier).state = 'another-admin';
    await tester.pump();
    repository.pending!.complete(AdminPagedResponse(data: [
      AdminAccount(
          id: 'late',
          fullName: 'Private old customer',
          email: 'p***@example.test',
          role: 'TENANT',
          isActive: true,
          createdAt: DateTime.utc(2026))
    ], page: 1, limit: 20, total: 1, pages: 1));
    await tester.pumpAndSettle();
    expect(find.text('Private old customer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date range sends Vietnam calendar boundaries and can be cleared',
      (tester) async {
    final repository = _Repository();
    final container = await _pump(tester, repository);
    await tester.pumpAndSettle();
    container.read(adminAccountsQueryProvider.notifier).state =
        const AdminAccountsQuery(
            from: '2026-10-25T17:00:00.000Z', to: '2026-10-27T16:59:59.999Z');
    await tester.pumpAndSettle();
    expect(repository.queries.last.from, '2026-10-25T17:00:00.000Z');
    expect(find.text('26/10/2026 - 27/10/2026'), findsOneWidget);
    await tester.tap(find.text('26/10/2026 - 27/10/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.from, '2026-10-25T17:00:00.000Z');
    expect(repository.queries.last.to, '2026-10-27T16:59:59.999Z');
    await tester.tap(find.text('Bỏ lọc ngày'));
    await tester.pumpAndSettle();
    final cleared = container.read(adminAccountsQueryProvider);
    expect(cleared.from, isNull);
    expect(cleared.to, isNull);
    expect(cleared.page, 1);
    expect(find.text('Lọc ngày tạo'), findsOneWidget);
  });

  testWidgets('returning from detail preserves the selected list page',
      (tester) async {
    final repository = _Repository();
    final router = GoRouter(initialLocation: '/admin/accounts', routes: [
      GoRoute(
          path: '/admin/accounts',
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: AdminAccountsPanel()))),
      GoRoute(
          path: '/admin/accounts/:id',
          builder: (context, state) => Scaffold(
              body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back to accounts')))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWith((ref) => 'admin-1'),
      adminCapabilitiesProvider.overrideWith(
          (ref) async => const AdminCapabilities(['admin.accounts.view'])),
      adminRepositoryProvider.overrideWithValue(repository),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.dark)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer 2'));
    await tester.pumpAndSettle();
    expect(find.text('Back to accounts'), findsOneWidget);
    await tester.tap(find.text('Back to accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Customer 2'), findsOneWidget);
    expect(repository.queries.last.page, 2);
  });

  testWidgets('mobile enlarged text has no overflow; errors can retry',
      (tester) async {
    final repository = _Repository()
      ..failure = const ApiFailure(message: 'offline');
    await _pump(tester, repository, size: const Size(320, 900), textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    repository.failure = null;
    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Customer 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureAdminAccounts(tester, 'accounts-mobile-large-text');
  });
}
