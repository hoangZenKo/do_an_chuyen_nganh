import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../onboarding/onboarding_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    // Wrap in Future() to delay provider modification until after the first
    // build frame — Riverpod does not allow mutating state inside initState.
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

    final state = ref.read(sessionControllerProvider);
    if (state.status == SessionStatus.authenticated && state.session != null) {
      context.go(homeRouteForSession(state.session!));
    } else {
      context.go(completed ? loginRoute : onboardingRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_startup);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: 480,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: compact ? 20 : 34,
                  ),
                  child: Column(
                    children: [
                      if (compact)
                        const SizedBox(height: 8)
                      else
                        const Spacer(flex: 3),
                      _HeroLogo(maxWidth: compact ? 286 : 360),
                      SizedBox(height: compact ? 18 : 28),
                      const _BrandName(),
                      SizedBox(height: compact ? 10 : 14),
                      const Text(
                        'RELIABLE  INVITING  EFFORTLESS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8F939C),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (compact)
                        const SizedBox(height: 42)
                      else
                        const Spacer(flex: 3),
                      const Text(
                        'Welcome Home',
                        style: TextStyle(
                          color: Color(0xFF007C78),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      const _LoadingBar(),
                      SizedBox(height: compact ? 14 : 20),
                      const _SecureConnection(),
                      if (compact)
                        const SizedBox(height: 8)
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final width = availableWidth < 260
            ? availableWidth
            : availableWidth.clamp(260.0, maxWidth).toDouble();

        return SizedBox(
          width: width,
          height: width * 0.94,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _HexagonBackdropPainter()),
              ),
              _LogoPanel(size: width * 0.62),
            ],
          ),
        );
      },
    );
  }
}

class _LogoPanel extends StatelessWidget {
  const _LogoPanel({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FCFA).withValues(alpha: 0.82),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(
          'assets/images/atrium_living_logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const Center(
            child: _MiniLogoWordmark(),
          ),
        ),
      ),
    );
  }
}

class _MiniLogoWordmark extends StatelessWidget {
  const _MiniLogoWordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0E213B),
          height: 1,
        ),
        children: [
          TextSpan(text: 'ATRIUM '),
          TextSpan(
            text: 'LIVING',
            style: TextStyle(color: Color(0xFF007C78)),
          ),
        ],
      ),
    );
  }
}

class _BrandName extends StatelessWidget {
  const _BrandName();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            color: Color(0xFF05070C),
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
          children: [
            TextSpan(text: 'Atrium '),
            TextSpan(
              text: 'Living',
              style: TextStyle(color: Color(0xFF007C78)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 4,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE4E8EE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 0.55),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return FractionallySizedBox(
                widthFactor: value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF007C78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SecureConnection extends StatelessWidget {
  const _SecureConnection();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, color: AppTheme.ink, size: 17),
        SizedBox(width: 8),
        Text(
          'SECURE CONNECTION',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HexagonBackdropPainter extends CustomPainter {
  const _HexagonBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide * 0.48;
    final innerRadius = size.shortestSide * 0.34;

    final outerPaint = Paint()
      ..color = const Color(0xFFEAF0F8).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    final innerPaint = Paint()
      ..color = const Color(0xFFF7F9FD).withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    canvas.drawPath(_hexagonPath(center, outerRadius), outerPaint);
    canvas.drawPath(_hexagonPath(center, innerRadius), innerPaint);
  }

  Path _hexagonPath(Offset center, double radius) {
    return Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.86, center.dy - radius * 0.5)
      ..lineTo(center.dx + radius * 0.86, center.dy + radius * 0.5)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.86, center.dy + radius * 0.5)
      ..lineTo(center.dx - radius * 0.86, center.dy - radius * 0.5)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
