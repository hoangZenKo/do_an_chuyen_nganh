import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/listing_comparison_screen.dart';
import 'package:rental_room_management/features/listings/listing_report_dialog.dart';
import 'package:rental_room_management/features/listings/listings_providers.dart';
import 'package:rental_room_management/features/listings/student_listing_widgets.dart';
import 'package:rental_room_management/models/room_listing.dart';
import 'package:rental_room_management/models/student_discovery.dart';
import '../../data/listings/listings_api_test.dart' show listingJson;
import '../chatbot/chatbot_test_support.dart';
import 'listings_screen_test.dart' show FakeListingsRepository, showExplore;

class StudentRepository extends FakeListingsRepository {
  Map<String, String>? reported;
  @override
  Future<List<SchoolCampus>> campuses() async => [
        const SchoolCampus(
            id: 'campus-1',
            name: 'Trường thử nghiệm',
            campus: 'Cơ sở A',
            city: 'Hà Nội',
            isDemo: true)
      ];
  @override
  Future<RoomListing> detail(String id) async {
    if (id == 'gone') {
      throw const ApiFailure(message: 'Tin đã ẩn', statusCode: 404);
    }
    return RoomListing.fromJson(
        {...listingJson, 'id': id, 'title': 'Phòng $id'});
  }

  @override
  Future<void> report(String id,
      {required String reason, required String detail}) async {
    reported = {'id': id, 'reason': reason, 'detail': detail};
  }
}

void main() {
  test(
      'cost estimate accounts for all declared fees and shares without losing money',
      () {
    final listing =
        RoomListing.fromJson({...listingJson, 'parkingFee': 100000});
    const estimate =
        LivingCostEstimate(electricityKwh: 50, waterM3: 3, people: 3);
    expect(estimate.monthly(listing), 2920000);
    expect(estimate.perPerson(listing), 973334);
    expect(estimate.moveIn(listing), 5420000);
  });

  test('campus filters survive pagination and participate in provider identity',
      () {
    const query = ListingQuery(campusId: 'campus-1', radiusKm: 3);
    expect(query.atPage(2).toQuery(), containsPair('campusId', 'campus-1'));
    expect(query.atPage(2).toQuery(), containsPair('radiusKm', 3));
    expect(query, isNot(const ListingQuery(campusId: 'campus-1', radiusKm: 5)));
    expect(const ListingQuery(radiusKm: 3).toQuery().containsKey('radiusKm'),
        isFalse);
  });

  test(
      'legacy listings do not fabricate verification, coordinates or parking charges',
      () {
    final listing = RoomListing.fromJson(listingJson);
    expect(listing.landlordVerifiedAt, isNull);
    expect(listing.inspectedAt, isNull);
    expect(listing.availabilityConfirmedAt, isNull);
    expect(listing.latitude, isNull);
    expect(listing.parkingFee, 0);
  });

  test(
      'comparison rejects fourth room, toggles by id and clears on account change',
      () {
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new)
    ]);
    addTearDown(container.dispose);
    final comparison = container.read(listingComparisonProvider.notifier);
    final rooms = List.generate(4,
        (index) => RoomListing.fromJson({...listingJson, 'id': 'room-$index'}));
    for (final room in rooms.take(3)) {
      expect(comparison.toggle(room), isTrue);
    }
    expect(comparison.toggle(rooms[3]), isFalse);
    expect(container.read(listingComparisonProvider), hasLength(3));
    expect(comparison.toggle(rooms.first), isTrue);
    expect(container.read(listingComparisonProvider), hasLength(2));
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('different'));
    expect(container.read(listingComparisonProvider), isEmpty);
  });

  testWidgets('school and radius choices reach the repository', (tester) async {
    final repository = StudentRepository();
    await showExplore(tester, repository);
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Không lọc theo trường'));
    await tester.tap(find.text('Không lọc theo trường'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trường thử nghiệm · Cơ sở A (mẫu)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.campusId, 'campus-1');
    expect(repository.queries.last.radiusKm, 5);
    expect(find.textContaining('đường chim bay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cost calculator rejects zero people and recovers after valid input',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ListingCostPanel(
                    listing: RoomListing.fromJson(listingJson))))));
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.pumpAndSettle();
    expect(find.text('Nhập số hợp lệ'), findsOneWidget);
    expect(find.text('Tổng dự kiến / tháng'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(2), '2');
    await tester.pumpAndSettle();
    expect(find.text('Tổng dự kiến / tháng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison hides estimates for withdrawn listings',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      publicListingsRepositoryProvider.overrideWithValue(StudentRepository()),
    ]);
    addTearDown(container.dispose);
    final comparison = container.read(listingComparisonProvider.notifier);
    comparison.toggle(RoomListing.fromJson({...listingJson, 'id': 'live'}));
    comparison.toggle(RoomListing.fromJson({...listingJson, 'id': 'gone'}));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ListingComparisonScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.textContaining('Tin không còn hiển thị'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report dialog validates details and sends the selected reason',
      (tester) async {
    final repository = StudentRepository();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(ChatTestSession.new),
          managedListingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const ListingReportDialog(listingId: 'l1')),
                          child: const Text('Mở báo cáo'),
                        ))))));
    await tester.tap(find.text('Mở báo cáo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ít nhất 10 ký tự'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField), 'Giá thực tế cao hơn tin đăng.');
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();
    expect(repository.reported, {
      'id': 'l1',
      'reason': 'wrong_price',
      'detail': 'Giá thực tế cao hơn tin đăng.'
    });
    expect(tester.takeException(), isNull);
  });
}
