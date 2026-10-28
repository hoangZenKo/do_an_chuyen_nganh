import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/data/auth/auth_api.dart';
import 'package:rental_room_management/data/auth/auth_repository.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
import 'package:rental_room_management/data/onboarding/onboarding_preferences.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/onboarding/onboarding_providers.dart';
import 'package:rental_room_management/features/onboarding/onboarding_screen.dart';
import 'package:rental_room_management/features/splash/splash_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';

AuthSession _session(String role) {
  return AuthSession(
    user: LandlordUser(
      id: 'u1',
      fullName: 'Test User',
      email: 'test@example.com',
      role: role,
    ),
    accessToken: 'access',
    refreshToken: 'refresh',
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.session)
      : super(
          api: AuthApi(Dio()),
          storage: SecureSessionStorage(storage: const FlutterSecureStorage()),
        );

  final AuthSession? session;

  @override
  Future<AuthSession?> restore() async => session;
}

class _FakeOnboardingPreferences extends OnboardingPreferences {
  _FakeOnboardingPreferences({this.completed = false});

  bool completed;
  int marks = 0;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    marks += 1;
    completed = true;
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: splashRoute,
    routes: [
      GoRoute(path: splashRoute, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: onboardingRoute, builder: (_, __) => const Text('onboarding')),
      GoRoute(path: loginRoute, builder: (_, __) => const Text('login')),
      GoRoute(
          path: dashboardRoute, builder: (_, __) => const Text('dashboard')),
      GoRoute(path: adminRoute, builder: (_, __) => const Text('admin')),
    ],
  );
}

Future<void> _pumpSplash(
  WidgetTester tester, {
  required AuthSession? session,
  required bool onboardingCompleted,
}) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(session)),
        onboardingPreferencesProvider.overrideWithValue(
          _FakeOnboardingPreferences(completed: onboardingCompleted),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash sends unauthenticated incomplete users to onboarding',
      (tester) async {
    await _pumpSplash(
      tester,
      session: null,
      onboardingCompleted: false,
    );

    expect(find.text('onboarding'), findsOneWidget);
  });

  testWidgets('splash sends unauthenticated completed users to login',
      (tester) async {
    await _pumpSplash(
      tester,
      session: null,
      onboardingCompleted: true,
    );

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('splash sends authenticated users to their role home',
      (tester) async {
    await _pumpSplash(
      tester,
      session: _session('admin'),
      onboardingCompleted: false,
    );

    expect(find.text('admin'), findsOneWidget);
  });

  testWidgets('onboarding skip marks completed before login navigation',
      (tester) async {
    final preferences = _FakeOnboardingPreferences();
    final router = GoRouter(
      initialLocation: onboardingRoute,
      routes: [
        GoRoute(
            path: onboardingRoute,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: loginRoute, builder: (_, __) => const Text('login')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(preferences.marks, 1);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('onboarding close marks completed before login navigation',
      (tester) async {
    final preferences = _FakeOnboardingPreferences();
    final router = GoRouter(
      initialLocation: onboardingRoute,
      routes: [
        GoRoute(
            path: onboardingRoute,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: loginRoute, builder: (_, __) => const Text('login')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(preferences.marks, 1);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('onboarding create account marks completed before navigation',
      (tester) async {
    final preferences = _FakeOnboardingPreferences();
    final router = GoRouter(
      initialLocation: onboardingRoute,
      routes: [
        GoRoute(
            path: onboardingRoute,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: loginRoute, builder: (_, __) => const Text('login')),
        GoRoute(
            path: registerRoute, builder: (_, __) => const Text('register')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(preferences.marks, 1);
    expect(find.text('register'), findsOneWidget);
  });

  testWidgets('onboarding log in marks completed before navigation',
      (tester) async {
    final preferences = _FakeOnboardingPreferences();
    final router = GoRouter(
      initialLocation: onboardingRoute,
      routes: [
        GoRoute(
            path: onboardingRoute,
            builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: loginRoute, builder: (_, __) => const Text('login')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(preferences.marks, 1);
    expect(find.text('login'), findsOneWidget);
  });
}
