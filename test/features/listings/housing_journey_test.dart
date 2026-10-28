import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/housing_repository.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/handover_screen.dart';
import 'package:rental_room_management/features/listings/housing_dialog.dart';
import 'package:rental_room_management/features/listings/housing_providers.dart';
import 'package:rental_room_management/features/listings/viewing_slots_screen.dart';
import 'package:rental_room_management/models/housing.dart';
import 'package:rental_room_management/models/tenant_portal.dart';
import '../chatbot/chatbot_test_support.dart';

class JourneyRepository extends HousingRepository {
  JourneyRepository() : super(Dio());
  ViewingAvailability availability =
      const ViewingAvailability(required: true, slots: []);
  bool fail = false;
  int saves = 0, accepts = 0;
  Completer<void>? pending;
  List<Object>? saved;
  LeaseHandover? record;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 1));
  @override
  Future<ViewingAvailability> slots(String listingId) async => availability;
  @override
  Future<HandoverDetail> handover(String leaseId) async {
    if (fail) throw const ApiFailure(message: 'Mất kết nối, hãy thử lại.');
    return HandoverDetail(
        leaseId: leaseId,
        roomName: 'A101',
        propertyName: 'Khu trọ sinh viên',
        active: true,
        startDate: startDate,
        handover: record,
        deposit: const {
          'agreed': 2000000,
          'collected': 1000000,
          'refunded': 200000,
          'deducted': 100000,
          'adjustment': 0,
          'balance': 700000
        });
  }

  @override
  Future<void> saveHandover(String leaseId, int version, int electricity,
      int water, String condition, List<String> images) async {
    saves++;
    saved = [version, electricity, water, condition, images];
    record = LeaseHandover(
        version: version + 1,
        electricity: electricity,
        water: water,
        condition: condition,
        images: images);
  }

  @override
  Future<void> acceptHandover(String leaseId, int version) async {
    accepts++;
    await pending?.future;
    record = LeaseHandover(
        version: version + 1,
        electricity: record!.electricity,
        water: record!.water,
        condition: record!.condition,
        images: record!.images,
        acceptedAt: DateTime.now());
  }
}

void main() {
  late ProviderContainer container;
  late JourneyRepository repository;
  setUp(() {
    repository = JourneyRepository();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      housingRepositoryProvider.overrideWithValue(repository)
    ]);
  });
  tearDown(() => container.dispose());
  Future<void> show(WidgetTester tester, Widget widget,
      {String role = 'landlord', double scale = 1}) async {
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('a', role: role));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: widget)));
    await tester.pumpAndSettle();
  }

  const draft = LeaseHandover(
      version: 1,
      electricity: 1234,
      water: 89,
      condition: 'Phòng sạch, cửa có vết xước cũ.',
      images: []);

  testWidgets('slot-only bookings cannot silently fall back to free-form dates',
      (tester) async {
    var writes = 0;
    await show(
        tester,
        HousingDialog(
            title: 'Đặt lịch',
            form: HousingForm.booking,
            accountId: 'a',
            listingId: 'l1',
            onSubmit: (_) async {
              writes++;
            }),
        role: 'tenant');
    expect(find.textContaining('Chưa có khung giờ trống'), findsOneWidget);
    expect(find.byIcon(Icons.event_outlined), findsNothing);
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(writes, 0);
  });

  testWidgets(
      'choosing an opening submits its exact instant and slot identifier',
      (tester) async {
    final start = DateTime.now().add(const Duration(days: 2));
    repository.availability = ViewingAvailability(required: true, slots: [
      ViewingSlot(
          id: 's1',
          startsAt: start,
          endsAt: start.add(const Duration(minutes: 30)),
          available: true)
    ]);
    HousingFormValue? submitted;
    await show(
        tester,
        HousingDialog(
            title: 'Đặt lịch',
            form: HousingForm.booking,
            accountId: 'a',
            listingId: 'l1',
            onSubmit: (value) async {
              submitted = value;
            }),
        role: 'tenant');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(' – ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(submitted?.slotId, 's1');
    expect(submitted?.date, start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancellation requires an explicit reason in the interface',
      (tester) async {
    var writes = 0;
    await show(
        tester,
        HousingDialog(
            title: 'Hủy lịch',
            form: HousingForm.viewingAction,
            accountId: 'a',
            requireNote: true,
            onSubmit: (_) async {
              writes++;
            }));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.textContaining('Nhập lý do'), findsOneWidget);
  });

  testWidgets(
      'landlord saves validated initial readings and condition, not a synthetic payment',
      (tester) async {
    await show(tester, const HandoverScreen(leaseId: 'lease-1'));
    await tester.enterText(find.byType(TextFormField).at(0), '1234');
    await tester.enterText(find.byType(TextFormField).at(1), '89');
    await tester.enterText(find.byType(TextFormField).at(2), draft.condition);
    await tester.ensureVisible(find.text('Lưu biên bản bàn giao'));
    await tester.tap(find.text('Lưu biên bản bàn giao'));
    await tester.pumpAndSettle();
    expect(repository.saves, 1);
    expect(repository.saved, [0, 1234, 89, draft.condition, <String>[]]);
    await tester.drag(find.byType(ListView), const Offset(0, 1600));
    await tester.pumpAndSettle();
    expect(find.text('Chờ người thuê kiểm tra và xác nhận'), findsOneWidget);
    expect(repository.accepts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant explicitly acknowledges move-in and cannot double-submit',
      (tester) async {
    repository.record = draft;
    repository.pending = Completer<void>();
    await show(tester, const HandoverScreen(leaseId: 'lease-1'),
        role: 'tenant');
    final button = find.widgetWithText(FilledButton, 'Xác nhận đã nhận phòng');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(repository.accepts, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã xác nhận nhận phòng'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets(
      'future leases cannot be accepted and offline handovers offer a retry',
      (tester) async {
    repository.record = draft;
    repository.startDate = DateTime.now().add(const Duration(days: 3));
    repository.fail = true;
    await show(tester, const HandoverScreen(leaseId: 'lease-1'),
        role: 'tenant');
    expect(find.text('Mất kết nối, hãy thử lại.'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull);
    expect(find.textContaining('Có thể xác nhận từ ngày'), findsOneWidget);
  });

  testWidgets(
      'handover and availability screens fit narrow devices with large text',
      (tester) async {
    repository.record = draft;
    await show(tester, const HandoverScreen(leaseId: 'lease-1'),
        role: 'tenant', scale: 1.8);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await show(tester, const ViewingSlotsScreen(listingId: 'l1'), scale: 1.8);
    expect(find.text('Mở khung 30 phút'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('lease occupancy does not claim move-in before handover acknowledgement',
      () {
    final pending = TenantPortalLease.fromJson(
        {'id': 'lease-1', 'status': 'active', 'requiresHandover': true});
    final moved = TenantPortalLease.fromJson({
      'id': 'lease-1',
      'status': 'active',
      'requiresHandover': true,
      'handedOverAt': DateTime.now().toUtc().toIso8601String()
    });
    expect(pending.occupancyLabel, 'Chờ bàn giao');
    expect(moved.occupancyLabel, 'Đang thuê');
  });
}
