import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../onboarding/onboarding_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _image =
      'assets/images/ChatGPT Image Aug 19, 2026, 02_08_52 AM.png';
  static const _forceOnboarding = bool.fromEnvironment('FORCE_ONBOARDING');

  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = Future(_restoreAndNavigate);
  }

  Future<void> _restoreAndNavigate() async {
    final onboardingCompleted =
        ref.read(onboardingCompletedProvider.future).catchError((_) => true);
    await Future.wait([
      ref.read(sessionControllerProvider.notifier).restore(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
    final completed = await onboardingCompleted;
    if (!mounted) return;

    if (_forceOnboarding) {
      context.go(onboardingRoute);
      return;
    }

    final state = ref.read(sessionControllerProvider);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    if (next != null && isPublicDiscoveryLocation(next)) {
      context.go(next);
      return;
    }
    if (state.status == SessionStatus.authenticated && state.session != null) {
      context.go(homeRouteForSession(state.session!));
    } else {
      context.go(completed ? exploreRoute : onboardingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_startup);
    return const Scaffold(
      backgroundColor: Color(0xFF020B17),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetImage(_image),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          _EdgeShade(),
        ],
      ),
    );
  }
}

class _EdgeShade extends StatelessWidget {
  const _EdgeShade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x44020B17),
            Color(0x00020B17),
            Color(0x55020B17),
          ],
          stops: [0, 0.5, 1],
        ),
      ),
    );
  }
}
