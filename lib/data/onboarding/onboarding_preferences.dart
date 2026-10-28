import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  OnboardingPreferences({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const completedKey = 'onboarding.completed.v1';

  final Future<SharedPreferences> Function() _loadPreferences;

  Future<bool> isCompleted() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final preferences = await _loadPreferences();
    await preferences.setBool(completedKey, true);
  }
}
