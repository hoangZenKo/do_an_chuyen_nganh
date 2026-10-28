import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'onboarding_providers.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F0F12);
const _kOrange = Color(0xFFFF6B1A);
const _kOrangeDeep = Color(0xFFE05500);
const _kTextPrimary = Color(0xFFFFFFFF);
const _kTextSecondary = Color(0xFFB0B3BF);
const _kDotInactive = Color(0xFF3A3B44);

// ─── Page data ────────────────────────────────────────────────────────────────
class _PageSpec {
  const _PageSpec({
    required this.image,
    required this.title,
    required this.subtitle,
  });
  final String image;
  final String title;
  final String subtitle;
}

const _pages = [
  _PageSpec(
    image: 'assets/images/a_high_quality_architectural_photograph_of_a_modern_luxury_apartment_building (1).png',
    title: 'Manage your\nrooms with ease',
    subtitle: 'Track rooms, tenants, leases,\nand payments all in one place.',
  ),
  _PageSpec(
    image: 'assets/images/rooms/room_07.jpeg',
    title: 'Smart payment\ntracking',
    subtitle: 'Monitor rent collection, send\ninvoices and get paid faster.',
  ),
  _PageSpec(
    image: 'assets/images/rooms/room_08.jpeg',
    title: 'Stay connected\nwith tenants',
    subtitle: 'Send notifications, manage\nrequests and resolve issues fast.',
  ),
  _PageSpec(
    image: 'assets/images/rooms/room_09.jpeg',
    title: 'Ready to get\nstarted?',
    subtitle: 'Create your account or log in\nto manage your rental business.',
  ),
];

// ─── Root widget ──────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() => _finishTo('/auth/login');

  Future<void> _finishTo(String route) async {
    try {
      await ref.read(onboardingPreferencesProvider).markCompleted();
    } finally {
      if (mounted) context.go(route);
    }
  }

  void _next() {
    if (_current == _pages.length - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    _fadeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            // ── Full-screen photo PageView ──────────────────────────────────
            SizedBox.expand(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _PhotoPage(spec: _pages[index]);
                },
              ),
            ),

            // ── Top gradient (status bar readability) ──────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 200,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kBg.withValues(alpha: 0.78),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── App icon + name ─────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 80, 0),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E26),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _kOrange.withValues(alpha: 0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: _kOrange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Atrium Rooms',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Skip and close actions ──────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                      message: 'Close',
                      child: IconButton(
                        onPressed: _finish,
                        color: Colors.white.withValues(alpha: 0.75),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.75),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),


            // ── Bottom content panel ────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomPanel(
                spec: _pages[_current],
                current: _current,
                total: _pages.length,
                fadeAnim: _fadeAnim,
                onNext: _next,
                onLogin: _finish,
                onCreateAccount: () => _finishTo('/auth/register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Photo page ───────────────────────────────────────────────────────────────
class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.spec});
  final _PageSpec spec;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Actual photo
        Image.asset(
          spec.image,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A2035)),
        ),
        // Subtle dark vignette
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.50),
                _kBg.withValues(alpha: 0.92),
              ],
              stops: const [0.30, 0.55, 0.72, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom panel ─────────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.spec,
    required this.current,
    required this.total,
    required this.fadeAnim,
    required this.onNext,
    required this.onLogin,
    required this.onCreateAccount,
  });

  final _PageSpec spec;
  final int current;
  final int total;
  final Animation<double> fadeAnim;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 390;

    return Container(
      decoration: BoxDecoration(
        color: _kBg.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(
        narrow ? 24 : 28,
        22,
        narrow ? 24 : 28,
        bottomPadding + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF38393F),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Title with fade
          FadeTransition(
            opacity: fadeAnim,
            child: Text(
              spec.title,
              style: TextStyle(
                color: _kTextPrimary,
                fontSize: narrow ? 30 : 34,
                fontWeight: FontWeight.w800,
                height: 1.14,
                letterSpacing: -0.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle with fade
          FadeTransition(
            opacity: fadeAnim,
            child: Text(
              spec.subtitle,
              style: TextStyle(
                color: _kTextSecondary,
                fontSize: narrow ? 15 : 16,
                height: 1.55,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // CTA button
          if (current == total - 1) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLogin,
                    child: const Text('Log In'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onCreateAccount,
                    child: const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ] else
            _CTAButton(
              label: current >= total - 2 ? 'Get started' : 'Next',
              onPressed: onNext,
            ),

          const SizedBox(height: 22),

          // Dots
          Center(
            child: _DotIndicator(current: current, total: total),
          ),
        ],
      ),
    );
  }
}

// ─── CTA Button with spring press ────────────────────────────────────────────
class _CTAButton extends StatefulWidget {
  const _CTAButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _scale.reverse(),
        onTapUp: (_) {
          _scale.forward();
          widget.onPressed();
        },
        onTapCancel: () => _scale.forward(),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kOrange, _kOrangeDeep],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _kOrange.withValues(alpha: 0.40),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dot Indicator ────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: active ? 28 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? _kOrange : _kDotInactive,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
