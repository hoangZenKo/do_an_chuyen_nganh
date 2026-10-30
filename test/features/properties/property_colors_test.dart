import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/property.dart';

const _properties = [
  Property(
    id: 'p1',
    name: 'Khu A',
    address: '123 Đường A',
    roomCount: 5,
    occupiedCount: 3,
  ),
];
const _archived = [
  Property(id: 'p2', name: 'Khu B', address: '', isArchived: true),
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
  String path = propertiesRoute,
  double width = 390,
  Future<List<Property>> Function()? load,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    sessionControllerProvider.overrideWith(_LandlordSession.new),
    propertiesProvider
        .overrideWith((_) => load?.call() ?? Future.value(_properties)),
    archivedPropertiesProvider.overrideWith((_) async => _archived),
  ]);
  addTearDown(container.dispose);
  container.read(appRouterProvider).go(path);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const RentalRoomApp(),
  ));
  if (settle) await tester.pumpAndSettle();
  return container;
}

ThemeData _theme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last));

Color _textColor(WidgetTester tester, String text) {
  final finder = find.text(text);
  return tester.widget<Text>(finder).style?.color ??
      DefaultTextStyle.of(tester.element(finder)).style.color!;
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

  for (final width in [320.0, 390.0]) {
    for (final path in [
      propertiesRoute,
      propertyFormRoute,
      propertyFormPath(propertyId: 'p1'),
    ]) {
      testWidgets('$path has a light theme at width $width', (tester) async {
        await _mount(tester, path: path, width: width);
        final theme = _theme(tester);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
        expect(theme.brightness, Brightness.light);
        expect(
            (scaffold.backgroundColor ?? theme.scaffoldBackgroundColor)
                .computeLuminance(),
            greaterThan(0.9));
        expect(theme.appBarTheme.backgroundColor!.computeLuminance(),
            greaterThan(0.9));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('property card names and addresses are readable on white',
      (tester) async {
    await _mount(tester);
    for (final text in ['Khu A', '123 Đường A']) {
      expect(_contrast(_textColor(tester, text), Colors.white),
          greaterThanOrEqualTo(4.5));
    }
    for (final text in ['5 phòng', '3 đang thuê', '2 trống', 'Archived']) {
      final container = tester.widget<Container>(find
          .ancestor(
            of: find.text(text),
            matching: find.byType(Container),
          )
          .first);
      final background = (container.decoration! as BoxDecoration).color!;
      expect(background.computeLuminance(), greaterThan(0.8));
      expect(_contrast(_textColor(tester, text), background),
          greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('archived properties and popup menus remain light',
      (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Khu B'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(_contrast(_textColor(tester, 'Khu B'), Colors.white),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Restore'))).brightness,
        Brightness.light);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(_theme(tester).brightness, Brightness.light);
    expect(Theme.of(tester.element(find.byType(AlertDialog))).brightness,
        Brightness.light);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final path in [propertyFormRoute, propertyFormPath(propertyId: 'p1')]) {
    testWidgets('$path fields and placeholders have readable contrast',
        (tester) async {
      await _mount(tester, path: path);
      for (final field
          in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
        final editable = tester.widget<EditableText>(find.descendant(
            of: find.byWidget(field), matching: find.byType(EditableText)));
        final decoration = tester
            .widget<InputDecorator>(find.descendant(
                of: find.byWidget(field),
                matching: find.byType(InputDecorator)))
            .decoration;
        final background = decoration.fillColor!;
        expect(background.computeLuminance(), greaterThan(0.8));
        expect(_contrast(editable.style.color!, background),
            greaterThanOrEqualTo(4.5));
        expect(_contrast(decoration.hintStyle!.color!, background),
            greaterThanOrEqualTo(4.5));
      }
      for (final text in ['Tên khu trọ', 'Địa chỉ']) {
        expect(
            _contrast(_textColor(tester, text),
                _theme(tester).scaffoldBackgroundColor),
            greaterThanOrEqualTo(4.5));
      }
      expect(find.byTooltip('Quay lại'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Khu A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty state and create navigation keep the light theme',
      (tester) async {
    await _mount(tester, load: () async => []);
    expect(
        _contrast(_textColor(tester, 'Chưa có khu trọ'),
            _theme(tester).scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
    await tester.pumpAndSettle();
    expect(_theme(tester).brightness, Brightness.light);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có khu trọ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and retry states stay light', (tester) async {
    final pending = Completer<List<Property>>();
    var attempts = 0;
    await _mount(tester, settle: false, load: () {
      if (attempts++ == 0) return pending.future;
      return Future.value(_properties);
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_theme(tester).brightness, Brightness.light);
    pending.completeError(Exception('Network unavailable'));
    await tester.pumpAndSettle();
    expect(
        _contrast(_textColor(tester, 'Exception: Network unavailable'),
            _theme(tester).scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Khu A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving properties does not change unrelated route themes',
      (tester) async {
    final container = await _mount(tester);
    container.read(appRouterProvider).go(accountAccessRoute);
    await tester.pumpAndSettle();
    expect(_theme(tester).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
