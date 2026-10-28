import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/listings_api.dart';
import 'package:rental_room_management/data/listings/listings_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/explore_screen.dart';
import 'package:rental_room_management/features/listings/listing_detail_screen.dart';
import 'package:rental_room_management/features/listings/listing_form_screen.dart';
import 'package:rental_room_management/features/listings/listing_widgets.dart';
import 'package:rental_room_management/features/listings/listings_providers.dart';
import 'package:rental_room_management/features/listings/manage_listings_screen.dart';
import 'package:rental_room_management/features/listings/tenant_home_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/models/room_listing.dart';
import '../chatbot/chatbot_test_support.dart';
import '../../data/listings/listings_api_test.dart' show listingJson;

class FakeListingsRepository extends ListingsRepository {
  FakeListingsRepository() : super(ListingsApi(Dio()));
  final queries = <ListingQuery>[];
  int calls = 0;
  bool fail = false;
  List<RoomListing> browseItems = [RoomListing.fromJson(listingJson)];
  String? savedId;
  Map<String, dynamic>? saved;
  String? lastAction;
  String? reviewNote;
  Future<ListingPage> Function()? management;
  @override
  Future<ListingPage> browse(ListingQuery query) async {
    queries.add(query);
    if (fail) throw const ApiFailure(message: 'Mất kết nối');
    return ListingPage(
        items: query.search == 'không có' ? [] : browseItems,
        total: query.search == 'không có' ? 0 : 13,
        page: query.page,
        limit: 12);
  }

  @override
  Future<RoomListing> detail(String id) async {
    if (fail) {
      throw const ApiFailure(message: 'Tin đã được ẩn', statusCode: 404);
    }
    return RoomListing.fromJson(listingJson);
  }

  @override
  Future<ListingPage> manage(
      {required bool admin, required int page, String? status}) {
    calls++;
    return management?.call() ??
        Future.value(ListingPage(items: [
          RoomListing.fromJson(
              {...listingJson, 'status': 'PENDING', 'roomId': 'r1'})
        ], total: 1, page: page, limit: 12));
  }

  @override
  Future<void> save(Map<String, dynamic> content, {String? id}) async {
    savedId = id;
    saved = content;
  }

  @override
  Future<void> action(RoomListing listing, String action,
      {String? note}) async {
    lastAction = action;
    reviewNote = note;
  }
}

class AdminListingsSession extends ChatTestSession {
  @override
  SessionState build() =>
      SessionState.authenticated(chatSession('admin', role: 'admin'));
}

