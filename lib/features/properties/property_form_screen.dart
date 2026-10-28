import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../models/property.dart';
import '../rooms/room_providers.dart';
import '../auth/auth_providers.dart';
import '../billing/transfer_account_dialog.dart';

class PropertyFormScreen extends ConsumerWidget {
  const PropertyFormScreen({super.key, this.propertyId});

  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (propertyId == null) {
      return const _FormScaffold(
        title: 'Thêm khu trọ',
        child: _PropertyForm(),
      );
    }

    final propertiesAsync = ref.watch(propertiesProvider);
    return _FormScaffold(
      title: 'Sửa khu trọ',
      child: propertiesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => _LoadError(
          message: '$error',
          onRetry: () => ref.invalidate(propertiesProvider),
        ),
        data: (properties) {
          Property? existing;
          for (final property in properties) {
            if (property.id == propertyId) {
              existing = property;
              break;
            }
          }
          if (existing == null) {
            return const Center(
              child: Text(
                'Không tìm thấy khu trọ.',
                style: TextStyle(color: Color(0xFF8891A8)),
              ),
            );
          }
          return _PropertyForm(existing: existing);
        },
      ),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8891A8)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _PropertyForm extends ConsumerStatefulWidget {
  const _PropertyForm({this.existing});

  final Property? existing;

  @override
  ConsumerState<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends ConsumerState<_PropertyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(propertyFormControllerProvider.notifier).submit(
            existing: widget.existing,
            name: _name.text.trim(),
            address: _address.text.trim(),
          );
      if (mounted) context.pop();
    } catch (_) {
      // Provider state renders the error banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(propertyFormControllerProvider);
    final isEdit = widget.existing != null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.hasError) ...[
            _ErrorBanner(message: _friendlyError(state.error)),
            const SizedBox(height: 16),
          ],
          _Field(
            controller: _name,
            label: 'Tên khu trọ',
            hint: 'Nhà trọ An Bình',
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Nhập tên khu trọ';
              if (text.length > 120) return 'Tên tối đa 120 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _address,
            label: 'Địa chỉ',
            hint: '123 Đường số 8...',
            maxLines: 3,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length > 255) return 'Địa chỉ tối đa 255 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (isEdit &&
              ref.watch(sessionControllerProvider).session?.user.role ==
                  'landlord') ...[
            OutlinedButton.icon(
              onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      TransferAccountDialog(propertyId: widget.existing!.id)),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Tài khoản nhận tiền'),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit ? 'Lưu thay đổi' : 'Tạo khu trọ',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object? error) {
    if (error is ApiFailure) return error.message;
    return 'Không thể lưu khu trọ. Vui lòng thử lại.';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF0F2FF),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, color: Color(0xFFF0F2FF)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E3348), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
          ),
        ),
      ],
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
