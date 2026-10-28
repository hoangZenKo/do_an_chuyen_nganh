import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/data/admin/admin_repository.dart';
import 'package:rental_room_management/features/admin/admin_properties_screen.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_moderation_screen.dart';
import 'package:rental_room_management/features/admin/admin_property_detail_screen.dart';
import 'package:rental_room_management/features/admin/admin_property_form_screen.dart';
import 'package:rental_room_management/features/admin/admin_rooms_screen.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_inventory.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/auth_models.dart';
import '../../fixtures/admin_accounts_capture.dart';

final _owner = StateProvider<String?>((ref) => 'admin-1');
final _rights = StateProvider<List<String>>((ref) => ['admin.properties.view']);

const _landlord = AdminPropertyLandlord(
    id: 'owner-1',
    fullName: 'Chủ trọ An',
    email: 'a***@test.vn',
    phone: '09***12',
    isActive: true);
const _listing = AdminPropertyListing(
    id: 'listing-1',
    title: 'Phòng ban công',
    status: 'PENDING',
    version: 3,
    monthlyRent: 3500000);
const _property = AdminPropertySummary(
    id: 'property-1',
    name: 'Khu trọ An',
    address: 'Thủ Đức',
    landlord: _landlord,
    roomCount: 25,
    occupiedCount: 10,
    vacantCount: 15);
const _room = AdminRoomSummary(
    id: 'room-1',
    name: 'Phòng A101',
    status: 'VACANT',
    basePrice: 3000000,
    listing: _listing,
    property: AdminRoomProperty(
        id: 'property-1',
        name: 'Khu trọ An',
        address: 'Thủ Đức',
        isArchived: false,
        landlord: _landlord));

class _Repository extends AdminRepository {
  _Repository() : super(api: AdminApi(Dio()));
  final propertyQueries = <AdminPropertiesQuery>[];
  final roomQueries = <AdminRoomsQuery>[];
  int detailCalls = 0;
  int writes = 0;
  @override
  Future<AdminPropertySummary> createProperty(
      {required String landlordId,
      required String name,
      required String address}) async {
    writes++;
    return _property;
  }

  Completer<AdminPagedResponse<AdminPropertySummary>>? pending;
  @override
  Future<AdminPagedResponse<AdminPropertySummary>> properties(
      AdminPropertiesQuery query) async {
    propertyQueries.add(query);
    if (pending != null) return pending!.future;
    return AdminPagedResponse(
        data: [_property], page: query.page, limit: 20, total: 21, pages: 2);
  }

  @override
  Future<AdminPagedResponse<AdminRoomSummary>> rooms(
      AdminRoomsQuery query) async {
    roomQueries.add(query);
    return AdminPagedResponse(
        data: [_room], page: query.page, limit: 20, total: 21, pages: 2);
  }

  @override
  Future<AdminPropertyDetail> property(String id) async {
    detailCalls++;
    return AdminPropertyDetail(
        id: _property.id,
        name: _property.name,
        address: _property.address,
        landlord: _landlord,
        roomCount: 25,
        occupiedCount: 10,
        vacantCount: 15,
        rooms: const [
          AdminPropertyRoom(
              id: 'room-1',
              name: 'Phòng A101',
              status: 'vacant',
              basePrice: 3000000,
              listing: _listing)
        ]);
  }
}

