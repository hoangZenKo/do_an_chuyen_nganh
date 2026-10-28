import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Brand Colors ────────────────────────────────────────────────────────────
const Color kAuthBg = Color(0xFFF4F6FA);
const Color kAuthCardBg = Color(0xFFFFFFFF);
const Color kAuthOrange = Color(0xFFFF6600);
const Color kAuthOrangeDeep = Color(0xFFE55C00);
const Color kAuthTitle = Color(0xFF0F172A);
const Color kAuthText = Color(0xFF1E293B);
const Color kAuthMuted = Color(0xFF64748B);
const Color kAuthInputBg = Color(0xFFF8FAFC);
const Color kAuthBorder = Color(0xFFE2E8F0);
const Color kAuthBorderFocused = Color(0xFFFF6600);
const Color kAuthError = Color(0xFFEF4444);

// ─── AuthScaffold ────────────────────────────────────────────────────────────

/// Clean, modern Card Scaffold for Auth screens matching the card design.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.form,
    this.showHeader = false,
    this.headerTitle,
    this.headerBody,
    this.footer,
    this.onBack,
    this.onSkip,
    this.skipLabel,
  });

  final String cardTitle;
  final String cardSubtitle;
  final Widget form;
  final bool showHeader;
  final String? headerTitle;
  final String? headerBody;
  final Widget? footer;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 380;

    return Scaffold(
      backgroundColor: kAuthBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Top Action Bar (Back / Skip if present) ─────────────────
                  if (onBack != null || onSkip != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (onBack != null)
                            IconButton(
                              onPressed: onBack,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: kAuthTitle,
                              ),
                              tooltip: 'Back',
                            )
                          else
                            const SizedBox.shrink(),
                          if (onSkip != null)
                            TextButton(
                              onPressed: onSkip,
                              child: Text(
                                skipLabel ?? 'Skip',
                                style: const TextStyle(
                                  color: kAuthMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ── Main Card ──────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 20 : 28,
                      vertical: isNarrow ? 28 : 34,
                    ),
                    decoration: BoxDecoration(
                      color: kAuthCardBg,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                          blurRadius: 36,
                          spreadRadius: 0,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Card Title
                        Text(
                          cardTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isNarrow ? 26 : 30,
                            fontWeight: FontWeight.w900,
                            color: kAuthTitle,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Card Subtitle
                        Text(
                          cardSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: kAuthMuted,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Form content
                        form,
                      ],
                    ),
                  ),

                  // ── Optional Footer ─────────────────────────────────────────
                  if (footer != null) ...[
                    const SizedBox(height: 20),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AuthTextField ────────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hintText,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onToggleObscure,
    this.autofillHints,
    this.helperText,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final Iterable<String>? autofillHints;
  final String? helperText;
  final AutovalidateMode autovalidateMode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kAuthTitle,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autofillHints: autofillHints,
          validator: validator,
          autovalidateMode: autovalidateMode,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: kAuthText,
          ),
          decoration: InputDecoration(
            helperText: helperText,
            helperMaxLines: 3,
            helperStyle: const TextStyle(color: kAuthMuted, fontSize: 12),
            errorMaxLines: 4,
            errorStyle:
                const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            hintText: hintText,
            hintStyle: const TextStyle(
              color: kAuthMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(prefixIcon, size: 20, color: const Color(0xFF475467)),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 48),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: kAuthMuted,
                    ),
                    tooltip: obscureText ? 'Show password' : 'Hide password',
                  ),
            filled: true,
            fillColor: kAuthInputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kAuthBorder, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kAuthBorderFocused, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kAuthError, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kAuthError, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── AuthSubmitButton ─────────────────────────────────────────────────────────

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kAuthOrange.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAuthOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kAuthOrange.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

// ─── AuthDivider ──────────────────────────────────────────────────────────────

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.text = 'Or continue with'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: kAuthBorder, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(
              color: kAuthMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: kAuthBorder, thickness: 1),
        ),
      ],
    );
  }
}

// ─── SocialAuthButtons ────────────────────────────────────────────────────────

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    this.onGooglePressed,
    this.onApplePressed,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: 'Google',
            icon: const _GoogleLogo(size: 19),
            onPressed: onGooglePressed ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Google Sign-In will be available soon.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SocialButton(
            label: 'Apple',
            icon: const Icon(
              Icons.apple,
              size: 22,
              color: kAuthTitle,
            ),
            onPressed: onApplePressed ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Apple Sign-In will be available soon.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: kAuthBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: kAuthTitle,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Google Logo Painter ─────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Blue arc (right + horizontal bar)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -math.pi * 0.18, math.pi * 0.38, false, bluePaint);

    // Red arc (top)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, -math.pi * 0.78, math.pi * 0.60, false, redPaint);

    // Yellow arc (left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, math.pi * 0.65, math.pi * 0.57, false, yellowPaint);

    // Green arc (bottom)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, math.pi * 0.18, math.pi * 0.47, false, greenPaint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - strokeWidth / 2, radius + 1, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Teal/Orange Text Button ─────────────────────────────────────────────────

class TealTextButton extends StatelessWidget {
  const TealTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: disabled ? kAuthMuted : kAuthOrange,
        ),
      ),
    );
  }
}

// ─── Validators ──────────────────────────────────────────────────────────────

String? requiredValue(String? value, String label) {
  if (value == null || value.trim().isEmpty) return '$label is required.';
  return null;
}

String? emailValue(String? value) {
  final required = requiredValue(value, 'Email');
  if (required != null) return required;
  final email = value!.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? passwordValue(String? value) {
  final required = requiredValue(value, 'Password');
  if (required != null) return required;
  if (value!.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  return null;
}

// ─── Trust badges (kept for backward compatibility if needed) ────────────────

class TrustBadgesRow extends StatelessWidget {
  const TrustBadgesRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
