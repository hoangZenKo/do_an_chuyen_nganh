import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/tenant_portal/tenant_portal_repository.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_maintenance_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/models/maintenance.dart';

const _ticket = MaintenanceTicket(
  id: 'ticket-test',
  propertyId: 'property-test',
  roomId: 'room-test',
  roomName: 'P.201',
  status: MaintenanceStatus.open,
  priority: MaintenancePriority.medium,
  title: 'Vòi nước bị rò',
);

class _Repository extends Mock implements TenantPortalRepository {}

Future<void> _mount(WidgetTester tester,
    {Size size = const Size(390, 844), _Repository? repository}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      if (repository != null)
        tenantPortalRepositoryProvider.overrideWithValue(repository),
      tenantPortalMaintenanceProvider.overrideWith((_) async => [_ticket])
    ],
    child: MaterialApp(
        theme: AppTheme.dark, home: const TenantMaintenanceScreen()),
  ));
  await tester.pumpAndSettle();
}

void _expectReadableFields(WidgetTester tester) {
  for (final element in find.byType(InputDecorator).evaluate()) {
    final theme = Theme.of(element);
    final decoration = (element.widget as InputDecorator).decoration;
    expect(theme.brightness, Brightness.light);
    expect(decoration.fillColor, Colors.white);
    final foreground =
        decoration.labelStyle?.color ?? theme.colorScheme.onSurfaceVariant;
    final luminances = [
      foreground.computeLuminance(),
      Colors.white.computeLuminance()
    ]..sort();
    expect((luminances.last + 0.05) / (luminances.first + 0.05),
        greaterThanOrEqualTo(4.5));
  }
  for (final field
      in tester.widgetList<EditableText>(find.byType(EditableText))) {
    final luminances = [
      field.style.color!.computeLuminance(),
      Colors.white.computeLuminance()
    ]..sort();
    expect((luminances.last + 0.05) / (luminances.first + 0.05),
        greaterThanOrEqualTo(4.5));
  }
  expect(tester.takeException(), isNull);
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

  for (final size in [const Size(390, 844), const Size(320, 740)]) {
    testWidgets('report sheet and priority menu stay light at ${size.width}',
        (tester) async {
      await _mount(tester, size: size);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Báo sự cố bảo trì'), findsOneWidget);
      _expectReadableFields(tester);
      await tester
          .tap(find.byType(DropdownButtonFormField<MaintenancePriority>));
      await tester.pumpAndSettle();
      final menuItem = find.text('Khẩn cấp').last;
      expect(Theme.of(tester.element(menuItem)).brightness, Brightness.light);
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      _expectReadableFields(tester);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('quick issue opens the same light report form', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Điều hòa / Nóng lạnh'));
    await tester.pumpAndSettle();
    _expectReadableFields(tester);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Kiểm tra điều hòa / bình nóng lạnh');
  });

  testWidgets('ticket response sheet also inherits the light maintenance theme',
      (tester) async {
    await _mount(tester);
    await tester.scrollUntilVisible(find.text(_ticket.title), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text(_ticket.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_ticket.title));
    await tester.pumpAndSettle();
    expect(find.text('Phản hồi'), findsOneWidget);
    _expectReadableFields(tester);
  });

  testWidgets('focused fields and validation stay readable above the keyboard',
      (tester) async {
    await _mount(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tiêu đề sự cố.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Vòi nước bị rò');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    _expectReadableFields(tester);
    await tester.ensureVisible(find.text('Hủy'));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting the light form preserves the maintenance payload',
      (tester) async {
    final repository = _Repository();
    when(() => repository.createMaintenance(
        title: 'Vòi nước bị rò',
        description: 'Rò tại bồn rửa',
        priority: MaintenancePriority.medium,
        imageUrls: const [])).thenAnswer((_) async => _ticket);
    await _mount(tester, repository: repository);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Vòi nước bị rò');
    await tester.enterText(find.byType(TextField).at(1), 'Rò tại bồn rửa');
    await tester.ensureVisible(find.text('Gửi yêu cầu'));
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Báo sự cố bảo trì'), findsNothing);
    expect(tester.takeException(), isNull);
    verify(() => repository.createMaintenance(
        title: 'Vòi nước bị rò',
        description: 'Rò tại bồn rửa',
        priority: MaintenancePriority.medium,
        imageUrls: const [])).called(1);
  });
}
