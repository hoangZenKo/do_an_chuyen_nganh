import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/operations/operations_api.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/operations/action_items_dashboard_card.dart';
import 'package:rental_room_management/features/operations/action_items_screen.dart';
import 'package:rental_room_management/features/operations/operations_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/landlord_notification.dart';
import 'package:rental_room_management/models/property.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
            id: 'owner',
            fullName: 'Owner',
            email: 'owner@test.com',
            role: 'landlord'),
        accessToken: 'test',
        refreshToken: 'test',
      ));
}

ActionItems _result(
    {int page = 1,
    int total = 25,
    List<String>? categories,
    bool empty = false}) {
  return ActionItems.fromJson({
    'data': {
      'summary': {
        'total': total,
        'unread': 9,
        'pendingViewings': 3,
        'overdueInvoices': 5,
        'dueSoonInvoices': 2,
        'pendingPaymentProofs': 6,
        'openMaintenance': 4,
        'urgentMaintenance': 1,
        'expiringLeases': 2,
        'dueInspections': 3
      },
      'categories': categories ??
          [
            'viewing',
            'invoice',
            'payment',
            'maintenance',
            'lease',
            'inspection'
          ],
      'items': empty
          ? []
          : [
              {
                'id': 'action-$page',
                'kind': 'viewing_pending',
                'category': 'viewing',
                'title': 'Lịch xem chờ xác nhận $page',
                'body': 'Sinh viên A · Phòng A101',
                'severity': 'warning',
                'isRead': false,
                'actionRoute': '/destination',
                'propertyName': 'Khu trọ An Bình',
                'dueAt': '2026-10-25T08:00:00.000Z',
              }
            ],
    },
    'meta': {'page': page, 'limit': 12, 'total': total},
  });
}

class _Api extends OperationsApi {
  _Api() : super(Dio());
  final queries = <ActionItemsQuery>[];
  final reads = <String>[];
  bool failRead = false;
  Future<ActionItems> Function(ActionItemsQuery query)? load;

  @override
  Future<ActionItems> actionItems(
      {int page = 1,
      int limit = 20,
      String category = 'all',
      String? propertyId}) {
    final query = ActionItemsQuery(
        page: page, limit: limit, category: category, propertyId: propertyId);
    queries.add(query);
    return load?.call(query) ?? Future.value(_result(page: page));
  }

  @override
  Future<void> markRead(String id) async {
    reads.add(id);
    if (failRead) throw Exception('offline');
  }
}

Future<void> _show(WidgetTester tester, _Api api,
    {double scale = 1, bool dashboard = false, String? propertyId}) async {
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => dashboard
            ? Scaffold(body: ActionItemsDashboardCard(propertyId: propertyId))
            : ActionItemsScreen(propertyId: propertyId)),
    GoRoute(
        path: '/destination',
        builder: (_, __) => const Scaffold(body: Text('Đích xử lý'))),
    GoRoute(
        path: '/actions',
        builder: (_, state) => Scaffold(
            body:
                Text('Danh sách ${state.uri.queryParameters['propertyId']}'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      operationsApiProvider.overrideWithValue(api),
      sessionControllerProvider.overrideWith(_Session.new),
      propertiesProvider.overrideWith((ref) async => const [
            Property(id: 'p1', name: 'Khu trọ Một', address: 'Test'),
            Property(id: 'p2', name: 'Khu trọ Hai', address: 'Test'),
          ]),
    ],
    child: MaterialApp.router(
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 260,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all group counts and working category filters',
      (tester) async {
    final api = _Api();
    await _show(tester, api);
    expect(find.text('Chứng từ chờ duyệt'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    await _reveal(tester, find.text('Hóa đơn  7'));
    await tester.tap(find.text('Hóa đơn  7'));
    await tester.pumpAndSettle();
    expect(api.queries.last.category, 'invoice');
    expect(api.queries.last.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks read, opens destination and refreshes after returning',
      (tester) async {
    final api = _Api();
    await _show(tester, api);
    await _reveal(tester, find.text('Lịch xem chờ xác nhận 1'));
    await tester.tap(find.text('Lịch xem chờ xác nhận 1'));
    await tester.pumpAndSettle();
    expect(api.reads, ['action-1']);
    expect(find.text('Đích xử lý'), findsOneWidget);
    final requests = api.queries.length;
    tester.element(find.text('Đích xử lý')).pop();
    await tester.pumpAndSettle();
    expect(api.queries.length, greaterThan(requests));
  });

  testWidgets('failed read does not block navigation', (tester) async {
    final api = _Api()..failRead = true;
    await _show(tester, api);
    await _reveal(tester, find.text('Lịch xem chờ xác nhận 1'));
    await tester.tap(find.text('Lịch xem chờ xác nhận 1'));
    await tester.pumpAndSettle();
    expect(find.text('Đích xử lý'), findsOneWidget);
  });

  testWidgets('pagination requests next page and resets on filter change',
      (tester) async {
    final api = _Api();
    await _show(tester, api);
    await _reveal(tester, find.byTooltip('Trang sau'));
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(api.queries.last.page, 2);
    await _reveal(tester, find.text('Hóa đơn  7'));
    await tester.tap(find.text('Hóa đơn  7'));
    await tester.pumpAndSettle();
    expect(api.queries.last.page, 1);
  });

  testWidgets('empty state and staff-visible categories are truthful',
      (tester) async {
    final api = _Api()
      ..load = (_) async =>
          _result(empty: true, total: 0, categories: ['maintenance']);
    await _show(tester, api);
    await _reveal(tester, find.text('Không có việc cần xử lý'));
    expect(find.text('Lịch xem  3'), findsNothing);
    expect(find.text('Sửa chữa  4'), findsOneWidget);
    expect(find.byTooltip('Trang sau'), findsNothing);
  });

  testWidgets('retry recovers from failed request', (tester) async {
    final api = _Api()..load = (_) async => throw Exception('Mất kết nối');
    await _show(tester, api);
    expect(find.text('Thử lại'), findsOneWidget);
    api.load = (_) async => _result();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chứng từ chờ duyệt'), findsOneWidget);
  });

  testWidgets('property filter changes request scope and keeps initial scope',
      (tester) async {
    final api = _Api();
    await _show(tester, api, propertyId: 'p1');
    expect(api.queries.last.propertyId, 'p1');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khu trọ Hai').last);
    await tester.pumpAndSettle();
    expect(api.queries.last.propertyId, 'p2');
  });

  testWidgets('small mobile with large text has no layout exception',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _show(tester, _Api(), scale: 1.6);
    await _reveal(tester, find.text('Lịch xem chờ xác nhận 1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dashboard previews live totals and opens property-scoped action center',
      (tester) async {
    final api = _Api();
    await _show(tester, api, dashboard: true, propertyId: 'p2');
    expect(api.queries.single.limit, 3);
    expect(api.queries.single.propertyId, 'p2');
    expect(find.text('25 việc · 9 chưa đọc'), findsOneWidget);
    await tester.tap(find.text('Việc cần xử lý'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách p2'), findsOneWidget);
  });
}
