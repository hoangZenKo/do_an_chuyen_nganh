import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/lease.dart';
import 'package:rental_room_management/models/room.dart';
import 'package:rental_room_management/models/tenant.dart';

const _background = Color(0xFFF8FAFC);
const _fieldSurface = Color(0xFFF1F5F9);
const _tenants = [
  Tenant(
    id: 'tenant-1',
    fullName: 'Nguyễn Văn A',
    phone: '+84901111111',
    activeLease:
        ActiveLeaseRef(id: 'lease-1', roomId: 'room-1', roomName: 'P.201'),
  ),
  Tenant(id: 'tenant-2', fullName: 'Trần Thị B'),
];

class _LandlordSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
          id: 'landlord-colors',
          fullName: 'Landlord',
          email: 'landlord@example.test',
          role: 'landlord',
        ),
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
      ));
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  String path = tenantsRoute,
  Future<List<Tenant>> Function()? load,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    sessionControllerProvider.overrideWith(_LandlordSession.new),
    tenantsProvider.overrideWith((_) => load?.call() ?? Future.value(_tenants)),
    inactiveTenantsProvider.overrideWith((_) async => []),
    tenantDetailProvider.overrideWith((_, __) async => _tenants.first),
    tenantLeasesProvider.overrideWith((_, __) async => []),
    tenantOverviewProvider
        .overrideWith((_, __) async => TenantOverview.fromJson({})),
    roomDetailProvider.overrideWith((_, __) async => const Room(
        id: 'room-1',
        propertyId: 'property-1',
        name: 'P.201',
        status: RoomStatus.occupied,
        basePrice: 3000000)),
    roomLeasesProvider.overrideWith((_, __) async => const [
          Lease(
              id: 'lease-1',
              roomId: 'room-1',
              tenantId: 'tenant-1',
              tenantName: 'Nguyễn Văn A',
              status: LeaseStatus.active,
              monthlyRent: 3000000),
        ]),
    roomServiceFeesProvider.overrideWith((_, __) async => []),
    roomAssetsProvider.overrideWith((_, __) async => []),
    roomInspectionsProvider.overrideWith((_, __) async => []),
  ]);
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(path);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const RentalRoomApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

double _contrast(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance()
  ]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
    }
  });
  for (final path in [
    tenantsRoute,
    tenantFormRoute,
    tenantFormPath(tenantId: 'tenant-1'),
    tenantDetailPath('tenant-1'),
  ]) {
    testWidgets('$path uses a consistent light tenant management theme',
        (tester) async {
      await _mount(tester, path: path);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      final theme = Theme.of(tester.element(find.byType(Scaffold).last));
      expect(theme.brightness, Brightness.light);
      expect(scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
          _background);
      expect(tester.takeException(), isNull);
    });
  }

  for (final path in [
    tenantFormRoute,
    tenantFormPath(tenantId: 'tenant-1'),
  ]) {
    testWidgets('$path back button returns to tenants when opened directly',
        (tester) async {
      final container = await _mount(tester, path: path);
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(
          container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          tenantsRoute);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tenant profile back returns to its room contract tab',
      (tester) async {
    final container = await _mount(tester, path: '/rooms/room-1');
    await tester.ensureVisible(find.text('Hợp đồng'));
    await tester.tap(find.text('Hợp đồng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hồ sơ'));
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết người thuê'), findsOneWidget);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/rooms/room-1');
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct tenant profile back falls back to the tenant list',
      (tester) async {
    final container = await _mount(tester, path: tenantDetailPath('tenant-1'));
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        tenantsRoute);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant profile back preserves the tenant search',
      (tester) async {
    await _mount(tester);
    await tester.enterText(find.byType(TextField), 'P.201');
    await tester.tap(find.text('Nguyễn Văn A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'P.201');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant form back button preserves the previous tenant search',
      (tester) async {
    await _mount(tester);
    await tester.enterText(find.byType(TextField), 'P.201');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'P.201');
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Trần Thị B'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search stays readable before and after focus and filtering',
      (tester) async {
    await _mount(tester);
    final field = find.byType(TextField);
    var decoration =
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    expect(decoration.fillColor, _fieldSurface);
    expect(_contrast(decoration.hintStyle!.color!, _fieldSurface),
        greaterThanOrEqualTo(4.5));
    await tester.enterText(field, 'P.201');
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Trần Thị B'), findsNothing);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(_contrast(editable.style.color!, _fieldSurface),
        greaterThanOrEqualTo(4.5));
    decoration =
        tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    expect(decoration.fillColor, _fieldSurface);
    expect(decoration.focusedBorder!.borderSide.color, AppTheme.primary);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Trần Thị B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive and search-empty states keep the light background',
      (tester) async {
    await _mount(tester);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy kết quả'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Ngưng hoạt động'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có người thuê ngưng hoạt động'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        _background);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network errors remain readable and retry reloads tenants',
      (tester) async {
    var attempts = 0;
    await _mount(tester, load: () async {
      if (attempts++ == 0) throw Exception('Network unavailable');
      return _tenants;
    });
    expect(find.textContaining('Network unavailable'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        _background);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile text and confirmation dialogs use the light palette',
      (tester) async {
    await _mount(tester, path: tenantDetailPath('tenant-1'));
    final name = tester.widget<Text>(find.text('Nguyễn Văn A'));
    expect(
        _contrast(name.style!.color!, Colors.white), greaterThanOrEqualTo(4.5));
    final context = tester.element(find.byType(Scaffold).last);
    final dialog = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Confirm')),
    );
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AlertDialog))).brightness,
        Brightness.light);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await dialog;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving tenant management preserves unrelated route themes',
      (tester) async {
    final container = await _mount(tester);
    container.read(appRouterProvider).go(accountAccessRoute);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
