import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_overview_theme.dart';

Future<String?> promptAdminStepUp(
    BuildContext context, bool Function() active) async {
  if (!active()) return null;
  final code = await showDialog<String>(
      context: context, builder: (_) => const _StepUpDialog());
  return active() ? code : null;
}

class _StepUpDialog extends StatefulWidget {
  const _StepUpDialog();
  @override
  State<_StepUpDialog> createState() => _StepUpDialogState();
}

class _StepUpDialogState extends State<_StepUpDialog> {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AdminOverviewTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminOverviewTheme.line),
        ),
        title: const Text('Xác thực thao tác nhạy cảm'),
        content: SingleChildScrollView(
            child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Nhập mã MFA mới hoặc mã khôi phục. Xác nhận chỉ dùng một lần cho đúng thao tác này và hết hạn sau 5 phút.'),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: input,
                        autofocus: true,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: 64,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s'))
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Mã MFA hoặc mã khôi phục'),
                        validator: (value) => (value?.length ?? 0) < 6
                            ? 'Nhập mã xác thực hợp lệ.'
                            : null),
                  ],
                ))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, input.text);
                }
              },
              child: const Text('Xác thực')),
        ],
      );
}
