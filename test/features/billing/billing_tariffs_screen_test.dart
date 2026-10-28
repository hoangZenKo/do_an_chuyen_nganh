import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_tariffs_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/billing_tariff.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';

AuthSession _session(String role,
        {String id = 'actor', List<String> permissions = const []}) =>
    AuthSession(
      user: LandlordUser(
          id: id,
          fullName: 'Test',
          email: 'test@example.test',
          role: role,
          permissions: permissions),
      accessToken: 'access',
      refreshToken: 'refresh',
    );

class _Session extends SessionController {
  _Session(this.initial);
  final AuthSession initial;
  @override
  SessionState build() => SessionState.authenticated(initial);
  void change(AuthSession next) => state = SessionState.authenticated(next);
}

BillingTariffVersion _version(
        {String id = 'tariff',
        String name = 'Internet',
        String state = 'PROPOSED'}) =>
    BillingTariffVersion(
      id: id,
      propertyId: 'property',
      serviceKey: 'internet',
      name: name,
      kind: 'SERVICE',
      unit: 'tháng',
      amount: 100000,
      isActive: true,
      effectiveFrom: DateTime.utc(2030, 1),
      version: 1,
      state: state,
      reason: 'New rate',
    );

class _Repository extends BillingRepository {
  _Repository() : super(BillingApi(Dio()));
  final proposals = <Map<String, dynamic>>[];
  final reviews = <Map<String, dynamic>>[];
  List<BillingTariffVersion> rows = [_version()];
  Object? failure;
  Object? readFailure;
  Completer<void>? pending;
  bool canApprove = true;
  int reads = 0;

  @override
  Future<List<BillingTariffVersion>> tariffs(String propertyId) async {
    reads++;
    if (readFailure != null) throw readFailure!;
    return rows;
  }

  @override
  Future<BillingTariffImpact> tariffImpact(String id) async =>
      BillingTariffImpact(
        proposed: rows.firstWhere((row) => row.id == id),
        rooms: const [BillingTariffRoomImpact(id: 'room', name: 'A101')],
        issuedInvoices: canApprove ? 0 : 1,
        lockedPeriods: 0,
        canApprove: canApprove,
        blockingReasons: canApprove ? [] : ['ISSUED_INVOICES'],
      );

  @override
  Future<BillingTariffVersion> proposeTariff({
    required String requestKey,
    required String propertyId,
    String? roomId,
    required String kind,
    required String serviceKey,
    required String name,
    required String unit,
    required int amount,
    required bool isActive,
    required String effectiveFrom,
    required List<Map<String, dynamic>> tiers,
    required String reason,
  }) async {
    proposals.add({
      'requestKey': requestKey,
      'propertyId': propertyId,
      'roomId': roomId,
      'kind': kind,
      'serviceKey': serviceKey,
      'name': name,
      'unit': unit,
      'amount': amount,
      'isActive': isActive,
      'effectiveFrom': effectiveFrom,
      'tiers': tiers,
      'reason': reason
    });
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    return rows.first;
  }

