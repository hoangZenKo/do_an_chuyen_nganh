import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/listings_providers.dart';
import 'package:rental_room_management/models/room_listing.dart';

class _GuestSession extends SessionController {
  @override
  SessionState build() => const SessionState.unauthenticated();
}

void main() {
  testWidgets('real tab routes share one fixed, persistent taskbar',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(_GuestSession.new),
      publicListingsProvider.overrideWith((ref, query) async =>
          const ListingPage(items: [], total: 0, page: 1, limit: 12)),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go(exploreRoute);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final nav = find.byType(LiquidBubbleNavigation);
    expect(nav, findsOneWidget);
    final state = tester.state(nav);
    final rect = tester.getRect(nav);
    final initialBubble = tester
        .getCenter(find.byKey(const ValueKey('liquid-navigation-bubble')));

    await tester.tap(find.text('Tài khoản'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(router.routeInformationProvider.value.uri.path, seekerAccountRoute);
    expect(nav, findsOneWidget);
    expect(identical(tester.state(nav), state), isTrue);
    expect(tester.getRect(nav), rect);
    final bubble = tester
        .getCenter(find.byKey(const ValueKey('liquid-navigation-bubble')));
    expect(bubble.dx, greaterThan(initialBubble.dx));
    expect(
        bubble.dx, lessThan(tester.getCenter(find.text('Tài khoản').last).dx));
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidBubbleNavigation>(nav).selectedIndex, 2);

    router.go(exploreRoute);
    await tester.pumpAndSettle();
    expect(nav, findsOneWidget);
    expect(identical(tester.state(nav), state), isTrue);
    expect(tester.widget<LiquidBubbleNavigation>(nav).selectedIndex, 0);
    expect(tester.takeException(), isNull);
  });
}
