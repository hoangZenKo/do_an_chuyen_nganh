import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/housing_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/housing_dialog.dart';
import 'package:rental_room_management/features/listings/housing_providers.dart';
import 'package:rental_room_management/features/listings/housing_screen.dart';
import 'package:rental_room_management/models/housing.dart';
import 'package:rental_room_management/models/tenant_portal.dart';
import '../chatbot/chatbot_test_support.dart';

class HousingTestRepository extends HousingRepository {
  HousingTestRepository() : super(Dio());
  int reads = 0;
  bool fail = false;
  bool enabled = false;
  String status = 'REQUESTED';
  final changes = <String>[];
  Future<HousingPage<SavedRoom>> Function()? loadSaved;
  @override
  Future<HousingPage<SavedRoom>> favorites(int page) {
    reads++;
    if (fail) throw const ApiFailure(message: 'Không có mạng');
    return loadSaved?.call() ??
        Future.value(HousingPage(items: [
          const SavedRoom(
              id: 'l1',
              title: 'Phòng đã lưu',
              address: 'Đường A',
              rent: 2500000,
              available: false)
        ], page: page, total: 1));
  }

  @override
  Future<HousingPage<RoomViewing>> viewings(int page) async =>
      HousingPage(items: [
        RoomViewing(
            id: 'v1',
            listingId: 'l1',
            title: 'Phòng có cửa sổ',
            studentName: 'Sinh viên A',
            landlordName: 'Chủ trọ A',
            address: 'Đường A',
            status: status,
            version: 1,
            scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
            rent: 2500000,
            deposit: 2000000)
      ], page: page, total: 1);
  @override
  Future<void> updateViewing(
      RoomViewing viewing, String next, String note) async {
    changes.add(next);
    status = next;
  }

  @override
  Future<RentalPilot> pilot() async =>
      RentalPilot(enabled: enabled, area: enabled ? 'Khu vực A' : '');
}

