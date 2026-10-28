import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tenant.dart';
import 'tenant_providers.dart';
import 'widgets/form_widgets.dart';

/// Create (tenantId == null) or edit a tenant profile.
class TenantFormScreen extends ConsumerWidget {
  const TenantFormScreen({super.key, this.tenantId});

  final String? tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tenantId == null) {
      return const _Scaffold(title: 'Thêm người thuê', child: _TenantForm());
    }
    final tenantAsync = ref.watch(tenantDetailProvider(tenantId!));
    return _Scaffold(
      title: 'Sửa người thuê',
      child: tenantAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(
          child:
              Text('$error', style: const TextStyle(color: Color(0xFF6B7280))),
        ),
        data: (tenant) => _TenantForm(existing: tenant),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _TenantForm extends ConsumerStatefulWidget {
  const _TenantForm({this.existing});
  final Tenant? existing;

  @override
  ConsumerState<_TenantForm> createState() => _TenantFormState();
}

class _TenantFormState extends ConsumerState<_TenantForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _idNumber;
  late final TextEditingController _note;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _name = TextEditingController(text: t?.fullName ?? '');
    _phone = TextEditingController(text: t?.phone ?? '');
    _idNumber = TextEditingController(text: t?.idNumber ?? '');
    _note = TextEditingController(text: t?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final draft = Tenant(
      id: widget.existing?.id ?? '',
      fullName: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      idNumber: _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    try {
      await ref.read(tenantFormControllerProvider.notifier).submit(
            existing: widget.existing,
            draft: draft,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error is ApiFailure
            ? error.message
            : 'Không thể lưu người thuê. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            FormErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _name,
            label: 'Họ tên',
            hint: 'Nguyễn Văn A',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _phone,
            label: 'Số điện thoại',
            hint: '+84901234567',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _idNumber,
            label: 'CCCD/CMND',
            hint: 'Tuỳ chọn',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _note,
            label: 'Ghi chú',
            hint: 'Tuỳ chọn',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SubmitButton(
            label: widget.existing == null ? 'Thêm người thuê' : 'Lưu thay đổi',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
