import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/onboarding/onboarding_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('is incomplete when the completion key is absent', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = OnboardingPreferences();

    expect(await preferences.isCompleted(), isFalse);
  });

  test('marks onboarding as completed', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = OnboardingPreferences();

    await preferences.markCompleted();

    expect(await preferences.isCompleted(), isTrue);
    final raw = await SharedPreferences.getInstance();
    expect(raw.getBool(OnboardingPreferences.completedKey), isTrue);
  });
}
