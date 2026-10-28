import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/student_discovery.dart';
import '../auth/auth_providers.dart';
import 'listing_widgets.dart';
import 'listings_providers.dart';

class ListingReportDialog extends ConsumerStatefulWidget {
  const ListingReportDialog({super.key, required this.listingId});
  final String listingId;
  @override
  ConsumerState<ListingReportDialog> createState() =>
      _ListingReportDialogState();
}

class _ListingReportDialogState extends ConsumerState<ListingReportDialog> {
  final _form = GlobalKey<FormState>();
  final _detail = TextEditingController();
  late final String? _identity;
  String _reason = 'wrong_price';
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _identity = ref.read(sessionIdentityProvider);
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(managedListingsRepositoryProvider).report(widget.listingId,
          reason: _reason, detail: _detail.text.trim());
      if (mounted && ref.read(sessionIdentityProvider) == _identity) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == _identity) {
        setState(() => _error = listingError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != _identity) {
      return AlertDialog(
          content:
              const Text('Tài khoản đã thay đổi. Hãy đóng và mở lại báo cáo.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng')),
          ]);
    }
    return AlertDialog(
        title: const Text('Báo cáo tin đăng'),
        content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                        value: _reason,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Vấn đề'),
                        items: [
                          for (final reason in listingReportReasons.entries)
                            DropdownMenuItem(
                                value: reason.key, child: Text(reason.value))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _reason = value!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _detail,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                            labelText: 'Mô tả cụ thể',
                            helperText:
                                'Không đưa CCCD, tài khoản ngân hàng hay thông tin nhạy cảm vào báo cáo.'),
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Nhập ít nhất 10 ký tự'
                            : null,
                      ),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                    ])))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Đang gửi…' : 'Gửi báo cáo')),
        ]);
  }
}