Future<void> showExplore(
    WidgetTester tester, FakeListingsRepository repository) async {
  final router = GoRouter(initialLocation: exploreRoute, routes: [
    GoRoute(path: exploreRoute, builder: (_, __) => const ExploreScreen()),
    GoRoute(
        path: publicListingRoute,
        builder: (_, state) =>
            ListingDetailScreen(id: state.pathParameters['id']!)),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    sessionControllerProvider.overrideWith(ChatTestSession.new),
    publicListingsRepositoryProvider.overrideWithValue(repository),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
}

void main() {
  test('public routes are accessible while management routes remain protected',
      () {
    const state = SessionState.unauthenticated();
    for (final route in [
      exploreRoute,
      publicListingPath('l1'),
      seekerAccountRoute
    ]) {
      expect(authRedirect(state: state, location: route), isNull);
    }
    for (final route in [
      landlordListingsRoute,
      adminListingsRoute,
      tenantPortalRoute
    ]) {
      expect(authRedirect(state: state, location: route), loginRoute);
    }
    expect(homeRouteForSession(chatSession('s', role: 'tenant')), exploreRoute);
    expect(
        authRedirect(
            state: const SessionState.checking(),
            location: publicListingPath('l1')),
        '/splash?next=%2Fexplore%2Flistings%2Fl1');
    expect(isPublicDiscoveryLocation('https://example.com'), isFalse);
  });

  testWidgets('browse, search and detail use actual repository data',
      (tester) async {
    final repository = FakeListingsRepository();
    await showExplore(tester, repository);
    expect(find.text('Phòng có ban công'), findsOneWidget);
    await tester.ensureVisible(find.text('Phòng có ban công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phòng có ban công'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết phòng'), findsOneWidget);
    expect(find.text('Chi phí rõ ràng'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'không có');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.queries.last.search, 'không có');
    expect(find.text('Chưa có phòng phù hợp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters validate price range and reset pagination',
      (tester) async {
    final repository = FakeListingsRepository();
    await showExplore(tester, repository);
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '3000000');
    await tester.enterText(fields.at(3), '1000000');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Giá tối đa nhỏ hơn giá tối thiểu'), findsOneWidget);
    await tester.enterText(fields.at(3), '4000000');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.minPrice, 3000000);
    expect(repository.queries.last.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network errors have a working retry', (tester) async {
    final repository = FakeListingsRepository()..fail = true;
    await showExplore(tester, repository);
    expect(find.text('Mất kết nối'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng có ban công'), findsOneWidget);
  });

  testWidgets('small screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(ChatTestSession.new),
          publicListingsRepositoryProvider
              .overrideWithValue(FakeListingsRepository()),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const ExploreScreen())));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final screenWidth in [320.0, 393.0, 600.0]) {
    testWidgets('explore displays two columns at width $screenWidth',
        (tester) async {
      tester.view.physicalSize = Size(screenWidth, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeListingsRepository()
        ..browseItems = List.generate(
          4,
          (index) => RoomListing.fromJson({
            ...listingJson,
            'id': 'room-$index',
            'title': 'Studio ban công rộng đầy đủ nội thất số $index',
          }),
        );
      await showExplore(tester, repository);

      final cards = find.byType(ListingCard);
      expect(cards, findsNWidgets(4));
      final first = tester.getRect(cards.at(0));
      final second = tester.getRect(cards.at(1));
      final third = tester.getRect(cards.at(2));
      final fourth = tester.getRect(cards.at(3));
      expect(first.top, second.top);
      expect(first.width, closeTo(second.width, 0.01));
      expect(second.left - first.right, closeTo(12, 0.01));
      expect(third.top, fourth.top);
      expect(third.top, greaterThan(first.bottom));
      expect(first.left, third.left);
      expect(second.left, fourth.left);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'missing rental profile shows onboarding instead of a broken dashboard',
      (tester) async {
    var invoiceCalls = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      tenantPortalProfileProvider.overrideWith((ref) => throw const ApiFailure(
          code: 'TENANT_PROFILE_NOT_FOUND',
          message: 'Missing',
          statusCode: 404)),
      tenantPortalInvoicesProvider.overrideWith((ref) async {
        invoiceCalls++;
        return [];
      }),
    ], child: const MaterialApp(home: TenantHomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa liên kết phòng thuê'), findsOneWidget);
    expect(invoiceCalls, 0);
  });

  testWidgets('portal server errors are not mistaken for having no room',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      tenantPortalProfileProvider.overrideWith((ref) =>
          throw const ApiFailure(message: 'Server error', statusCode: 500)),
    ], child: const MaterialApp(home: TenantHomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được phòng của bạn'), findsOneWidget);
    expect(find.text('Bạn chưa liên kết phòng thuê'), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('management hides content when the account changes',
      (tester) async {
    final repository = FakeListingsRepository();
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      managedListingsRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ManageListingsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Phòng có ban công'), findsOneWidget);
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('other'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng có ban công'), findsNothing);
    expect(find.text('Phiên quản lý đã thay đổi'), findsOneWidget);
  });

  testWidgets(
      'editing a valid draft saves the original version without changing the room',
      (tester) async {
    final repository = FakeListingsRepository();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(ChatTestSession.new),
          managedListingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ListingFormScreen(
                                        listing: RoomListing.fromJson({
                                      ...listingJson,
                                      'roomId': 'r1',
                                      'version': 7,
                                      'imageUrls': [
                                        'https://example.com/public-room.jpg'
                                      ]
                                    })))),
                        child: const Text('Mở form')))))));
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu bản nháp'), 500,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(repository.savedId, 'l1');
    expect(repository.saved!['version'], 7);
    expect(repository.saved, isNot(contains('roomId')));
    expect(find.text('Mở form'), findsOneWidget);
  });

  testWidgets('admin rejects a listing only after providing a reason',
      (tester) async {
    final repository = FakeListingsRepository();
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionControllerProvider.overrideWith(AdminListingsSession.new),
      managedListingsRepositoryProvider.overrideWithValue(repository),
    ], child: const MaterialApp(home: ManageListingsScreen(admin: true))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Từ chối'), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Cần nhập lý do'), findsOneWidget);
    expect(repository.lastAction, isNull);
    await tester.enterText(find.byType(TextFormField), 'Cần ảnh rõ hơn');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.lastAction, 'REJECT');
    expect(repository.reviewNote, 'Cần ảnh rõ hơn');
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft form rejects missing images before making a request',
      (tester) async {
    final repository = FakeListingsRepository();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(ChatTestSession.new),
          managedListingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
            home: ListingFormScreen(
                listing: RoomListing.fromJson(
                    {...listingJson, 'roomId': 'r1', 'version': 7})))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lưu bản nháp'), 500,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Lưu bản nháp'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.text('Vui lòng nhập thông tin'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
