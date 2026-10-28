import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_screen.dart';
import 'package:rental_room_management/features/chatbot/chatbot_providers.dart';
import 'package:rental_room_management/features/chatbot/chatbot_screen.dart';
import 'package:rental_room_management/features/chatbot/widgets/chatbot_launcher.dart';
import 'package:rental_room_management/features/dashboard/dashboard_providers.dart';
import 'package:rental_room_management/features/dashboard/dashboard_screen.dart';
import 'package:rental_room_management/features/operations/operations_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';
import 'package:rental_room_management/features/rooms/rooms_list_screen.dart';
import 'package:rental_room_management/models/dashboard.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/landlord_notification.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';

import '../chatbot/chatbot_test_support.dart';

const _properties = [
  Property(id: 'p1', name: 'Khu trọ An Bình', address: '12 Nguyễn Trãi'),
  Property(id: 'p2', name: 'Khu trọ Bình An', address: '24 Lê Lợi'),
];

class _DashboardSession extends ChatTestSession {
  _DashboardSession(this.role);

  final String role;

  @override
  SessionState build() =>
      SessionState.authenticated(chatSession('dashboard', role: role));
}

Future<GoRouter> _showDashboard(
  WidgetTester tester, {
  String role = 'landlord',
  String? selectedPropertyId = 'p1',
  List<Property> properties = _properties,
  double textScale = 1,
  List<DashboardAttentionItem> attentionItems = const [],
  List<Invoice> invoices = const [],
}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: chatbotRoute, builder: (_, __) => const ChatbotScreen()),
    GoRoute(
        path: billingRoute,
        builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Hóa đơn')),
            body: BillingScreen(
                initialFilter: state.uri.queryParameters['filter']))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      actionItemsProvider
          .overrideWith((ref, query) async => ActionItems.fromJson({
                'data': {'summary': {}, 'items': [], 'categories': []},
                'meta': {'total': 0, 'page': 1, 'limit': query.limit},
              })),
      sessionControllerProvider.overrideWith(() => _DashboardSession(role)),
      selectedPropertyProvider.overrideWith((ref) => selectedPropertyId),
      propertiesProvider.overrideWith((ref) async => properties),
      dashboardMetricsProvider.overrideWith((ref) async => DashboardMetrics(
            propertyId: 'p1',
            generatedAt: DateTime.utc(2026, 10, 22),
            roomStats: const DashboardRoomStats(
                total: 0,
                occupied: 0,
                vacant: 0,
                maintenance: 0,
                occupancyRate: 0),
            leaseStats: const DashboardLeaseStats(active: 0),
            currentMonth: const DashboardCurrentMonth(
                invoiceCount: 0,
                billedAmount: 0,
                receivedAmount: 0,
                outstandingInvoiceCount: 0,
                outstandingAmount: 0),
            revenueTrend: const [],
            attentionItems: attentionItems,
            recentInvoices: const [],
          )),
      roomsProvider.overrideWith((ref, propertyId) async => const <Room>[]),
      invoicesProvider.overrideWith((ref) async => invoices),
      billingRemindersProvider.overrideWith((ref) async => const []),
      pendingPaymentProofsProvider.overrideWith((ref) async => const []),
      chatbotRepositoryProvider.overrideWithValue(ChatTestRepository()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('overdue attention opens the existing filtered invoice list',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _showDashboard(tester, attentionItems: const [
      DashboardAttentionItem(
          kind: DashboardAttentionKind.overdueInvoice,
          roomId: 'room-1',
          roomName: 'A01'),
    ]);
    final entry = find.text('Xem hóa đơn trễ hạn');
    await tester.scrollUntilVisible(entry, 400,
        scrollable: find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            widget.axisDirection == AxisDirection.down));
    await tester.pumpAndSettle();
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    expect(entry.hitTestable(), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
        tester.widget<BillingScreen>(find.byType(BillingScreen)).initialFilter,
        'overdue');
    expect(
        GoRouterState.of(tester.element(find.byType(BillingScreen)))
            .uri
            .toString(),
        '$billingRoute?filter=overdue');
    expect(tester.takeException(), isNull);
  });

  group('Floating dashboard navigation', () {
    testWidgets('hold and scrub previews a tab then commits on release',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _showDashboard(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tổng quan')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(find.text('Phòng')));
      await tester.pump();
      expect(find.byType(RoomsListScreen), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(RoomsListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('content reaches the end without moving the navigation',
        (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await _showDashboard(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final navigation = find.byWidget(scaffold.bottomNavigationBar!);
      final navigationRect = tester.getRect(navigation);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down),
        ),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final lastContent = find.text('Chưa có hóa đơn nào.').last;
      expect(lastContent.hitTestable(), findsOneWidget);
      expect(tester.getRect(lastContent).bottom, lessThan(navigationRect.top));
      expect(tester.getRect(navigation), navigationRect);
      final scrollOffset = scrollable.position.pixels;

      await tester.tap(find.descendant(
          of: find.byType(LiquidBubbleNavigation),
          matching: find.text('Phòng')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();
      final restored = tester.state<ScrollableState>(find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)));
      expect(restored.position.pixels, scrollOffset);
      expect(lastContent.hitTestable(), findsOneWidget);
      final currentNavigation = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .bottomNavigationBar!;
      expect(tester.getRect(find.byWidget(currentNavigation)), navigationRect);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      for (final bottomInset in [0.0, 34.0]) {
        testWidgets('pill fits width $width with inset $bottomInset',
            (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(bottom: bottomInset);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          await _showDashboard(tester);

          final bottomNavigation = tester
              .widget<Scaffold>(find.byType(Scaffold).first)
              .bottomNavigationBar!;
          tester.view.physicalSize = Size(width, 844);
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: bottomNavigation,
            ),
          ));
          await tester.pumpAndSettle();
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
          final navigation = find.byWidget(scaffold.bottomNavigationBar!);
          final pill = find.descendant(
              of: navigation, matching: find.byType(LiquidBubbleNavigation));
          final pillRect = tester.getRect(pill);
          expect(pillRect.left, 28);
          expect(pillRect.right, width - 28);
          expect(pillRect.height, 72);
          expect(pillRect.bottom, 844 - bottomInset - 16);
          expect(tester.widget<LiquidBubbleNavigation>(pill).backgroundColor,
              Colors.white);

          for (final label in ['Tổng quan', 'Phòng', 'Hóa đơn', 'Thêm']) {
            final tab = find.descendant(
              of: navigation,
              matching: find.text(label),
            );
            expect(tab, findsOneWidget);
            final target =
                find.ancestor(of: tab, matching: find.byType(InkWell));
            expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          }
          final addIcon = find.descendant(
            of: navigation,
            matching: find.byIcon(Icons.add_rounded),
          );
          final addButton = find.ancestor(
            of: addIcon,
            matching: find.byWidgetPredicate(
                (widget) => widget is GestureDetector && widget.onTap != null),
          );
          final addRect = tester.getRect(addButton);
          expect(addRect.center, pillRect.center);
          expect(pillRect.contains(addRect.topLeft), isTrue);
          expect(pillRect.contains(addRect.bottomRight), isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('navigation fits large text and landscape safe areas',
        (tester) async {
      await _showDashboard(tester);
      final navigation = tester
          .widget<Scaffold>(find.byType(Scaffold).first)
          .bottomNavigationBar!;
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      tester.view.padding =
          const FakeViewPadding(left: 44, right: 44, bottom: 21);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(bottomNavigationBar: navigation),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Tổng quan')).left,
          greaterThanOrEqualTo(44 + 28));
      expect(tester.getRect(find.text('Thêm')).right,
          lessThanOrEqualTo(844 - 44 - 28));

      tester.view.physicalSize = const Size(320, 700);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tổng quan'), findsOneWidget);
    });

    testWidgets('tabs and center action keep their existing callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _showDashboard(tester, properties: const []);

      Finder navigationItem(Finder matching) {
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        return find.descendant(
          of: find.byWidget(scaffold.bottomNavigationBar!),
          matching: matching,
        );
      }

      await tester.tap(navigationItem(find.text('Phòng')));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
          tester
              .widget<Text>(navigationItem(find.text('Phòng')))
              .style!
              .fontWeight,
          FontWeight.w700);
      await tester.tap(navigationItem(find.text('Tổng quan')));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsListScreen), findsNothing);
      expect(tester.widget<Text>(find.text('Tổng quan')).style!.fontWeight,
          FontWeight.w700);

      await tester.tap(navigationItem(find.byIcon(Icons.add_rounded)));
      await tester.pumpAndSettle();
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Add New Room'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Quick Actions'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(navigationItem(find.byIcon(Icons.menu_rounded)));
      await tester.pumpAndSettle();
      expect(find.text('Management Menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AI button stays at bottom right above dashboard navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _showDashboard(tester);

    final button = find.byType(FloatingActionButton);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final buttonRect = tester.getRect(button);
    final navigationRect =
        tester.getRect(find.byWidget(scaffold.bottomNavigationBar!));
    expect(find.byTooltip('Hỏi trợ lý AI'), findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsOneWidget,
    );
    expect(buttonRect.right, closeTo(374, 1));
    expect(buttonRect.bottom, lessThan(navigationRect.top));
    expect(buttonRect.height, greaterThanOrEqualTo(48));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(tester.getRect(button), buttonRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI button opens chat for the currently selected property',
      (tester) async {
    await _showDashboard(tester, selectedPropertyId: 'p2');
    await tester.tap(find.byTooltip('Hỏi trợ lý AI'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatbotScreen), findsOneWidget);
    expect(find.text('Phạm vi: Khu trọ Bình An'), findsOneWidget);
  });

  for (final selectedId in <String?>[null, 'missing-property']) {
    testWidgets(
        'AI button uses the displayed property for selection $selectedId',
        (tester) async {
      await _showDashboard(tester, selectedPropertyId: selectedId);
      await tester.tap(find.byTooltip('Hỏi trợ lý AI'));
      await tester.pumpAndSettle();
      expect(find.text('Phạm vi: Khu trọ An Bình'), findsOneWidget);
    });
  }

  testWidgets('AI button opens general guidance when there are no properties',
      (tester) async {
    await _showDashboard(tester, properties: const []);
    await tester.tap(find.byTooltip('Hỏi trợ lý AI'));
    await tester.pumpAndSettle();
    expect(find.text('Phạm vi: Hướng dẫn chung'), findsOneWidget);
  });

  for (final role in ['staff', 'tenant']) {
    testWidgets('AI button is hidden for $role accounts', (tester) async {
      await _showDashboard(tester, role: role);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Hỏi trợ lý AI'), findsNothing);
    });
  }

  testWidgets('AI launcher fits a small screen with large text and is tappable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        floatingActionButton: ChatbotLauncher(onPressed: () => opened = true),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Hỏi trợ lý AI'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
