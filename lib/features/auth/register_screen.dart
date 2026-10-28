import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import 'account_access_link.dart';
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
  final _errorKey = GlobalKey();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _seeker = true;
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
    final phone = _normalizedPhone(value ?? '');
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại.';
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone) ||
        (phone.startsWith('+84') &&
            !RegExp(r'^\+84(?:[35789][0-9]{8}|2[0-9]{9})$').hasMatch(phone))) {
      return 'Nhập số Việt Nam hợp lệ (vd. 0901234567) hoặc số có mã quốc gia.';
    }
    return null;
  }

  String _normalizedPhone(String value) {
    final phone = value.replaceAll(RegExp(r'[\s().-]'), '');
    if (RegExp(r'^0(?:[35789][0-9]{8}|2[0-9]{9})$').hasMatch(phone)) {
      return '+84${phone.substring(1)}';
    }
    return phone;
  }

  String _registrationError(Object error) {
    if (error is! ApiFailure) {
      return 'Chưa thể hoàn tất đăng ký. Vui lòng thử lại sau.';
    }
    if (error.code == 'EMAIL_ALREADY_REGISTERED') {
      return 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.';
    }
    if (error.statusCode == 429) {
      return 'Bạn đã thử đăng ký quá nhiều lần. Vui lòng đợi một phút rồi thử lại.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      final reference = error.requestId;
      return 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.'
          '${reference == null ? '' : ' Mã hỗ trợ: $reference.'}';
    }
    return error.message;
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Conditions.'),
          backgroundColor: kAuthOrange,
          behavior: SnackBarBehavior.floating,
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
                seeker: _seeker,
                fullName: _name.text.trim(),
                email: _email.text.trim(),
                phone: _normalizedPhone(_phone.text),
                password: _password.text,
              );
      if (mounted) context.go(homeRouteForSession(session));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _registrationError(error);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final errorContext = _errorKey.currentContext;
        if (errorContext != null) {
          Scrollable.ensureVisible(errorContext,
              duration: const Duration(milliseconds: 250));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      cardTitle: 'Create Account',
      cardSubtitle: 'Tìm phòng mới hoặc quản lý khu trọ của bạn.',
      onBack: _loading ? null : () => context.go(loginRoute),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn muốn sử dụng ứng dụng để',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kAuthTitle,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<bool>(
              value: _seeker,
              isExpanded: true,
              dropdownColor: kAuthCardBg,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: kAuthMuted),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kAuthText,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: kAuthInputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kAuthBorder, width: 1.2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kAuthBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: kAuthBorderFocused, width: 1.8),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: true,
                  child:
                      Text('Tìm thuê phòng', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: false,
                  child:
                      Text('Quản lý nhà trọ', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged:
                  _loading ? null : (value) => setState(() => _seeker = value!),
            ),
            const SizedBox(height: 20),
            // Full Name
            AuthTextField(
              controller: _name,
              hintText: 'Full name',
              prefixIcon: Icons.person_outline_rounded,
              validator: (value) {
                final name = (value ?? '').trim();
                if (name.isEmpty) return 'Vui lòng nhập họ tên.';
                if (name.length > 120) return 'Họ tên không quá 120 ký tự.';
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 16),

            // Email
            AuthTextField(
              controller: _email,
              hintText: 'Email address',
              prefixIcon: Icons.mail_outline_rounded,
              validator: emailValue,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),

            // Phone
            AuthTextField(
              controller: _phone,
              hintText: 'Phone number',
              prefixIcon: Icons.phone_outlined,
              validator: _phoneValue,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              helperText: 'Nhập 0901234567 hoặc +84901234567.',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 16),

            // Password
            AuthTextField(
              controller: _password,
              hintText: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              validator: accountPasswordValidation,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              helperText:
                  'Mật khẩu 12–128 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt.',
              onChanged: (_) => setState(() {}),
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),

            // Confirm Password
            AuthTextField(
              controller: _confirmPassword,
              hintText: 'Confirm password',
              prefixIcon: Icons.lock_reset_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập lại mật khẩu.';
                }
                if (value != _password.text) {
                  return 'Mật khẩu xác nhận không khớp.';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 18),

            // Terms & Conditions Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreeToTerms,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _agreeToTerms = v ?? false),
                    activeColor: kAuthOrange,
                    side: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475467),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text('Terms & Conditions'),
                              content: const Text(
                                'By using Atrium Rooms, you agree to our standard terms of property management and service operations.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 13,
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
            const SizedBox(height: 24),

            if (_error != null) ...[
              Semantics(
                key: _errorKey,
                liveRegion: true,
                child: _ErrorBanner(message: _error!),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            AuthSubmitButton(
              label: 'Sign Up',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 28),

            // Divider & Social login
            const AuthDivider(text: 'Or sign up with'),
            const SizedBox(height: 20),
            const SocialAuthButtons(),
            const SizedBox(height: 28),

            // Footer: Already have an account? Log in
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: kAuthMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : () => context.go(loginRoute),
                    child: const Text(
                      'Log in',
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
