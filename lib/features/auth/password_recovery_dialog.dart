import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_failure.dart';
import '../../data/auth/auth_api.dart';
import 'auth_providers.dart';

final passwordRecoverySenderProvider =
    Provider<Future<String> Function(String)>(
        (ref) => AuthApi(ref.watch(dioProvider)).requestPasswordReset);

class PasswordRecoveryDialog extends ConsumerStatefulWidget {
  const PasswordRecoveryDialog({super.key, this.initialEmail = ''});
  final String initialEmail;
  @override
  ConsumerState<PasswordRecoveryDialog> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<PasswordRecoveryDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  int _seconds = 0;
  String? _message, _error;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0 || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message =
          await ref.read(passwordRecoverySenderProvider)(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _message = message;
        _seconds = 60;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _seconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _seconds = 0);
        } else {
          setState(() => _seconds--);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiFailure
            ? error.message
            : 'Không gửi được yêu cầu. Vui lòng thử lại sau.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Khôi phục mật khẩu'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Nhập email đăng nhập. Nếu tài khoản hợp lệ và kênh gửi khả dụng, bạn sẽ nhận được liên kết dùng một lần.'),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _email,
                              enabled: !_busy && _seconds == 0,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                              validator: (value) =>
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'Nhập email hợp lệ.'),
                          if (_message != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(_message!)),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Đóng')),
          FilledButton(
              onPressed: _busy || _seconds > 0 ? null : _send,
              child: Text(_busy
                  ? 'Đang gửi...'
                  : _seconds > 0
                      ? 'Gửi lại sau ${_seconds}s'
                      : 'Gửi hướng dẫn'))
        ],
      );
}
