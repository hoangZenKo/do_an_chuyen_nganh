import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_overview_shell.dart';
import 'package:rental_room_management/features/admin/admin_overview_theme.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_workspace_scaffold.dart';
import 'package:rental_room_management/features/admin/admin_workflow_widgets.dart';
import 'package:rental_room_management/features/admin/admin_landlord_form_screen.dart';
import 'package:rental_room_management/features/admin/admin_landlords_screen.dart';
import 'package:rental_room_management/features/admin/admin_property_form_screen.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

void main() {
  testWidgets('landlord directory uses the canonical inventory section',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionIdentityProvider.overrideWithValue('operator'),
      adminCapabilitiesProvider.overrideWith(
          (_) async => const AdminCapabilities(['admin.accounts.manage'])),
      adminLandlordsProvider.overrideWith((ref, query) async => []),
    ], child: const MaterialApp(home: AdminLandlordsScreen())));
    await tester.pumpAndSettle();
    expect(find.byType(AdminSectionPanel), findsOneWidget);
    expect(find.text('Danh mục chủ trọ'), findsOneWidget);
    expect(find.text('Không tìm thấy chủ trọ.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('forms and dialogs share the overview surfaces', () {
    final theme = AdminOverviewTheme.light;
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.fillColor, AdminOverviewTheme.surface);
    expect(theme.dialogTheme.backgroundColor, AdminOverviewTheme.surface);
  });

  test('neutral workflow status uses the canonical accent', () {
    expect(workflowStatusColor('OPEN'), AdminOverviewTheme.blue);
  });

  testWidgets('shared workflow components use the overview accent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AdminOverviewTheme.light,
        home: const Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          AdminSectionPanel(title: 'Section', icon: Icons.support_agent),
          AdminMetricCard(label: 'Metric', value: '1', icon: Icons.analytics),
          AdminRecordCard(title: Text('Record'), leadingIcon: Icons.receipt),
        ])))));
    for (final icon in [Icons.support_agent, Icons.analytics, Icons.receipt]) {
      expect(tester.widget<Icon>(find.byIcon(icon)).color,
          AdminOverviewTheme.blue);
    }
    expect(tester.takeException(), isNull);
  });

  for (final screen in const [
    AdminLandlordFormScreen(),
    AdminPropertyFormScreen()
  ]) {
    testWidgets('$screen uses the shared shell', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionIdentityProvider.overrideWithValue('operator'),
        adminCapabilitiesProvider.overrideWith((_) async =>
            const AdminCapabilities([
              'admin.accounts.manage',
              'admin.properties.view',
              'admin.properties.manage'
            ])),
        adminLandlordsProvider.overrideWith((ref, query) async => []),
      ], child: MaterialApp(home: screen)));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOverviewShell), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      for (final field
          in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
        final input = tester.widget<InputDecorator>(find.descendant(
            of: find.byWidget(field), matching: find.byType(InputDecorator)));
        expect(input.decoration.labelText, isNotEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final configuration in [(1440.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    final (width, textScale) = configuration;
    testWidgets(
        'property workspace shares dashboard shell at width $width scale $textScale',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var summaryReads = 0;
      final router = GoRouter(initialLocation: '/admin/properties/p1', routes: [
        GoRoute(
            path: '/admin/properties/:id',
            builder: (_, __) => const AdminWorkspaceScaffold(
                title: 'Chi tiết khu trọ',
                location: '/admin/properties/p1',
                body: Text('Property content'))),
        GoRoute(
            path: '/admin/properties', builder: (_, __) => const SizedBox()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionIdentityProvider.overrideWithValue('admin-1'),
            adminCapabilitiesProvider.overrideWith((_) async =>
                const AdminCapabilities(['admin.properties.view'])),
            adminWorkspaceSummaryProvider.overrideWith((_) async {
              summaryReads++;
              throw StateError('A view-only operator must not load summary');
            }),
          ],
          child: MaterialApp.router(
              theme: ThemeData.dark(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOverviewShell), findsOneWidget);
      expect(find.text('Property content'), findsOneWidget);
      final contentContext = tester.element(find.text('Property content'));
      expect(Theme.of(contentContext).brightness, Brightness.light);
      expect(Theme.of(contentContext).scaffoldBackgroundColor,
          AdminOverviewTheme.background);
      expect(summaryReads, 0);
      if (width >= 1100) {
        expect(find.text('Rental Admin'), findsOneWidget);
        final tile = tester.widget<ListTile>(
            find.byKey(const ValueKey('admin-nav-/admin/properties')));
        expect(tile.selected, isTrue);
      } else {
        final navigation =
            tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(navigation.selectedIndex,
            inInclusiveRange(0, navigation.destinations.length - 1));
        expect(find.text('Khu trọ'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
