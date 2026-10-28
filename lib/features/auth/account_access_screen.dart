import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/auth/auth_api.dart';
import 'auth_navigation.dart';
import 'account_access_link.dart';
import 'password_recovery_dialog.dart';
import 'auth_providers.dart';

class AccountAccessScreen extends ConsumerStatefulWidget {
  const AccountAccessScreen({super.key, this.token});
  final String? token;
  @override
  ConsumerState<AccountAccessScreen> createState() =>
      _AccountAccessScreenState();
}

class _AccountAccessScreenState extends ConsumerState<AccountAccessScreen> {
  final _form = GlobalKey<FormState>();
  late final _token = TextEditingController(text: widget.token);
  final _password = TextEditingController(), _confirm = TextEditingController();
  bool _busy = false, _done = false;
  String? _error;
  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthApi(ref.read(dioProvider))
          .redeemAccountAccess(_token.text.trim(), _password.text);
      await ref.read(sessionControllerProvider.notifier).logout();
      if (mounted) {
        setState(() {
          _done = true;
          _token.clear();
          _password.clear();
          _confirm.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Liên kết không hợp lệ, hết hạn, đã dùng hoặc dịch vụ chưa khả dụng. Bạn có thể yêu cầu liên kết khôi phục mới.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Đặt mật khẩu tài khoản')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _done
                      ? Column(children: [
                          const Text(
                              'Mật khẩu đã được cập nhật. Vui lòng đăng nhập lại.'),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: () => context.go(loginRoute),
                              child: const Text('Đăng nhập'))
                        ])
                      : Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    'Dùng liên kết trong lời mời hoặc email khôi phục. Mỗi liên kết chỉ dùng một lần trong 30 phút.'),
                                const SizedBox(height: 20),
                                if (_error != null)
                                  Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                TextFormField(
                                    controller: _token,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Mã từ liên kết'),
                                    validator: (value) =>
                                        (value?.trim().length ?? 0) < 32
                                            ? 'Mã không hợp lệ.'
                                            : null),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    maxLength: 128,
                                    decoration: const InputDecoration(
                                        labelText: 'Mật khẩu mới'),
                                    validator: accountPasswordValidation),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _confirm,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Nhập lại mật khẩu'),
                                    validator: (value) =>
                                        value != _password.text
                                            ? 'Mật khẩu không khớp.'
                                            : null),
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: Text(_busy
                                        ? 'Đang cập nhật…'
                                        : 'Đặt mật khẩu')),
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => showDialog<void>(
                                            context: context,
                                            builder: (_) =>
                                                const PasswordRecoveryDialog()),
                                    child: const Text(
                                        'Yêu cầu liên kết khôi phục mới')),
                              ]))))));
}