Future<ProviderContainer> _pump(
    WidgetTester tester, _Repository repo, Widget panel,
    {List<String>? rights,
    Size size = const Size(1100, 1500),
    double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_owner)),
        if (rights != null) _rights.overrideWith((ref) => rights),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(ref.watch(_rights))),
        adminRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: adminAccountsCaptureKey,
              child: Scaffold(body: SingleChildScrollView(child: panel))))));
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Future<void> _revealPropertyAction(WidgetTester tester, Finder target) async {
  for (var attempt = 0;
      attempt < 8 && target.hitTestable().evaluate().isEmpty;
      attempt++) {
    await tester.drag(find.byKey(const ValueKey('admin-properties-list')),
        const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  setUpAll(loadAdminAccountsCaptureFonts);
  testWidgets(
      'properties debounce and filters reset pagination; viewer cannot edit',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, const AdminPropertiesPanel());
    await tester.pumpAndSettle();
    expect(find.text('Khu trọ An'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(find.text('Thêm khu trọ'), findsNothing);
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(repo.propertyQueries.last.page, 2);
    await tester.enterText(
        find.byKey(const ValueKey('property-search')), '  An  ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.propertyQueries.last.search, isNull);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(repo.propertyQueries.last.search, 'An');
    expect(repo.propertyQueries.last.page, 1);
    await tester.tap(find.byKey(const ValueKey('property-archived')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã lưu trữ').last);
    await tester.pumpAndSettle();
    expect(repo.propertyQueries.last.archived, 'archived');
    await captureAdminAccounts(tester, 'inventory-properties-desktop');
  });

  testWidgets(
      'no inventory fetch without rights; old response hidden on identity change',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, const AdminPropertiesPanel(), rights: []);
    await tester.pumpAndSettle();
    expect(repo.propertyQueries, isEmpty);
    await tester.pumpWidget(const SizedBox());
    repo.pending = Completer();
    final container = await _pump(tester, repo, const AdminPropertiesPanel());
    container.read(_owner.notifier).state = 'admin-2';
    repo.pending!.complete(const AdminPagedResponse(
        data: [_property], page: 1, limit: 20, total: 1, pages: 1));
    await tester.pumpAndSettle();
    expect(find.text('Khu trọ An'), findsNothing);
    expect(container.read(adminPropertiesQueryProvider).page, 1);
  });

  testWidgets('rooms validate internal prices and preserve property scope',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, const AdminRoomsPanel(propertyId: 'property-1'));
    await tester.pumpAndSettle();
    expect(repo.roomQueries.single.propertyId, 'property-1');
    expect(find.text('Giá nội bộ: 3.000.000 đ/tháng'), findsOneWidget);
    expect(find.text('Giá tin đăng: 3.500.000 đ/tháng'), findsOneWidget);
    expect(find.text('Kiểm duyệt tin này'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('room-min-price')), '4000000');
    await tester.enterText(
        find.byKey(const ValueKey('room-max-price')), '2000000');
    await tester.tap(find.text('Áp dụng giá'));
    await tester.pumpAndSettle();
    expect(repo.roomQueries.length, 1);
    expect(find.text('Giá tối thiểu không được lớn hơn giá tối đa.'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('room-max-price')), '5000000');
    await tester.tap(find.text('Áp dụng giá'));
    await tester.pumpAndSettle();
    expect(repo.roomQueries.last.minPrice, 4000000);
    expect(repo.roomQueries.last.maxPrice, 5000000);
    expect(repo.roomQueries.last.propertyId, 'property-1');
    await captureAdminAccounts(tester, 'inventory-rooms-desktop');
  });

  testWidgets(
      'detail shows bounded preview and complete counts; direct form is gated',
      (tester) async {
    final repo = _Repository();
    await _pump(
        tester, repo, const AdminPropertyDetailPanel(propertyId: 'property-1'));
    await tester.pumpAndSettle();
    expect(find.text('Xem trước 1 / 25 phòng'), findsOneWidget);
    expect(find.textContaining('10 đang thuê'), findsOneWidget);
    expect(find.text('a***@test.vn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.detailCalls = 0;
    await _pump(
        tester,
        repo,
        const SizedBox(
            height: 800,
            child: AdminPropertyFormScreen(propertyId: 'property-1')));
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 0);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('room filter and cards fit 320px with 200 percent text',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, const AdminRoomsPanel(),
        size: const Size(320, 1800), scale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureAdminAccounts(tester, 'inventory-rooms-mobile-200');
  });

  testWidgets(
      'permissions revoked hide room data; manager actions are separately authorized',
      (tester) async {
    final repo = _Repository();
    final container = await _pump(tester, repo, const AdminRoomsPanel(),
        rights: ['admin.properties.view', 'admin.listings.moderate']);
    await tester.pumpAndSettle();
    expect(find.text('Kiểm duyệt tin này'), findsOneWidget);
    container.read(_rights.notifier).state = [];
    await tester.pumpAndSettle();
    expect(find.text('Phòng A101'), findsNothing);
    expect(find.text('Kiểm duyệt tin này'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, repo, const AdminPropertiesPanel(),
        rights: ['admin.properties.view', 'admin.properties.manage']);
    await tester.pumpAndSettle();
    expect(find.text('Thêm khu trọ'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsOneWidget);
  });

  testWidgets(
      'pending action forwards exact target to real moderation workspace and refreshes on return',
      (tester) async {
    final repo = _Repository();
    final requests = <AdminRequest>[];
    final router = GoRouter(initialLocation: adminRoomsRoute, routes: [
      GoRoute(
          path: adminRoomsRoute,
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: AdminRoomsPanel()))),
      GoRoute(
          path: adminModerationRoute,
          builder: (_, state) =>
              AdminModerationScreen(initialFilters: state.uri.queryParameters)),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWith((ref) => 'admin-1'),
      adminCapabilitiesProvider.overrideWith((ref) async =>
          const AdminCapabilities(
              ['admin.properties.view', 'admin.listings.moderate'])),
      adminRepositoryProvider.overrideWithValue(repo),
      adminResourceProvider.overrideWith((ref, request) async {
        requests.add(request);
        return {
          'data': [],
          'meta': {'page': 1, 'limit': 20, 'total': 0, 'pages': 0}
        };
      }),
    ], child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm duyệt tin này'));
    await tester.pumpAndSettle();
    expect(
        requests
            .where((request) => request.path == '/admin/moderation/queue')
            .last
            .query,
        containsPair('search', 'listing-1'));
    expect(
        requests
            .where((request) => request.path == '/admin/moderation/queue')
            .last
            .query,
        containsPair('kind', 'LISTING'));
    router.pop();
    await tester.pumpAndSettle();
    expect(repo.roomQueries.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px property and detail previews fit at 200 percent text',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, const AdminPropertiesPanel(),
        size: const Size(320, 1800), scale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureAdminAccounts(tester, 'inventory-properties-mobile-200');
    await tester.pumpWidget(const SizedBox());
    await _pump(
        tester, repo, const AdminPropertyDetailPanel(propertyId: 'property-1'),
        size: const Size(320, 1800), scale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await captureAdminAccounts(tester, 'inventory-detail-mobile-200');
  });

  testWidgets(
      'property form controller refuses direct writes without management capability',
      (tester) async {
    final repo = _Repository();
    final container = await _pump(tester, repo, const AdminPropertiesPanel());
    await tester.pumpAndSettle();
    final subscription =
        container.listen(adminPropertyFormControllerProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(adminPropertyFormControllerProvider.future);
    await expectLater(
        container
            .read(adminPropertyFormControllerProvider.notifier)
            .submit(landlordId: 'owner', name: 'Name', address: 'Address'),
        throwsA(isA<Exception>()));
    expect(repo.writes, 0);
  });

  test(
      'inventory route guards allow viewers but keep form and moderation restricted',
      () {
    const session = AuthSession(
        user: LandlordUser(
            id: 'viewer',
            fullName: 'Viewer',
            email: 'v@test.vn',
            role: 'admin',
            permissions: ['admin.properties.view']),
        accessToken: 'access',
        refreshToken: 'refresh');
    for (final path in [
      adminPropertiesRoute,
      '/admin/properties/property-1',
      adminRoomsRoute
    ]) {
      expect(
          authRedirect(
              state: const SessionState.authenticated(session), location: path),
          isNull);
    }
    expect(
        authRedirect(
            state: const SessionState.authenticated(session),
            location: adminPropertyFormRoute),
        adminRoute);
    expect(
        authRedirect(
            state: const SessionState.authenticated(session),
            location: adminModerationRoute),
        adminRoute);
  });

  test('moderation URL targets one listing without unescaped query values', () {
    final uri = Uri.parse(adminListingModerationPath('listing/with ?query'));
    expect(uri.path, adminModerationRoute);
    expect(uri.queryParameters,
        {'kind': 'LISTING', 'search': 'listing/with ?query'});
  });

  for (final size in [const Size(1440, 1100), const Size(320, 1100)]) {
    testWidgets(
        'inventory shell preserves query on detail/back at ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repo = _Repository();
      final router = GoRouter(initialLocation: adminPropertiesRoute, routes: [
        GoRoute(
            path: adminPropertiesRoute,
            builder: (_, __) => const AdminPropertiesScreen()),
        GoRoute(
            path: adminPropertyDetailRoute,
            builder: (_, state) => AdminPropertyDetailScreen(
                propertyId: state.pathParameters['id']!)),
        GoRoute(
            path: adminRoomsRoute,
            builder: (_, state) => AdminRoomsScreen(
                propertyId: state.uri.queryParameters['propertyId'])),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionIdentityProvider.overrideWith((ref) => 'admin-1'),
            adminCapabilitiesProvider.overrideWith((ref) async =>
                const AdminCapabilities(['admin.properties.view'])),
            adminRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
              theme: AppTheme.dark,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(size.width < 500 ? 2 : 1)),
                  child: child!))));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('property-search')), 'An');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      {
        await _revealPropertyAction(tester, find.byTooltip('Trang sau'));
        await tester.tap(find.byTooltip('Trang sau'));
        await tester.pumpAndSettle();
        await _revealPropertyAction(tester, find.text('Xem chi tiết'));
        await tester.tap(find.text('Xem chi tiết'));
        await tester.pumpAndSettle();
        expect(find.text('Xem trước 1 / 25 phòng'), findsOneWidget);
        await tester.ensureVisible(find.text('Danh sách khu trọ'));
        await tester.tap(find.text('Danh sách khu trọ'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<TextField>(
                    find.byKey(const ValueKey('property-search')))
                .controller!
                .text,
            'An');
        expect(repo.propertyQueries.last.page, 2);
        await tester.ensureVisible(find.byTooltip('Làm mới workspace'));
        await tester.tap(find.byTooltip('Làm mới workspace'));
        await tester.pumpAndSettle();
        expect(repo.propertyQueries.length, 4);
      }
      router.go(adminRoomsPath(propertyId: 'property-1'));
      await tester.pumpAndSettle();
      expect(repo.roomQueries.last.propertyId, 'property-1');
      expect(tester.takeException(), isNull);
    });
  }
}
