import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/widgets/liquid_bubble_navigation.dart';

void main() {
  testWidgets('scroll padding follows the actual taskbar height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBody: true,
        bottomNavigationBar: const SizedBox(
          key: ValueKey('taskbar'),
          height: 200,
        ),
        body: Builder(builder: (context) {
          return ListView(
            padding: EdgeInsets.only(
              bottom: liquidTaskbarBottomPadding(context),
            ),
            children: [
              for (var index = 0; index < 20; index++)
                SizedBox(height: 80, child: Text('Item $index')),
              const SizedBox(
                key: ValueKey('last-item'),
                height: 60,
                child: Text('Last item'),
              ),
            ],
          );
        }),
      ),
    ));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    final last = tester.getRect(find.byKey(const ValueKey('last-item')));
    final bar = tester.getRect(find.byKey(const ValueKey('taskbar')));
    expect(last.bottom, lessThanOrEqualTo(bar.top - 16));
  });

  for (final safeArea in [0.0, 34.0]) {
    for (final additionalClearance in [0.0, 72.0]) {
      testWidgets(
          'nested scaffold preserves taskbar clearance with safe area $safeArea and extra $additionalClearance',
          (tester) async {
        Widget harness(double height) => MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: EdgeInsets.only(bottom: safeArea),
                  viewPadding: EdgeInsets.only(bottom: safeArea),
                ),
                child: child!,
              ),
              home: Scaffold(
                extendBody: true,
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: SizedBox(
                    key: const ValueKey('taskbar'),
                    height: height,
                  ),
                ),
                body: LiquidTaskbarScrollScope(
                  additionalClearance: additionalClearance,
                  child: Scaffold(
                    bottomNavigationBar: const SizedBox.shrink(),
                    body: Builder(builder: (context) {
                      return ListView(
                        padding: EdgeInsets.only(
                          bottom: liquidTaskbarBottomPadding(context),
                        ),
                        children: [
                          for (var index = 0; index < 20; index++)
                            SizedBox(height: 80, child: Text('Item $index')),
                          const SizedBox(
                            key: ValueKey('last-item'),
                            height: 60,
                            child: Text('Last item'),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            );

        for (final height in [80.0, 200.0]) {
          await tester.pumpWidget(harness(height));
          await tester.pumpAndSettle();
          final list = find.byType(ListView);
          expect(tester.getRect(list).bottom,
              tester.view.physicalSize.height / tester.view.devicePixelRatio);
          await tester.drag(list, const Offset(0, -4000));
          await tester.pumpAndSettle();
          final last = tester.getRect(find.byKey(const ValueKey('last-item')));
          final bar = tester.getRect(find.byKey(const ValueKey('taskbar')));
          expect(
              last.bottom, closeTo(bar.top - 16 - additionalClearance, 0.01));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('standalone content does not reserve a nonexistent taskbar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: LiquidTaskbarScrollScope(
          child: Builder(builder: (context) {
            return SizedBox(
              key: const ValueKey('padding'),
              height: liquidTaskbarBottomPadding(context),
            );
          }),
        ),
      ),
    ));
    expect(
        tester.widget<SizedBox>(find.byKey(const ValueKey('padding'))).height,
        50);
  });

  testWidgets('keyboard inset replaces hidden taskbar scroll clearance',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 120),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: LiquidTaskbarScrollScope(
          child: Builder(builder: (context) {
            return SizedBox(
              key: const ValueKey('padding'),
              height: liquidTaskbarBottomPadding(context),
            );
          }),
        ),
      ),
    ));
    expect(
        tester.widget<SizedBox>(find.byKey(const ValueKey('padding'))).height,
        16);
  });
}
