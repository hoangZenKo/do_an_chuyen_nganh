import 'package:flutter/material.dart';

// ─── Brand colours ──────────────────────────────────────────────────────────
const Color _kTeal = Color(0xFF0D6E62);
const Color _kBg = Color(0xFFEEF4F6);
const Color _kCard = Color(0xFFFFFFFF);
const Color _kInk = Color(0xFF111827);
const Color _kMuted = Color(0xFF6B7280);
const Color _kBorder = Color(0xFFD1D5DB);

// ─── AuthScaffold ────────────────────────────────────────────────────────────

/// Generic scaffold shared by Login and Register screens.
///
/// [showHeader]  – when true, renders the logo + hero text above the card.
/// [headerTitle] – small subtitle above the card (e.g. "Join the Community").
/// [headerBody]  – paragraph below headerTitle.
/// [cardTitle]   – large title inside the white card.
/// [cardSubtitle]– smaller text inside the white card.
/// [form]        – the actual form content placed inside the card.
/// [footer]      – optional widget below the card (e.g. trust badges row).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    this.showHeader = true,
    this.headerTitle,
    this.headerBody,
    required this.cardTitle,
    this.cardSubtitle,
    required this.form,
    this.footer,
    this.onBack,
    this.onSkip,
    this.skipLabel,
  });

  final bool showHeader;
  final String? headerTitle;
  final String? headerBody;
  final String cardTitle;
  final String? cardSubtitle;
  final Widget form;
  final Widget? footer;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? skipLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: _kBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: onBack != null
                  ? IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.close, color: _kInk),
                    )
                  : const SizedBox.shrink(),
              actions: [
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      skipLabel ?? 'Skip',
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        // ── Header (logo + hero text) ─────────────────────
                        if (showHeader) ...[
                          const _AtriumLogo(),
                          const SizedBox(height: 16),
                          if (headerTitle != null)
                            Text(
                              headerTitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                                height: 1.2,
                              ),
                            ),
                          if (headerBody != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              headerBody!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _kMuted,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],

                        // ── White card ───────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!showHeader) ...[
                                const _AtriumLogo(size: 60),
                                const SizedBox(height: 20),
                              ],
                              Text(
                                cardTitle,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: _kInk,
                                  height: 1.2,
                                ),
                              ),
                              if (cardSubtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  cardSubtitle!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _kMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              form,
                            ],
                          ),
                        ),

                        // ── Footer ───────────────────────────────────────
                        if (footer != null) ...[
                          const SizedBox(height: 24),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo widget ─────────────────────────────────────────────────────────────

class _AtriumLogo extends StatelessWidget {
  const _AtriumLogo({this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = Image.asset(
      'assets/images/atrium_living_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.apartment_rounded,
        size: size * 0.7,
        color: _kTeal,
      ),
    );

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5F3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: asset),
        ),
        const SizedBox(height: 6),
        const Text(
          'ATRIUM LIVING',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: _kTeal,
          ),
        ),
      ],
    );
  }
}

// ─── AuthTextField ────────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onToggleObscure,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autofillHints: autofillHints,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: _kInk),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: _kMuted)
                : null,
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: _kMuted,
                    ),
                    tooltip: obscureText ? 'Show password' : 'Hide password',
                  ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kTeal, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
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
    this.icon,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color.fromRGBO(13, 110, 98, 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ],
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
  if (value!.length < 12 ||
      !RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'\d').hasMatch(value) ||
      !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return 'Use 12+ chars with upper/lowercase, a number, and a symbol.';
  }
  return null;
}

// ─── Trust badges ─────────────────────────────────────────────────────────────

class TrustBadgesRow extends StatelessWidget {
  const TrustBadgesRow({
    super.key,
    this.badges = const [
      (Icons.shield_outlined, 'SECURE ACCESS'),
      (Icons.headset_mic_outlined, '24/7 SUPPORT'),
    ],
  });

  final List<(IconData, String)> badges;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: badges
              .expand(
                (b) => [
                  Icon(b.$1, size: 14, color: _kMuted),
                  const SizedBox(width: 4),
                  Text(
                    b.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              )
              .toList()
            ..removeLast(),
        ),
        const SizedBox(height: 10),
        const Text(
          '© 2024 Atrium Living Management. All rights reserved.',
          style: TextStyle(fontSize: 11, color: _kMuted),
        ),
      ],
    );
  }
}

// ─── Teal text link ───────────────────────────────────────────────────────────

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
          color: disabled ? _kMuted : _kTeal,
        ),
      ),
    );
  }
}
