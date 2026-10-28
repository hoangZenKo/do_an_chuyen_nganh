import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../auth/auth_providers.dart';
import '../tenants/widgets/form_widgets.dart';

class TenantChangePasswordScreen extends ConsumerStatefulWidget {
  const TenantChangePasswordScreen({super.key});

  @override
  ConsumerState<TenantChangePasswordScreen> createState() =>
      _TenantChangePasswordScreenState();
}

class _TenantChangePasswordScreenState
    extends ConsumerState<TenantChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đổi mật khẩu.')),
        );
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiFailure ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              FormErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _current,
              label: 'Mật khẩu hiện tại',
              validator: (value) =>
                  value == null || value.isEmpty ? 'Nhập mật khẩu hiện tại.' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _next,
              label: 'Mật khẩu mới',
              validator: (value) =>
                  value == null || value.length < 12 ? 'Tối thiểu 12 ký tự.' : null,
            ),
            const SizedBox(height: 24),
            SubmitButton(
              label: 'Đổi mật khẩu',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
