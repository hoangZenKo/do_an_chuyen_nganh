import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/onboarding/onboarding_preferences.dart';

final onboardingPreferencesProvider = Provider<OnboardingPreferences>((ref) {
  return OnboardingPreferences();
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingPreferencesProvider).isCompleted();
});
