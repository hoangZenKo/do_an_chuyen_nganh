import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/campus_management_screen.dart';
import 'package:rental_room_management/features/listings/discovery_tools.dart';
import 'package:rental_room_management/features/listings/saved_searches_screen.dart';
import 'package:rental_room_management/models/room_listing.dart';
import 'package:rental_room_management/models/student_discovery.dart';
import '../../data/listings/listings_api_test.dart'
    show RecordingListingsAdapter, listingJson;
import '../chatbot/chatbot_test_support.dart';
import 'listings_screen_test.dart' show FakeListingsRepository, showExplore;

class FakeDiscoveryTools extends DiscoveryToolsApi {
  FakeDiscoveryTools() : super(Dio());
  final changes = <String>[];
  @override
  Future<List<Map<String, dynamic>>> searches() async => [
        {
          'id': 's1',
          'name': 'Gần trường',
          'enabled': true,
          'filters': {
            'maxBudget': 4000000,
            'electricityKwh': 60,
            'freshOnly': true
          }
        },
      ];
  @override
  Future<Map<String, dynamic>> alerts(int page) async => {
        'data': <Object>[],
        'meta': {'unread': 0, 'total': 0}
      };
  @override
  Future<void> status(String id, bool enabled) async {
    changes.add('$id:$enabled');
  }

  @override
  Future<void> remove(String id) async {
    changes.add('delete:$id');
  }

  @override
  Future<List<SchoolCampus>> campuses() async => [
        const SchoolCampus(
            id: 'c1',
            name: 'Trường thử nghiệm',
            campus: 'Cơ sở chính',
            city: 'Hà Nội',
            address: 'Địa chỉ thử nghiệm',
            latitude: 21,
            longitude: 105)
      ];
  Map<String, dynamic>? savedCampus;
  @override
  Future<void> campus(Map<String, dynamic> data, String? id) async {
    savedCampus = data;
  }
}

void main() {
  test(
      'budget, usage and freshness survive serialization, pagination and provider equality',
      () {
    const query = ListingQuery(
        maxBudget: 4000000, electricityKwh: 60, waterM3: 4, freshOnly: true);
    final filters = query.toQuery()
      ..remove('page')
      ..remove('limit');
    expect(ListingQuery.fromJson(filters), query);
    expect(query.atPage(3).toQuery(), containsPair('maxBudget', 4000000));
    expect(query.atPage(3).electricityKwh, 60);
    expect(query, isNot(const ListingQuery(maxBudget: 4000000)));
    final listing =
        RoomListing.fromJson({...listingJson, 'estimatedMonthlyCost': 3200000});
    expect(listing.estimatedMonthlyCost, 3200000);
    expect(listing.availabilityFresh, isFalse);
    expect(
        RoomListing.fromJson({
          ...listingJson,
          'availabilityConfirmedAt': DateTime.now().toIso8601String()
        }).availabilityFresh,
        isTrue);
  });
  test(
      'save search excludes paging and keeps budget assumptions in API payload',
      () async {
    final adapter = RecordingListingsAdapter({
      'data': {'id': 's1'}
    }, status: 201);
    final api = DiscoveryToolsApi(
        Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
          ..httpClientAdapter = adapter);
    await api.save('My budget',
        const ListingQuery(maxBudget: 3500000, electricityKwh: 70, page: 3));
    expect(adapter.request.path, '/student/searches');
    final data = adapter.request.data as Map;
    expect(data['filters'], containsPair('electricityKwh', 70));
    expect((data['filters'] as Map).containsKey('page'), isFalse);
    expect((data['filters'] as Map).containsKey('limit'), isFalse);
  });
  testWidgets('budget filter survives searching and changing categories',
      (tester) async {
    final repository = FakeListingsRepository();
    await showExplore(tester, repository);
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    final budget =
        find.widgetWithText(TextFormField, 'Tổng ngân sách tối đa (đ/tháng)');
    await tester.ensureVisible(budget);
    await tester.enterText(budget, '3500000');
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.maxBudget, 3500000);
    await tester.enterText(find.byType(TextField).first, 'ban công');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.queries.last.maxBudget, 3500000);
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.maxBudget, 3500000);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'saved searches can pause and delete; alerts show an honest empty state',
      (tester) async {
    final api = FakeDiscoveryTools();
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      discoveryToolsProvider.overrideWithValue(api)
    ]);
    addTearDown(container.dispose);
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('student', role: 'tenant'));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SavedSearchesScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Gần trường'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(api.changes, contains('s1:false'));
    await tester.tap(find.byTooltip('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    expect(api.changes, contains('delete:s1'));
    await tester.tap(find.text('Tin mới phù hợp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có tin mới phù hợp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'campus form saves real coordinates and active state without invented verification',
      (tester) async {
    final api = FakeDiscoveryTools();
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      discoveryToolsProvider.overrideWithValue(api)
    ]);
    addTearDown(container.dispose);
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('admin', role: 'admin'));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CampusManagementScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trường thử nghiệm · Cơ sở chính'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Vĩ độ'), '21.1');
    final button = find.text('Lưu cơ sở');
    await tester.scrollUntilVisible(button, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.savedCampus?['latitude'], 21.1);
    expect(api.savedCampus?['isActive'], isTrue);
    expect(api.savedCampus?.containsKey('isDemo'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
