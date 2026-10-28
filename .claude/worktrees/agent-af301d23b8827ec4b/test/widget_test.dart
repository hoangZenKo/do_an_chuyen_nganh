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

    expect(find.text('Welcome Home'), findsOneWidget);
    expect(find.text('SECURE CONNECTION'), findsOneWidget);

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

      final expectedTitleSize = size.width < 390 ? 28.0 : 32.0;
      final expectedBodySize = size.width < 390 ? 16.0 : 18.0;
      final expectedButtonSize = size.width < 390 ? 14.0 : 15.0;
      final expectedNextWidth = size.width < 390 ? 132.0 : 160.0;
      final expectedNextHeight = size.width < 390 ? 48.0 : 54.0;

      final nextButton = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.text('Next'),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(nextButton.width, expectedNextWidth);
      expect(nextButton.height, expectedNextHeight);

      final firstPageTitle = tester.widget<Text>(
        find.text('Find Your Perfect\nSpace'),
      );
      final firstPageDescription = tester.widget<Text>(
        find.text(
          'Explore a curated selection of premium rooms in prime locations. '
          'We handle the logistics so you can feel at home.',
        ),
      );
      expect(firstPageTitle.style?.fontSize, expectedTitleSize);
      expect(firstPageDescription.style?.fontSize, expectedBodySize);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Seamless Paperless\nBooking'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Manage with Ease'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Atrium\nLiving'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);

      final welcomeTitle = tester.widget<Text>(
        find.text('Welcome to Atrium\nLiving'),
      );
      final welcomeDescription = tester.widget<Text>(
        find.text(
          'Your journey to a better living experience starts here. '
          'Discover premium spaces managed with care and precision.',
        ),
      );
      expect(welcomeTitle.style?.fontSize, expectedTitleSize);
      expect(welcomeDescription.style?.fontSize, expectedBodySize);

      for (final label in <String>['Create Account', 'Log In']) {
        final button = tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        );
        expect(
            button.style?.textStyle?.resolve({})?.fontSize, expectedButtonSize);
      }
    });
  }
}