  @override
  Future<BillingTariffVersion> reviewTariff(
      {required String id,
      required String requestKey,
      required String decision,
      required String reason}) async {
    reviews.add({
      'id': id,
      'requestKey': requestKey,
      'decision': decision,
      'reason': reason
    });
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    rows = [_version(state: decision)];
    return rows.first;
  }
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Repository repository, {
  String role = 'landlord',
  List<String> permissions = const [],
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    sessionControllerProvider
        .overrideWith(() => _Session(_session(role, permissions: permissions))),
    billingRepositoryProvider.overrideWithValue(repository),
    selectedPropertyProvider.overrideWith((ref) => 'property'),
    propertiesProvider.overrideWith((ref) async => const [
          Property(id: 'property', name: 'Khu trọ An Bình', address: 'Hà Nội')
        ]),
    roomsProvider('property').overrideWith((ref) async => const [
          Room(
              id: 'room',
              propertyId: 'property',
              name: 'A101',
              status: RoomStatus.vacant)
        ]),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: const ValueKey('tariff-capture'),
      child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: const BillingTariffsScreen()),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _visible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder _filledButton(String label) => find.byWidgetPredicate((widget) =>
    widget is FilledButton &&
    find
        .descendant(of: find.byWidget(widget), matching: find.text(label))
        .evaluate()
        .isNotEmpty);

Finder _outlinedButton(String label) => find.byWidgetPredicate((widget) =>
    widget is OutlinedButton &&
    find
        .descendant(of: find.byWidget(widget), matching: find.text(label))
        .evaluate()
        .isNotEmpty);

Future<void> _fill(WidgetTester tester) async {
  await tester.tap(find.text('Tạo đề xuất biểu phí'));
  await tester.pumpAndSettle();
  for (final field in {
    'Mã biểu phí': 'internet',
    'Tên hiển thị': 'Internet',
    'Đơn vị': 'tháng',
    'Đơn giá': '150000',
    'Lý do thay đổi': 'Theo đơn giá nhà cung cấp'
  }.entries) {
    final finder = find.widgetWithText(TextFormField, field.key);
    await _visible(tester, finder);
    await tester.enterText(finder, field.value);
  }
  await _visible(tester, find.text('Gửi đề xuất'));
}

Future<void> _select(WidgetTester tester) async {
  final row = find.text('Internet · phiên bản 1').first;
  await _visible(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  await _visible(tester, find.text('Xem trước & phê duyệt'));
}

Future<void> _capture(WidgetTester tester, String filename) async {
  if (!const bool.fromEnvironment('TARIFF_CAPTURE')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('tariff-capture')));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('.impeccable/review')
      ..createSync(recursive: true);
    File('${directory.path}/$filename')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('TARIFF_CAPTURE')) {
      final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
      if (font.existsSync()) {
        for (final family in ['Roboto', 'Ahem']) {
          final loader = FontLoader(family)
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync())));
          await loader.load();
        }
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  test('tariff route requires billing view for staff', () {
    expect(
        authRedirect(
            state: SessionState.authenticated(
                _session('staff', permissions: ['billing.view'])),
            location: billingTariffsRoute),
        isNull);
    expect(
        authRedirect(
            state: SessionState.authenticated(
                _session('staff', permissions: ['billing.create'])),
            location: billingTariffsRoute),
        isNotNull);
    expect(
        authRedirect(
            state: SessionState.authenticated(_session('tenant')),
            location: billingTariffsRoute),
        isNotNull);
  });

  testWidgets(
      'staff can propose but cannot review even with approval permission',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository, role: 'staff', permissions: [
      'billing.view',
      'billing.create',
      'billing.tariff_approve'
    ]);
    expect(find.text('Tạo đề xuất biểu phí'), findsOneWidget);
    await _select(tester);
    expect(find.text('Duyệt áp dụng'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Từ chối'), findsNothing);
  });

  testWidgets('missing billing permission does not load tariffs',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository, role: 'tenant');
    expect(find.text('Không có quyền xem biểu phí'), findsOneWidget);
    expect(repository.reads, 0);
  });

  testWidgets('sends one complete proposal and disables repeated clicks',
      (tester) async {
    final repository = _Repository()..pending = Completer<void>();
    await _open(tester, repository);
    await _fill(tester);
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pump();
    expect(tester.widget<FilledButton>(_filledButton('Đang gửi…')).onPressed,
        isNull);
    expect(repository.proposals, hasLength(1));
    final proposal = repository.proposals.single;
    expect(proposal['propertyId'], 'property');
    expect(proposal['amount'], 150000);
    expect(proposal['tiers'], isEmpty);
    expect(proposal['requestKey'], matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect(proposal['effectiveFrom'], endsWith('-01T00:00:00.000Z'));
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi đề xuất biểu phí để duyệt.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unknown result blocks resubmit and refresh never replays mutation',
      (tester) async {
    final repository = _Repository()
      ..failure = const ApiFailure(message: 'Offline');
    await _open(tester, repository);
    await _fill(tester);
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('Tải lại để đối chiếu'));
    expect(repository.proposals, hasLength(1));
    await tester.tap(find.text('Tải lại để đối chiếu'));
    await tester.pumpAndSettle();
    expect(repository.proposals, hasLength(1));
    expect(repository.reads, greaterThan(1));
    await _visible(tester, find.text('Gửi đề xuất'));
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pumpAndSettle();
    expect(repository.proposals, hasLength(2));
    expect(repository.proposals.first['requestKey'],
        repository.proposals.last['requestKey']);
  });

  testWidgets('refresh error retains rows and blocks approval until fresh read',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    repository.readFailure = const ApiFailure(message: 'Offline');
    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('Internet · phiên bản 1'));
    expect(find.text('Internet · phiên bản 1'), findsOneWidget);
    await _select(tester);
    await _visible(tester, find.text('Duyệt áp dụng'));
    final button = tester.widget<FilledButton>(_filledButton('Duyệt áp dụng'));
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'locked preview disables approval but permits rejection with reason',
      (tester) async {
    final repository = _Repository()..canApprove = false;
    await _open(tester, repository);
    await _select(tester);
    await _visible(tester, find.text('Duyệt áp dụng'));
    expect(
        tester.widget<FilledButton>(_filledButton('Duyệt áp dụng')).onPressed,
        isNull);
    await tester.tap(_outlinedButton('Từ chối'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Lý do'), 'Kỳ đã phát hành');
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pumpAndSettle();
    expect(repository.reviews.single['decision'], 'REJECTED');
    expect(repository.reviews.single['reason'], 'Kỳ đã phát hành');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'account change discards draft and ignores late mutation response',
      (tester) async {
    final repository = _Repository()..pending = Completer<void>();
    final container = await _open(tester, repository);
    await _fill(tester);
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pump();
    (container.read(sessionControllerProvider.notifier) as _Session)
        .change(_session('landlord', id: 'other'));
    await tester.pump();
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi đề xuất biểu phí để duyệt.'), findsNothing);
    expect(find.text('Lý do thay đổi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'small phone and large text retain readable form without overflow',
      (tester) async {
    await _open(tester, _Repository(),
        size: const Size(360, 800), textScale: 1.4);
    await _capture(tester, 'tariffs-phone.png');
    await _fill(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'tariffs-phone-form.png');
  });

  testWidgets('tablet layout renders tariff history and comparison',
      (tester) async {
    await _open(tester, _Repository(), size: const Size(1024, 768));
    await _select(tester);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'tariffs-tablet.png');
  });

  testWidgets(
      'utility proposal validates tier boundaries and serializes unbounded last tier',
      (tester) async {
    final repository = _Repository();
    await _open(tester, repository);
    await _fill(tester);
    final kind =
        find.widgetWithText(DropdownButtonFormField<String>, 'Loại biểu phí');
    await _visible(tester, kind);
    await tester.tap(kind);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điện').last);
    await tester.pumpAndSettle();
    await _visible(tester, find.text('Thêm bậc'));
    await tester.tap(find.text('Thêm bậc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm bậc'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Đơn giá / đơn vị').at(0), '2000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Đơn giá / đơn vị').at(1), '3000');
    await _visible(tester, find.text('Gửi đề xuất'));
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pumpAndSettle();
    expect(repository.proposals, isEmpty);
    expect(find.textContaining('Các bậc phải tăng dần'), findsOneWidget);
    await _visible(tester, find.widgetWithText(TextFormField, 'Bậc 1 đến'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Bậc 1 đến'), '50');
    await _visible(tester, find.text('Gửi đề xuất'));
    await tester.tap(find.text('Gửi đề xuất'));
    await tester.pumpAndSettle();
    expect(repository.proposals.single['kind'], 'ELECTRICITY');
    expect(repository.proposals.single['serviceKey'], 'electricity');
    expect(repository.proposals.single['unit'], 'kWh');
    expect(repository.proposals.single['tiers'], [
      {'upTo': 50, 'unitPrice': 2000},
      {'upTo': null, 'unitPrice': 3000}
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history uses bounded pages and filters without writes',
      (tester) async {
    final repository = _Repository()
      ..rows = List.generate(
          14, (index) => _version(id: 't$index', name: 'Internet $index'));
    await _open(tester, repository);
    expect(find.text('Internet 12 · phiên bản 1'), findsNothing);
    await _visible(tester, find.byTooltip('Trang sau'));
    await tester.tap(find.byTooltip('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Internet 12 · phiên bản 1'), findsOneWidget);
    final query =
        find.widgetWithText(TextField, 'Tìm tên, mã biểu phí hoặc mã phòng');
    await _visible(tester, query);
    await tester.enterText(query, 'Internet 13');
    await tester.pumpAndSettle();
    expect(find.text('Internet 13 · phiên bản 1'), findsOneWidget);
    expect(find.text('Internet 12 · phiên bản 1'), findsNothing);
    expect(repository.proposals, isEmpty);
    expect(repository.reviews, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
