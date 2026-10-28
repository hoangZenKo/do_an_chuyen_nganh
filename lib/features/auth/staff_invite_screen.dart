import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../tenants/widgets/form_widgets.dart';
import 'auth_navigation.dart';
import 'auth_providers.dart';

class StaffInviteScreen extends ConsumerStatefulWidget {
  const StaffInviteScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<StaffInviteScreen> createState() => _StaffInviteScreenState();
}

class _StaffInviteScreenState extends ConsumerState<StaffInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session =
          await ref.read(sessionControllerProvider.notifier).acceptStaffInvite(
                inviteCode: _code.text.trim(),
                password: _password.text,
              );
      if (mounted) context.go(homeRouteForSession(session));
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
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(title: const Text('Kích hoạt nhân viên')),
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
              controller: _code,
              label: 'Mã mời',
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Nhập mã mời.' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              label: 'Mật khẩu mới',
              validator: (value) => value == null || value.length < 12
                  ? 'Tối thiểu 12 ký tự.'
                  : null,
            ),
            const SizedBox(height: 24),
            SubmitButton(
              label: 'Kích hoạt',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
