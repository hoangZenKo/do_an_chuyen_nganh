import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeAndGo(String route) async {
    try {
      await ref.read(onboardingPreferencesProvider).markCompleted();
    } finally {
      if (mounted) context.go(route);
    }
  }

  Future<void> _finish() => _completeAndGo('/auth/login');

  Future<void> _openRegister() => _completeAndGo('/auth/register');

  Future<void> _openLogin() => _completeAndGo('/auth/login');

  void _next() {
    if (_currentPage == _pageCount - 1) {
      _finish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_currentPage == 0) return;

    _controller.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              pageIndex: _currentPage,
              onClose: () => _finish(),
              onSkip: () => _finish(),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: const [
                  _InfoPage(
                    visual: _PropertyIllustration(),
                    badge: 'Onboarding 01',
                    title: 'Find Your Perfect\nSpace',
                    description:
                        'Explore a curated selection of premium rooms in prime locations. We handle the logistics so you can feel at home.',
                  ),
                  _InfoPage(
                    visual: _BookingIllustration(),
                    title: 'Seamless Paperless\nBooking',
                    description:
                        'Book your room in minutes with our fully digital process.',
                  ),
                  _InfoPage(
                    visual: _ManagementIllustration(),
                    title: 'Manage with Ease',
                    description:
                        'Track rent, requests, messages, and room status from one calm, organized workspace.',
                  ),
                  _WelcomePage(),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _currentPage == _pageCount - 1
                  ? _AuthActions(
                      key: const ValueKey('auth-actions'),
                      currentPage: _currentPage,
                      pageCount: _pageCount,
                      onCreateAccount: () => _openRegister(),
                      onLogin: () => _openLogin(),
                    )
                  : _StepActions(
                      key: const ValueKey('step-actions'),
                      currentPage: _currentPage,
                      pageCount: _pageCount,
                      onPrevious: _previous,
                      onNext: _next,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pageIndex,
    required this.onClose,
    required this.onSkip,
  });

  final int pageIndex;
  final VoidCallback onClose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 390;
    final showTitleOnLeft = pageIndex == 0 || pageIndex == 3;
    final titleStyle = TextStyle(
      color: Colors.black,
      fontSize: narrow ? 25 : 31,
      fontWeight: FontWeight.w900,
      height: 1,
    );

    return SizedBox(
      height: narrow ? 72 : 84,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: showTitleOnLeft
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Atrium Living', style: titleStyle),
                    )
                  : IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                      iconSize: narrow ? 30 : 34,
                      color: Colors.black,
                      tooltip: 'Close',
                    ),
            ),
            if (!showTitleOnLeft)
              Text(
                'Atrium Living',
                style: titleStyle,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B3B43),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(56, 44),
                  textStyle: TextStyle(
                    fontSize: narrow ? 15 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Skip'),
                    if (pageIndex == 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.close_rounded, size: narrow ? 22 : 27),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.visual,
    required this.title,
    required this.description,
    this.badge,
  });

  final Widget visual;
  final String title;
  final String description;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 390;
        final compact = constraints.maxHeight < 640;
        final visualHeight = (constraints.maxHeight * (compact ? 0.36 : 0.43))
            .clamp(210.0, 340.0)
            .toDouble();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 22 : 30,
                compact ? 8 : 28,
                narrow ? 22 : 30,
                24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: visualHeight, child: visual),
                  SizedBox(height: compact ? 18 : 28),
                  if (badge != null) ...[
                    _Badge(text: badge!),
                    SizedBox(height: compact ? 18 : 26),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: narrow ? 28 : 32,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF4D4D56),
                      fontSize: narrow ? 16 : 18,
                      fontWeight: FontWeight.w400,
                      height: 1.48,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 390;
        final compact = constraints.maxHeight < 560;
        final logoHeight = (constraints.maxHeight * (compact ? 0.27 : 0.34))
            .clamp(140.0, 260.0)
            .toDouble();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 26 : 44,
                compact ? 8 : 24,
                narrow ? 26 : 44,
                20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: logoHeight,
                    child: const _LogoIllustration(),
                  ),
                  SizedBox(height: compact ? 18 : 30),
                  Text(
                    'Welcome to Atrium\nLiving',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: narrow ? 28 : 32,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 26),
                  Text(
                    'Your journey to a better living experience starts here. Discover premium spaces managed with care and precision.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF4D4D56),
                      fontSize: narrow ? 16 : 18,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF83E7DD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF007C70),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StepActions extends StatelessWidget {
  const _StepActions({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SizedBox(
      height: narrow ? 112 : 132,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(narrow ? 22 : 36, 10, narrow ? 22 : 28, 18),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _Dots(currentPage: currentPage, pageCount: pageCount),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _PreviousButton(
                enabled: currentPage > 0,
                onPressed: onPrevious,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _NextButton(onPressed: onNext),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthActions extends StatelessWidget {
  const _AuthActions({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 36 : 72, 8, narrow ? 36 : 72, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FullWidthButton(
            label: 'Create Account',
            icon: Icons.arrow_forward_rounded,
            backgroundColor: AppTheme.ink,
            height: narrow ? 48 : 52,
            onPressed: onCreateAccount,
          ),
          const SizedBox(height: 10),
          _FullWidthButton(
            label: 'Log In',
            icon: Icons.login_rounded,
            backgroundColor: const Color(0xFF007C70),
            height: narrow ? 48 : 52,
            onPressed: onLogin,
          ),
          const SizedBox(height: 24),
          _Dots(currentPage: currentPage, pageCount: pageCount),
          const SizedBox(height: 14),
          const _HelpPill(),
        ],
      ),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.height,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: narrow ? 20 : 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: backgroundColor.withValues(alpha: 0.22),
          textStyle: TextStyle(
            fontSize: narrow ? 14 : 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _PreviousButton extends StatelessWidget {
  const _PreviousButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;
    final color = enabled ? const Color(0xFF71757E) : const Color(0xFFB8BAC1);

    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: color,
        padding: EdgeInsets.zero,
      ),
      icon: Icon(Icons.arrow_back_rounded, size: narrow ? 27 : 32),
      label: Text(
        'Previous',
        style: TextStyle(
          fontSize: narrow ? 15 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return SizedBox(
      width: narrow ? 132 : 160,
      height: narrow ? 48 : 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007C70),
          foregroundColor: Colors.white,
          elevation: 10,
          shadowColor: const Color(0xFF007C70).withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: TextStyle(
            fontSize: narrow ? 14 : 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Next'),
            SizedBox(width: narrow ? 6 : 8),
            Icon(Icons.arrow_forward_rounded, size: narrow ? 20 : 22),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.currentPage,
    required this.pageCount,
  });

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final active = index == currentPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: active ? 54 : 13,
          height: 13,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF007C70) : const Color(0xFFC5C7CD),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _HelpPill extends StatelessWidget {
  const _HelpPill();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Container(
      width: double.infinity,
      height: narrow ? 58 : 70,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline_rounded,
            color: const Color(0xFF007C70),
            size: narrow ? 26 : 32,
          ),
          SizedBox(width: narrow ? 12 : 18),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Need help getting started?',
                style: TextStyle(
                  color: const Color(0xFF3F4047),
                  fontSize: narrow ? 15 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyIllustration extends StatelessWidget {
  const _PropertyIllustration();

  @override
  Widget build(BuildContext context) {
    return const _ScaledVisual(
      width: 360,
      height: 260,
      child: Stack(
        children: [
          _RoomCard(),
          Positioned(
            left: 24,
            bottom: 24,
            child: _VerifiedPropertyCard(),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: const CustomPaint(
        painter: _RoomPainter(),
        size: Size(360, 260),
      ),
    );
  }
}

class _VerifiedPropertyCard extends StatelessWidget {
  const _VerifiedPropertyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: Color(0xFF007C70),
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verified Property',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Kensington, London',
                  style: TextStyle(
                    color: Color(0xFF7D7F88),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingIllustration extends StatelessWidget {
  const _BookingIllustration();

  @override
  Widget build(BuildContext context) {
    return const _ScaledVisual(
      width: 360,
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(child: _SoftTealGlow()),
          Positioned(
            left: 78,
            top: 24,
            child: _DocumentMockup(),
          ),
          Positioned(
            right: 10,
            top: 48,
            child: _BookingSentCard(),
          ),
          Positioned(
            left: 4,
            bottom: 8,
            child: _PhoneMockup(),
          ),
        ],
      ),
    );
  }
}

class _DocumentMockup extends StatelessWidget {
  const _DocumentMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      height: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Line(width: 130, height: 16, color: Color(0xFFD4E5FC)),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (index) {
              return Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: index == 3
                      ? const Color(0xFF83E7DD)
                      : const Color(0xFFE7EFFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: index == 3
                    ? const Center(
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(0xFF007C70),
                        ),
                      )
                    : null,
              );
            }),
          ),
          const SizedBox(height: 16),
          const _Line(width: 180, height: 9),
          const SizedBox(height: 8),
          const _Line(width: 160, height: 9),
          const SizedBox(height: 8),
          const _Line(width: 120, height: 9),
          const Spacer(),
          const Divider(color: Color(0xFFD5D7DE)),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tenant A.L.',
              style: TextStyle(
                color: Color(0xFF007C70),
                fontSize: 21,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingSentCard extends StatelessWidget {
  const _BookingSentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF007C70),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Booking Sent',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Instant confirmation',
                  style: TextStyle(
                    color: Color(0xFF8A8D96),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 196,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const CustomPaint(
          painter: _PhonePainter(),
        ),
      ),
    );
  }
}

class _ManagementIllustration extends StatelessWidget {
  const _ManagementIllustration();

  @override
  Widget build(BuildContext context) {
    return const _ScaledVisual(
      width: 360,
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _SoftTealGlow()),
          _DashboardMockup(),
        ],
      ),
    );
  }
}

class _DashboardMockup extends StatelessWidget {
  const _DashboardMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 284,
      height: 340,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(42),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning,',
                        style: TextStyle(
                          color: Color(0xFF737782),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Alex Chen',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF83E7DD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF007C70),
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 64,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$1,450.00',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Due in 24 days',
                            style: TextStyle(
                              color: Color(0xFF9CA2B2),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _PaidPill(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(
                  child: _SmallDashboardTile(
                    title: 'Requests',
                    subtitle: '2 Active',
                    icon: Icons.handyman_rounded,
                    filled: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SmallDashboardTile(
                    title: 'Chat',
                    subtitle: 'No msgs',
                    icon: Icons.chat_bubble_outline_rounded,
                    filled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FC),
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                  left: BorderSide(color: Color(0xFF007C70), width: 4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    color: Color(0xFF007C70),
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Leaking Faucet - Plumber 2:00 PM',
                        style: TextStyle(
                          color: Color(0xFF444751),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  const _PaidPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF007C70),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'PAID',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallDashboardTile extends StatelessWidget {
  const _SmallDashboardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.filled,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFDDE9FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: filled ? null : Border.all(color: const Color(0xFFD5D7DE)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color:
                    filled ? const Color(0xFF007C70) : const Color(0xFF555861),
                size: 16,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF737782),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoIllustration extends StatelessWidget {
  const _LogoIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8BE7E0).withValues(alpha: 0.25),
                blurRadius: 90,
                spreadRadius: 24,
              ),
            ],
          ),
        ),
        Image.asset(
          'assets/images/atrium_living_logo.png',
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

class _ScaledVisual extends StatelessWidget {
  const _ScaledVisual({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );
  }
}

class _SoftTealGlow extends StatelessWidget {
  const _SoftTealGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.82,
          colors: [
            const Color(0xFFDDF8F6).withValues(alpha: 0.86),
            const Color(0xFFF8F9FD).withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.width,
    required this.height,
    this.color = const Color(0xFFEFF3FB),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8EEF8),
          Color(0xFFF7F0E8),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wallPaint);

    final windowPaint = Paint()..color = const Color(0xFFC9D9E8);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.04, size.height * 0.08, size.width * 0.25,
          size.height * 0.46),
      windowPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.36, size.height * 0.09, size.width * 0.16,
          size.height * 0.38),
      windowPaint,
    );

    final floorPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE8DCC8),
          Color(0xFFCBA779),
        ],
      ).createShader(Rect.fromLTWH(
        0,
        size.height * 0.56,
        size.width,
        size.height * 0.44,
      ));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.56, size.width, size.height * 0.44),
      floorPaint,
    );

    final headboardPaint = Paint()..color = const Color(0xFF5C4739);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.35, size.width * 0.34,
            size.height * 0.16),
        const Radius.circular(10),
      ),
      headboardPaint,
    );

    final bedPaint = Paint()..color = const Color(0xFFF0ECE5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.29, size.height * 0.42, size.width * 0.43,
            size.height * 0.25),
        const Radius.circular(14),
      ),
      bedPaint,
    );

    final blanketPaint = Paint()..color = const Color(0xFFB8AEA3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.50, size.height * 0.48, size.width * 0.22,
            size.height * 0.19),
        const Radius.circular(12),
      ),
      blanketPaint,
    );

    final dresserPaint = Paint()..color = const Color(0xFFB88A5D);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.78, size.height * 0.46, size.width * 0.18,
          size.height * 0.22),
      dresserPaint,
    );

    final chairPaint = Paint()..color = const Color(0xFF14233C);
    canvas.drawCircle(
      Offset(size.width * 0.07, size.height * 0.66),
      size.width * 0.08,
      chairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhonePainter extends CustomPainter {
  const _PhonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD7C4AA),
          Color(0xFF101828),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final cardPaint = Paint()..color = Colors.white.withValues(alpha: 0.94);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.17, size.height * 0.07, size.width * 0.66,
            size.height * 0.84),
        const Radius.circular(16),
      ),
      cardPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFDDE8EF)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < 5; index += 1) {
      final y = size.height * (0.20 + index * 0.09);
      canvas.drawLine(
        Offset(size.width * 0.28, y),
        Offset(size.width * (index.isEven ? 0.72 : 0.62), y),
        linePaint,
      );
    }

    final signPaint = Paint()
      ..color = const Color(0xFF007C70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.29, size.height * 0.57, size.width * 0.40,
            size.height * 0.13),
        const Radius.circular(5),
      ),
      signPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
