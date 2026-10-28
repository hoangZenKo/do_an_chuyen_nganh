import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/app/app.dart';
import 'package:rental_room_management/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('shows splash screen first', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: RentalRoomApp()),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  for (final size in <Size>[
    const Size(375, 812),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('onboarding pages fit ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atrium Rooms'), findsOneWidget);
      expect(find.text('Manage your\nrooms with ease'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Smart payment\ntracking'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Stay connected\nwith tenants'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });
  }
}
