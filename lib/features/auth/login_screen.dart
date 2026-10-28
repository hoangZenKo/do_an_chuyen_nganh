import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import 'auth_form.dart';
import 'auth_navigation.dart';
import 'auth_providers.dart';
import 'password_recovery_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _mfaCode = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _error;
  bool _mfaRequired = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _mfaCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref.read(sessionControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
            mfaCode: _mfaRequired ? _mfaCode.text : null,
          );
      if (mounted) {
        context.go(next != null && isPublicDiscoveryLocation(next)
            ? next
            : homeRouteForSession(session));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _mfaRequired = _mfaRequired ||
            (error is ApiFailure &&
                (error.code == 'MFA_REQUIRED' ||
                    error.code == 'INVALID_MFA_CODE'));
        _error = error is ApiFailure && error.code == 'MFA_REQUIRED'
            ? 'Admin cần mã xác thực hai lớp hoặc mã khôi phục.'
            : error is ApiFailure
                ? error.message
                : 'Unable to sign in right now. Please try again.';
      });
    }
  }

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => PasswordRecoveryDialog(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      cardTitle: 'Welcome Back',
      cardSubtitle: 'Log in to manage your Atrium Rooms.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error banner
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],

            // Email Field
            AuthTextField(
              controller: _email,
              hintText: 'Email address',
              prefixIcon: Icons.mail_outline_rounded,
              validator: emailValue,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),

            // Password Field
            AuthTextField(
              controller: _password,
              hintText: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) => requiredValue(value, 'Password'),
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
            ),
            if (_mfaRequired) ...[
              const SizedBox(height: 16),
              AuthTextField(
                controller: _mfaCode,
                hintText: 'Mã MFA hoặc mã khôi phục',
                prefixIcon: Icons.verified_user_outlined,
                keyboardType: TextInputType.visiblePassword,
                validator: (value) => requiredValue(value, 'Mã xác thực'),
              ),
            ],
            const SizedBox(height: 16),

            // Remember me & Forgot password row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Remember me
                InkWell(
                  onTap: _loading
                      ? null
                      : () => setState(() => _rememberMe = !_rememberMe),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: _loading
                                ? null
                                : (v) =>
                                    setState(() => _rememberMe = v ?? false),
                            activeColor: kAuthOrange,
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475467),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Forgot Password
                GestureDetector(
                  onTap: _loading ? null : _showForgotPasswordDialog,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 14,
                      color: kAuthOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Log In Button
            AuthSubmitButton(
              label: 'Log In',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 28),

            // Divider
            const AuthDivider(text: 'Or continue with'),
            const SizedBox(height: 20),

            // Social Buttons
            const SocialAuthButtons(),
            TextButton(
              onPressed: _loading ? null : () => context.go(exploreRoute),
              child: const Text('Khám phá phòng không cần đăng nhập'),
            ),
            const SizedBox(height: 28),

            // Footer: Don't have an account? Sign up
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: kAuthMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => context.go(registerRoute),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 14,
                        color: kAuthOrange,
                        fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