void main() {
  late ProviderContainer container;
  late HousingTestRepository repository;
  setUp(() {
    repository = HousingTestRepository();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      housingRepositoryProvider.overrideWithValue(repository)
    ]);
  });
  tearDown(() => container.dispose());
  Future<void> show(WidgetTester tester, Widget screen,
      {double scale = 1}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: screen)));
    await tester.pumpAndSettle();
  }

  test('housing routes require a compatible authenticated role', () {
    for (final route in [
      housingFavoritesRoute,
      housingViewingsRoute,
      housingNoticesRoute,
      rentalPilotRoute
    ]) {
      expect(
          authRedirect(
              state: const SessionState.unauthenticated(), location: route),
          loginRoute);
      expect(
          authRedirect(
              state:
                  SessionState.authenticated(chatSession('s', role: 'staff')),
              location: route),
          settingsRoute);
      expect(
          authRedirect(
              state:
                  SessionState.authenticated(chatSession('s', role: 'tenant')),
              location: route),
          isNull);
    }
    expect(
        authRedirect(
            state: SessionState.authenticated(chatSession('o')),
            location: housingFavoritesRoute),
        dashboardRoute);
    expect(
        authRedirect(
            state: SessionState.authenticated(chatSession('s', role: 'tenant')),
            location: pilotFeedbackRoute),
        exploreRoute);
  });
  test('login resumes a public listing but never an external redirect', () {
    final session =
        SessionState.authenticated(chatSession('s', role: 'tenant'));
    expect(
        authRedirect(
            state: session,
            location: loginRoute,
            next: publicListingPath('l1')),
        publicListingPath('l1'));
    expect(
        authRedirect(
            state: session, location: loginRoute, next: 'https://example.com'),
        exploreRoute);
    expect(authRedirect(state: session, location: loginRoute, next: '/admin'),
        exploreRoute);
  });
  test(
      'tenant lease history distinguishes agreed deposit from recorded balance',
      () {
    final lease = TenantPortalLease.fromJson({
      'deposit': 2000000,
      'depositBalance': 750000,
      'depositTransactions': [
        {
          'id': 'd1',
          'leaseId': 'lease-1',
          'type': 'collected',
          'amount': 1000000
        },
        {'id': 'd2', 'leaseId': 'lease-1', 'type': 'refunded', 'amount': 250000}
      ]
    });
    expect(lease.deposit, 2000000);
    expect(lease.depositBalance, 750000);
    expect(lease.depositTransactions.last.label, 'Hoàn cọc');
    expect(TenantPortalLease.fromJson({'deposit': 2000000}).depositBalance, 0);
  });
  testWidgets(
      'unavailable saved rooms remain removable and readable at large text',
      (tester) async {
    await show(tester, const HousingScreen(section: HousingSection.favorites),
        scale: 2);
    expect(find.text('Phòng đã lưu'), findsOneWidget);
    expect(find.textContaining('Tin đã ngừng nhận khách'), findsOneWidget);
    expect(find.byTooltip('Bỏ lưu phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed loads support retry', (tester) async {
    repository.fail = true;
    await show(tester, const HousingScreen(section: HousingSection.favorites));
    expect(find.text('Không có mạng'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng đã lưu'), findsOneWidget);
  });
  testWidgets('landlord confirms a viewing through the versioned action form',
      (tester) async {
    await show(tester, const HousingScreen(section: HousingSection.viewings));
    await tester.tap(find.text('Xác nhận lịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.changes, ['CONFIRMED']);
    expect(find.text('Đã xác nhận'), findsOneWidget);
  });
  testWidgets('tenant cannot confirm or create a lease', (tester) async {
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('s', role: 'tenant'));
    await show(tester, const HousingScreen(section: HousingSection.viewings));
    expect(find.text('Xác nhận lịch'), findsNothing);
    expect(find.text('Tạo hợp đồng'), findsNothing);
    expect(find.text('Hủy lịch'), findsOneWidget);
  });
  testWidgets('dialog blocks stale-account submissions', (tester) async {
    var writes = 0;
    await show(
        tester,
        HousingDialog(
            title: 'Test',
            form: HousingForm.feedback,
            accountId: 'a',
            onSubmit: (_) async {
              writes++;
            }));
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await tester.pumpAndSettle();
    expect(find.text('Phiên đăng nhập đã thay đổi'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
    expect(writes, 0);
  });
  testWidgets('closed pilot has no feedback submission', (tester) async {
    await show(tester, const RentalPilotScreen());
    expect(find.text('Chưa mở thử nghiệm thực tế'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Gửi phản hồi'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    expect(button.onPressed, isNull);
  });
  testWidgets(
      'feedback rejects empty detail and prevents duplicate submissions',
      (tester) async {
    final pending = Completer<void>();
    var submissions = 0;
    await show(
        tester,
        HousingDialog(
            title: 'Test feedback',
            form: HousingForm.feedback,
            accountId: 'a',
            onSubmit: (_) {
              submissions++;
              return pending.future;
            }));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ít nhất 10 ký tự.'), findsOneWidget);
    expect(submissions, 0);
    await tester.enterText(
        find.byType(TextFormField).last, 'Phản hồi thử nghiệm chi tiết.');
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    expect(find.text('Đang lưu…'), findsOneWidget);
    expect(submissions, 1);
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Phiên đăng nhập đã thay đổi'), findsOneWidget);
    expect(submissions, 1);
  });
  testWidgets('late account A response cannot overwrite account B favorites',
      (tester) async {
    container.dispose();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      housingRepositoryProvider.overrideWith((ref) {
        final id = ref.watch(sessionIdentityProvider);
        return id == 'a'
            ? repository
            : (HousingTestRepository()
              ..loadSaved =
                  () async => const HousingPage(items: [], page: 1, total: 0));
      })
    ]);
    final pending = Completer<HousingPage<SavedRoom>>();
    repository.loadSaved = () => pending.future;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: HousingScreen(section: HousingSection.favorites))));
    await tester.pump();
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await tester.pumpAndSettle();
    pending.complete(const HousingPage(items: [
      SavedRoom(
          id: 'private',
          title: 'Private A favorite',
          address: 'Road',
          rent: 1,
          available: true)
    ], page: 1, total: 1));
    await tester.pumpAndSettle();
    expect(find.text('Private A favorite'), findsNothing);
    expect(find.textContaining('Bạn chưa lưu phòng nào'), findsOneWidget);
  });
}
