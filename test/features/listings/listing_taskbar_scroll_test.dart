import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/explore_screen.dart';
import 'package:rental_room_management/features/listings/listing_widgets.dart';
import 'package:rental_room_management/features/listings/listings_providers.dart';
import 'package:rental_room_management/features/listings/seeker_account_screen.dart';
import 'package:rental_room_management/features/listings/tenant_home_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/models/room_listing.dart';

import '../../data/listings/listings_api_test.dart' show listingJson;

class _GuestSession extends SessionController {
  @override
  SessionState build() => const SessionState.unauthenticated();
}

void main() {
  for (final tab in [
    (0, const ExploreScreen(), 'Trang sau'),
    (1, const TenantHomeScreen(), 'Kiểm tra liên kết hợp đồng'),
    (2, const SeekerAccountScreen(), 'Tạo tài khoản'),
  ]) {
    testWidgets('listing tab ${tab.$1} reveals its final action above taskbar',
        (tester) async {
      tester.view.physicalSize = const Size(430, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_GuestSession.new),
          publicListingsProvider.overrideWith((ref, query) async =>
              const ListingPage(items: [], total: 0, page: 1, limit: 12)),
          tenantPortalProfileProvider
              .overrideWith((ref) async => throw const ApiFailure(
                    message: 'Missing tenant profile',
                    code: 'TENANT_PROFILE_NOT_FOUND',
                  )),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 34),
              viewPadding: const EdgeInsets.only(bottom: 34),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: ListingNavigationShell(
            selectedIndex: tab.$1,
            child: tab.$2,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final nav = find.byType(LiquidBubbleNavigation);
      expect(nav, findsOneWidget);
      final navRect = tester.getRect(nav);
      final scrollView = tab.$1 == 1
          ? find.byType(SingleChildScrollView).first
          : find.byType(ListView).first;
      expect(tester.getRect(scrollView).bottom, 700);

      await tester.drag(scrollView, const Offset(0, -4000));
      await tester.pumpAndSettle();
      final lastAction = find
          .ancestor(
            of: find.text(tab.$3),
            matching:
                find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          )
          .first;
      expect(tester.getRect(lastAction).bottom,
          lessThanOrEqualTo(navRect.top - 15.9));
      expect(tester.getRect(nav), navRect);
      final bubble = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('liquid-navigation-bubble')));
      expect((bubble.decoration as BoxDecoration).color, Colors.white);

      if (tab.$1 == 0) {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExploreScreen)),
        );
        final comparison = container.read(listingComparisonProvider.notifier);
        for (final identifier in ['first', 'second']) {
          comparison
              .toggle(RoomListing.fromJson({...listingJson, 'id': identifier}));
        }
        await tester.pumpAndSettle();
        final compareButton = find
            .ancestor(
              of: find.text('So sánh'),
              matching: find
                  .byWidgetPredicate((widget) => widget is ButtonStyleButton),
            )
            .first;
        expect(compareButton.hitTestable(), findsOneWidget);
        expect(tester.getRect(compareButton).bottom, lessThan(navRect.top));
        await tester.drag(scrollView, const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(tester.getRect(lastAction).bottom,
            lessThan(tester.getRect(compareButton).top));
        expect(tester.getRect(nav), navRect);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
