import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/listings/listing_widgets.dart';

void main() {
  testWidgets('holding and dragging the taskbar selects a tab on release',
      (tester) async {
    final router = GoRouter(
      initialLocation: exploreRoute,
      routes: [
        for (final (index, path) in [
          exploreRoute,
          tenantPortalRoute,
          seekerAccountRoute,
        ].indexed)
          GoRoute(
            path: path,
            builder: (_, __) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: ListingNavigation(selectedIndex: index),
            ),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Khám phá')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('Tài khoản')));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, exploreRoute);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, seekerAccountRoute);
  });

  testWidgets(
      'bubble follows the finger and a cancelled drag does not navigate',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_harness(onSelected: changes.add));
    final before = tester.getCenter(find.byKey(_bubble));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Explore')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();

    expect(
        tester.getCenter(find.byKey(_bubble)).dx, closeTo(before.dx + 90, 1));
    expect(changes, isEmpty);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(tester.getCenter(find.byKey(_bubble)), before);
  });

  testWidgets('tap slides the bubble and supports rapid retargeting',
      (tester) async {
    await tester.pumpWidget(_harness());
    final start = tester.getCenter(find.byKey(_bubble)).dx;
    await tester.tap(find.text('Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final intermediate = tester.getCenter(find.byKey(_bubble)).dx;
    expect(intermediate, greaterThan(start));
    expect(intermediate, lessThan(tester.getCenter(find.text('Account')).dx));

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.byKey(_bubble)).dx,
        closeTo(tester.getCenter(find.text('Home')).dx, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected selection settles back to the active tab',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(_harness(
      acceptSelection: false,
      onSelected: changes.add,
    ));
    final before = tester.getCenter(find.byKey(_bubble));
    await tester.dragFrom(
        tester.getCenter(find.text('Explore')), const Offset(550, 0));
    await tester.pumpAndSettle();
    expect(changes, [2]);
    expect(tester.getCenter(find.byKey(_bubble)), before);
  });

  testWidgets('actions and the center button do not become selected tabs',
      (tester) async {
    var centerTaps = 0;
    final changes = <int>[];
    await tester.pumpWidget(_harness(
      items: [
        ..._items,
        const LiquidNavigationItem(
          icon: Icons.menu,
          selectedIcon: Icons.menu,
          label: 'More',
          isAction: true,
        ),
      ],
      onSelected: changes.add,
      centerAction: IconButton(
        onPressed: () => centerTaps++,
        icon: const Icon(Icons.add),
      ),
    ));
    final before = tester.getCenter(find.byKey(_bubble));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(centerTaps, 1);
    expect(changes, isEmpty);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(changes, [3]);
    expect(tester.getCenter(find.byKey(_bubble)), before);

    changes.clear();
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Explore')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('More')));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, [2]);
  });

  testWidgets('reduced motion selects immediately without a spring',
      (tester) async {
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.tap(find.text('Account'));
    await tester.pump();
    expect(tester.getCenter(find.byKey(_bubble)).dx,
        closeTo(tester.getCenter(find.text('Account')).dx, 1));
    final selectedCenter = tester.getCenter(find.byKey(_bubble));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(find.byKey(_bubble)), selectedCenter);
  });

  testWidgets('RTL dragging uses the visible tab under the finger',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
        _harness(textDirection: TextDirection.rtl, onSelected: changes.add));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Explore')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.text('Account')));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(changes, [2]);
    expect(tester.getCenter(find.byKey(_bubble)).dx,
        closeTo(tester.getCenter(find.text('Account')).dx, 1));
  });

  for (final width in [320.0, 430.0, 1024.0]) {
    testWidgets('taskbar stays fixed and the last item is accessible at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_harness(textScale: 2, bottomInset: 34));
      await tester.pumpAndSettle();
      final navBefore = tester.getRect(find.byType(LiquidBubbleNavigation));
      await tester.scrollUntilVisible(find.text('Last item'), 400,
          scrollable: find.byType(Scrollable));
      await tester.pumpAndSettle();
      final navAfter = tester.getRect(find.byType(LiquidBubbleNavigation));
      expect(navAfter, navBefore);
      expect(navAfter.bottom, closeTo(812 - 34, 1));
      expect(tester.getRect(find.text('Last item')).bottom,
          lessThanOrEqualTo(navAfter.top));
      await tester.tap(find.text('Last item'));
      await tester.pump();
      expect(find.text('Reached the end'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _bubble = ValueKey('liquid-navigation-bubble');
const _items = [
  LiquidNavigationItem(
      icon: Icons.search, selectedIcon: Icons.search, label: 'Explore'),
  LiquidNavigationItem(
      icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  LiquidNavigationItem(
      icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Account'),
];

Widget _harness({
  ValueChanged<int>? onSelected,
  bool acceptSelection = true,
  bool disableAnimations = false,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
  double bottomInset = 0,
  List<LiquidNavigationItem> items = _items,
  Widget? centerAction,
}) {
  var selected = 0;
  var reachedEnd = false;
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        padding: EdgeInsets.only(bottom: bottomInset),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: textDirection,
        child: StatefulBuilder(builder: (context, setState) {
          return Scaffold(
            extendBody: false,
            body: ListView.builder(
              itemCount: 51,
              itemBuilder: (_, index) => index == 50
                  ? TextButton(
                      onPressed: () => setState(() => reachedEnd = true),
                      child: Text(reachedEnd ? 'Reached the end' : 'Last item'),
                    )
                  : SizedBox(height: 80, child: Text('Item $index')),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: LiquidBubbleNavigation(
                selectedIndex: selected,
                items: items,
                centerAction: centerAction,
                onSelected: (index) {
                  onSelected?.call(index);
                  if (acceptSelection && !items[index].isAction) {
                    setState(() => selected = index);
                  }
                },
              ),
            ),
          );
        }),
      ),
    ),
  );
}
