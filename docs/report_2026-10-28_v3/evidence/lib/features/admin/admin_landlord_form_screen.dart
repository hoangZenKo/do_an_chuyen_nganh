import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import 'admin_providers.dart';
import 'admin_workspace_scaffold.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';

class AdminLandlordFormScreen extends ConsumerStatefulWidget {
  const AdminLandlordFormScreen({super.key, this.landlordId});

  final String? landlordId;

  @override
  ConsumerState<AdminLandlordFormScreen> createState() =>
      _AdminLandlordFormScreenState();
}

class _AdminLandlordFormScreenState
    extends ConsumerState<AdminLandlordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _prefilled = false;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (_owner == null ||
        identity != _owner ||
        rights.isLoading ||
        rights.hasError ||
        !rights.requireValue.has('admin.accounts.manage')) {
      return const AdminWorkspaceScaffold(
          title: 'Chủ trọ',
          location: adminLandlordFormRoute,
          canOpen: false,
          body: SizedBox.shrink());
    }
    final landlordId = widget.landlordId;
    final isEditing = landlordId != null;
    final async = ref.watch(adminLandlordFormControllerProvider);
    final detailAsync =
        isEditing ? ref.watch(adminLandlordDetailProvider(landlordId)) : null;

    detailAsync?.whenData((landlord) {
      if (_prefilled) return;
      _prefilled = true;
      _fullName.text = landlord.fullName;
      _email.text = landlord.email;
      _phone.text = landlord.phone ?? '';
    });

    return AdminWorkspaceScaffold(
      title: isEditing ? 'Chỉnh sửa chủ trọ' : 'Thêm chủ trọ',
      location: adminLandlordFormRoute,
      busy: async.isLoading,
      body: detailAsync?.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AdminOverviewTheme.blue),
            ),
            error: (error, _) => Center(child: Text('$error')),
            data: (_) => _FormBody(
              formKey: _formKey,
              fullName: _fullName,
              email: _email,
              phone: _phone,
              password: _password,
              isEditing: isEditing,
              loading: async.isLoading,
              error: async.error,
              onSubmit: () => _submit(context, landlordId),
            ),
          ) ??
          _FormBody(
            formKey: _formKey,
            fullName: _fullName,
            email: _email,
            phone: _phone,
            password: _password,
            isEditing: isEditing,
            loading: async.isLoading,
            error: async.error,
            onSubmit: () => _submit(context, landlordId),
          ),
    );
  }

  Future<void> _submit(BuildContext context, String? landlordId) async {
    final rights = ref.read(adminCapabilitiesProvider);
    if (_owner == null ||
        ref.read(sessionIdentityProvider) != _owner ||
        rights.isLoading ||
        rights.valueOrNull?.has('admin.accounts.manage') != true) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(adminLandlordFormControllerProvider.notifier).submit(
            landlordId: landlordId,
            fullName: _fullName.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
          );
      if (context.mounted) context.pop();
    } catch (_) {
      // Provider state renders the error banner.
    }
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.formKey,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.isEditing,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullName;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final bool isEditing;
  final bool loading;
  final Object? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: fullName,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                readOnly: isEditing,
                validator: isEditing ? null : _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                keyboardType: TextInputType.phone,
              ),
              if (isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Giá trị có dấu * được giữ nguyên. Nhập đầy đủ số mới nếu cần thay đổi; xóa trống để bỏ số điện thoại.'),
                ),
              if (!isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  validator: _required,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          child: Text(loading
              ? 'Đang lưu…'
              : isEditing
                  ? 'Lưu thay đổi'
                  : 'Tạo chủ trọ'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Semantics(
              liveRegion: true,
              child: Text('$error',
                  style: const TextStyle(color: AdminOverviewTheme.red))),
        ],
      ],
    );
  }
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Vui lòng nhập thông tin.'
      : null;
}
