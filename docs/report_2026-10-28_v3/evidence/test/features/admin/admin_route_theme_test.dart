import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/features/admin/admin_overview_theme.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_workspace_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/auth_models.dart';

class _AdminSession extends SessionController {
  @override
  SessionState build() => SessionState.authenticated(AuthSession(
      user: LandlordUser(
          id: 'admin-theme-test',
          fullName: 'Admin',
          email: 'admin@example.test',
          role: 'admin',
          permissions: [
            for (final destination in adminDestinations)
              ...destination.permissions,
            'admin.support.manage',
            'admin.properties.manage',
          ]),
      accessToken: 'test-access',
      refreshToken: 'test-refresh'));
}

void main() {
  final paths = [
    for (final destination in adminDestinations) destination.path,
    '/admin/properties/form',
    '/admin/properties/property-1',
    '/admin/landlords/form',
    '/admin/landlords/landlord-1',
    '/admin/accounts/account-1',
    '/admin/tickets?ticketId=ticket-1',
    '/admin/reports',
  ];
  for (final path in paths) {
    testWidgets('$path keeps the new theme when workspace identity changes',
        (tester) async {
      final container = ProviderContainer(overrides: [
        sessionControllerProvider.overrideWith(_AdminSession.new),
        sessionIdentityProvider.overrideWithValue(null),
        adminCapabilitiesProvider
            .overrideWith((_) async => const AdminCapabilities([])),
      ]);
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      router.go(path);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const RentalRoomApp()));
      await tester.pumpAndSettle();

      expect(
          router.routeInformationProvider.value.uri.path, Uri.parse(path).path);
      final context = tester.element(find.byType(Navigator).last);
      expect(Theme.of(context).brightness, Brightness.light);
      expect(Theme.of(context).scaffoldBackgroundColor,
          AdminOverviewTheme.background);
      if (path == '/admin/security') {
        final dialog = showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(title: Text('Admin dialog')));
        await tester.pumpAndSettle();
        expect(Theme.of(tester.element(find.byType(AlertDialog))).brightness,
            Brightness.light);
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await dialog;
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non-Admin account access keeps its existing theme',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(_AdminSession.new),
      sessionIdentityProvider.overrideWithValue(null),
      adminCapabilitiesProvider
          .overrideWith((_) async => const AdminCapabilities([])),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go('/admin/security');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const RentalRoomApp()));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
        Brightness.light);

    router.go(accountAccessRoute);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, accountAccessRoute);
    expect(Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
        Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
