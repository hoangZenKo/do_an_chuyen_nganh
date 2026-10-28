import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import 'auth_form.dart';
import 'auth_navigation.dart';
import 'auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _phoneValue(String? value) {
    final required = requiredValue(value, 'Phone');
    if (required != null) return required;
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value!.trim())) {
      return 'Use international format, e.g. +84901234567.';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions.'),
          backgroundColor: Color(0xFF0D6E62),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session =
          await ref.read(sessionControllerProvider.notifier).register(
                fullName: _name.text.trim(),
                email: _email.text.trim(),
                phone: _phone.text.trim(),
                password: _password.text,
              );
      if (mounted) context.go(homeRouteForSession(session));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiFailure
            ? error.message
            : 'Unable to create your account right now. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      // Header above the card
      showHeader: true,
      headerTitle: 'Join the Community',
      headerBody: 'Empower your property management\nwith premium tools.',
      onBack: _loading ? null : () => context.go(loginRoute),
      // No "Skip" on register
      cardTitle: 'Create Landlord Account',
      cardSubtitle: 'Fill in your details to start your journey.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Error banner ──────────────────────────────────────────
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // ── Full Name ─────────────────────────────────────────────
            AuthTextField(
              controller: _name,
              label: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => requiredValue(v, 'Full name'),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 16),

            // ── Email ─────────────────────────────────────────────────
            AuthTextField(
              controller: _email,
              label: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              validator: emailValue,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),

            // ── Phone ─────────────────────────────────────────────────
            AuthTextField(
              controller: _phone,
              label: 'Phone Number',
              hintText: '+1 (555) 000-0000',
              prefixIcon: Icons.phone_outlined,
              validator: _phoneValue,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 16),

            // ── Password ──────────────────────────────────────────────
            AuthTextField(
              controller: _password,
              label: 'Password',
              hintText: 'Create a strong password',
              prefixIcon: Icons.lock_outline_rounded,
              validator: passwordValue,
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),

            // ── Confirm password ──────────────────────────────────────
            AuthTextField(
              controller: _confirmPassword,
              label: 'Confirm Password',
              hintText: 'Re-enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) {
                final required = requiredValue(value, 'Confirm password');
                if (required != null) return required;
                if (value != _password.text) return 'Passwords do not match.';
                return null;
              },
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 20),

            // ── Terms checkbox ────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreeToTerms,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _agreeToTerms = v ?? false),
                    activeColor: const Color(0xFF0D6E62),
                    side:
                        const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF374151), height: 1.5),
                      children: [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: Color(0xFF0D6E62),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: '\nand '),
                        TextSpan(
                          text: 'Privacy Policy.',
                          style: TextStyle(
                            color: Color(0xFF0D6E62),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────────────
            AuthSubmitButton(
              label: 'Create Landlord Account',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 20),

            // ── Login link ────────────────────────────────────────────
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have a landlord account? ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                  TealTextButton(
                    label: 'Log In',
                    onPressed: () => context.go(loginRoute),
                    disabled: _loading,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
