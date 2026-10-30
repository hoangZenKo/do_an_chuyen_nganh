import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/maintenance/maintenance_form_screen.dart';
import 'package:rental_room_management/features/maintenance/maintenance_providers.dart';
import 'package:rental_room_management/features/maintenance/maintenance_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_management_theme.dart';
import 'package:rental_room_management/features/tenants/widgets/form_widgets.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/maintenance.dart';
import 'package:rental_room_management/models/property.dart';
import 'package:rental_room_management/models/room.dart';

const _ticket = MaintenanceTicket(
  id: 'ticket',
  propertyId: 'property',
  roomId: 'room',
  roomName: 'A101',
  propertyName: 'Atrium',
  title: 'Vỡ ống nước',
  description: 'Ống nước dưới bồn rửa bị rò rỉ.',
  status: MaintenanceStatus.open,
  priority: MaintenancePriority.urgent,
  estimatedCost: 350000,
);

const _result = MaintenanceListResult(
  items: [_ticket],
  summary: MaintenanceSummary(
    count: 1,
    openCount: 1,
    doneCount: 0,
    estimatedCost: 350000,
    actualCost: 0,
  ),
);

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
            id: 'owner', fullName: 'Owner', email: 'owner@test.com'),
        accessToken: 'test',
        refreshToken: 'test',
      ));
}

Future<void> _mount(
  WidgetTester tester, {
  Widget screen = const MaintenanceScreen(),
  ThemeData? theme,
  double width = 390,
  Future<MaintenanceListResult> Function(MaintenanceListQuery)? load,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(_Session.new),
      maintenanceListProvider.overrideWith(
          (ref, query) async => load == null ? _result : await load(query)),
      maintenanceDetailProvider.overrideWith((ref, id) async => _ticket),
      propertiesProvider.overrideWith((ref) async => const [
            Property(id: 'property', name: 'Atrium', address: 'Test address'),
          ]),
      roomsProvider.overrideWith((ref, id) async => const [
            Room(
              id: 'room',
              propertyId: 'property',
              name: 'A101',
              status: RoomStatus.occupied,
            ),
          ]),
    ],
    child: MaterialApp(theme: theme ?? AppTheme.dark, home: screen),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

double _contrast(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}

void _expectReadableText(WidgetTester tester, Finder finder, Color background) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(_contrast(paragraph.text.style!.color!, background),
      greaterThanOrEqualTo(4.5));
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('list and search have readable colors at width $width',
        (tester) async {
      await _mount(tester, width: width);
      await tester.pumpAndSettle();
      final card = tester.widget<Container>(find
          .ancestor(
              of: find.text(_ticket.title), matching: find.byType(Container))
          .first);
      expect((card.decoration! as BoxDecoration).color,
          AppTheme.dark.colorScheme.surface);
      _expectReadableText(
          tester, find.text(_ticket.title), AppTheme.dark.colorScheme.surface);
      _expectReadableText(tester, find.text(_ticket.description!),
          AppTheme.dark.colorScheme.surface);
      final input = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(input.decoration.fillColor, AppTheme.surfaceAlt);
      expect(_contrast(input.decoration.hintStyle!.color!, AppTheme.surfaceAlt),
          greaterThanOrEqualTo(4.5));
      await tester.enterText(find.byType(TextField), 'không tồn tại');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có yêu cầu sửa chữa'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'A101');
      await tester.pumpAndSettle();
      expect(find.text(_ticket.title), findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(_contrast(editable.style.color!, AppTheme.surfaceAlt),
          greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filters still send the selected status and priority',
      (tester) async {
    final queries = <MaintenanceListQuery>[];
    await _mount(tester, load: (query) async {
      queries.add(query);
      return _result;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đang xử lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khẩn cấp').first);
    await tester.pumpAndSettle();
    expect(queries.last.status, MaintenanceStatus.inProgress);
    expect(queries.last.priority, MaintenancePriority.urgent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected filters and urgent badges retain readable contrast',
      (tester) async {
    await _mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khẩn cấp').first);
    await tester.pumpAndSettle();
    for (final label in ['Tất cả', 'Mới báo', 'Khẩn cấp']) {
      final matches = find.text(label);
      for (var index = 0; index < matches.evaluate().length; index++) {
        final text = matches.at(index);
        final container = tester.widget<Container>(
            find.ancestor(of: text, matching: find.byType(Container)).first);
        final decoration = container.decoration! as BoxDecoration;
        final background =
            Color.alphaBlend(decoration.color!, AppTheme.surface);
        _expectReadableText(tester, text, background);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('maintenance honors a light theme without hardcoded dark text',
      (tester) async {
    final theme = TenantManagementTheme.light;
    await _mount(tester, theme: theme);
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);
    _expectReadableText(
        tester, find.text(_ticket.title), theme.colorScheme.surface);
    _expectReadableText(
        tester, find.text(_ticket.description!), theme.colorScheme.surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared text fields keep the existing light tenant form readable',
      (tester) async {
    final controller = TextEditingController(text: 'Tenant');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: TenantManagementTheme.light,
      home: Scaffold(
        body: AppTextField(controller: controller, label: 'Name', hint: 'Name'),
      ),
    ));
    final input = tester.widget<InputDecorator>(find.byType(InputDecorator));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(input.decoration.fillColor, Colors.white);
    expect(_contrast(editable.style.color!, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(input.decoration.hintStyle!.color!, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticket detail and completion dialog keep dark surfaces',
      (tester) async {
    await _mount(tester, screen: const MaintenanceScreen(ticketId: 'ticket'));
    await tester.pumpAndSettle();
    _expectReadableText(tester, find.text(_ticket.title), AppTheme.surface);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn tất sửa chữa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final edit in [false, true]) {
    testWidgets('form dropdown and text colors are readable, edit=$edit',
        (tester) async {
      await _mount(tester,
          screen: MaintenanceFormScreen(ticketId: edit ? 'ticket' : null));
      await tester.pumpAndSettle();
      final input = tester.widget<InputDecorator>(find
          .descendant(
              of: find.byType(DropdownButtonFormField<Property>),
              matching: find.byType(InputDecorator))
          .first);
      _expectReadableText(
          tester, find.text('Atrium').first, input.decoration.fillColor!);
      await tester.tap(find.byType(DropdownButton<Property>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Atrium').last);
      await tester.pumpAndSettle();
      final titleField = find.ancestor(
          of: find.text('Tiêu đề'), matching: find.byType(AppTextField));
      final editable = tester.widget<EditableText>(
          find.descendant(of: titleField, matching: find.byType(EditableText)));
      final titleInput = tester.widget<InputDecorator>(find.descendant(
          of: titleField, matching: find.byType(InputDecorator)));
      expect(titleInput.decoration.fillColor, AppTheme.surfaceAlt);
      expect(_contrast(editable.style.color!, AppTheme.surfaceAlt),
          greaterThanOrEqualTo(4.5));
      if (edit) expect(find.text(_ticket.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading, error and retry preserve the active theme',
      (tester) async {
    final pending = Completer<MaintenanceListResult>();
    var calls = 0;
    await _mount(tester, load: (_) {
      calls++;
      return calls == 1 ? pending.future : Future.value(_result);
    });
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .color,
        AppTheme.dark.colorScheme.primary);
    pending.completeError(StateError('Maintenance unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Maintenance unavailable'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text(_ticket.title), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
