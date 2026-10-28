import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../tenants/widgets/form_widgets.dart';
import 'admin_providers.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit landlord' : 'Add landlord')),
      body: detailAsync?.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
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
              AppTextField(
                controller: fullName,
                label: 'Full name',
                validator: _required,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                readOnly: isEditing,
                validator: isEditing ? null : _required,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: phone,
                label: 'Phone',
                keyboardType: TextInputType.phone,
              ),
              if (!isEditing) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: password,
                  label: 'Password',
                  validator: _required,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SubmitButton(
          label: isEditing ? 'Save changes' : 'Create landlord',
          loading: loading,
          onPressed: onSubmit,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          FormErrorBanner(message: '$error'),
        ],
      ],
    );
  }
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Required' : null;
}
