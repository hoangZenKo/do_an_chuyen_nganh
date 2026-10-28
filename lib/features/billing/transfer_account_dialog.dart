import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/manual_transfer_api.dart';
import '../auth/auth_providers.dart';
import '../tenant_portal/tenant_portal_providers.dart';

class TransferAccountDialog extends ConsumerStatefulWidget {
  const TransferAccountDialog({super.key, required this.propertyId});
  final String propertyId;
  @override
  ConsumerState<TransferAccountDialog> createState() =>
      _TransferAccountDialogState();
}

class _TransferAccountDialogState extends ConsumerState<TransferAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _number = TextEditingController();
  late final String? _owner;
  int? _version;
  String? _qr;
  String? _error;
  bool _enabled = true;
  bool _busy = true;
  bool _invalidated = false;
  bool _reloadRequired = false;

  bool get _sameOwner =>
      !_invalidated &&
      _owner != null &&
      ref.read(sessionIdentityProvider) == _owner &&
      ref.read(sessionControllerProvider).session?.user.role == 'landlord';

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_sameOwner) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account =
          await ref.read(manualTransferApiProvider).account(widget.propertyId);
      if (!mounted || !_sameOwner) return;
      setState(() {
        _version = account.version;
        _bank.text = account.bankName;
        _name.text = account.accountName;
        _number.text = account.accountNumber;
        _qr = account.qrImagePath;
        _enabled = account.version == 0 || account.enabled;
        _reloadRequired = false;
      });
    } catch (error) {
      if (mounted && _sameOwner) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (!_sameOwner) return;
    final picker = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp']);
    final path = picker?.files.single.path;
    if (path == null || !mounted || !_sameOwner) return;
    setState(() => _busy = true);
    try {
      final url = await ref.read(uploadApiProvider).uploadFile(path);
      if (!mounted || !_sameOwner) return;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.hasScheme ||
          !uri.path.startsWith('/uploads/') ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException('Ảnh QR tải lên không hợp lệ.');
      }
      setState(() {
        _qr = uri.path;
        _error = null;
      });
    } catch (error) {
      if (mounted && _sameOwner) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_sameOwner ||
        _version == null ||
        _reloadRequired ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(manualTransferApiProvider).save(
          widget.propertyId,
          TransferAccount(
              version: _version!,
              enabled: _enabled,
              bankName: _bank.text.trim(),
              accountName: _name.text.trim(),
              accountNumber: _number.text.trim(),
              qrImagePath: _qr));
      if (mounted && _sameOwner) Navigator.pop(context, true);
    } catch (error) {
      if (mounted && _sameOwner) {
        setState(() {
          _error = '$error';
          _reloadRequired = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    final role = ref.watch(sessionControllerProvider).session?.user.role;
    if (identity != _owner || role != 'landlord') _invalidated = true;
    if (_invalidated || _owner == null) {
      return AlertDialog(
          title: const Text('Phiên đã thay đổi'),
          content: const Text(
              'Đóng form và đăng nhập lại trước khi cập nhật tài khoản nhận tiền.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'))
          ]);
    }
    return AlertDialog(
      title: const Text('Tài khoản nhận tiền'),
      content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
              child: Form(
                  key: _form,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Người thuê chuyển khoản trực tiếp cho bạn. Bạn cần kiểm tra tiền vào ngân hàng trước khi duyệt chứng từ.'),
                        if (_busy) const LinearProgressIndicator(),
                        if (_version != null) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _bank,
                              enabled: !_busy,
                              maxLength: 120,
                              decoration:
                                  const InputDecoration(labelText: 'Ngân hàng'),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
                                      ? 'Nhập tên ngân hàng.'
                                      : null),
                          TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                  labelText: 'Tên chủ tài khoản'),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
                                      ? 'Nhập tên chủ tài khoản.'
                                      : null),
                          TextFormField(
                              controller: _number,
                              enabled: !_busy,
                              maxLength: 34,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Số tài khoản'),
                              validator: (value) => !RegExp(r'^[0-9]{4,34}$')
                                      .hasMatch(value?.trim() ?? '')
                                  ? 'Nhập 4–34 chữ số, giữ nguyên số 0 đầu.'
                                  : null),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cho phép chuyển khoản'),
                              value: _enabled,
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                      setState(() => _enabled = value)),
                          const Text(
                              'Ảnh QR lấy từ app ngân hàng (không bắt buộc). Kiểm tra QR trùng tài khoản nhận tiền; ứng dụng không tự xác minh ngân hàng.'),
                          Wrap(spacing: 8, children: [
                            OutlinedButton.icon(
                                onPressed: _busy ? null : _upload,
                                icon: const Icon(Icons.qr_code),
                                label: Text(_qr == null
                                    ? 'Tải ảnh QR'
                                    : 'Thay ảnh QR')),
                            if (_qr != null)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() => _qr = null),
                                  child: const Text('Bỏ ảnh QR')),
                          ]),
                          if (_qr != null)
                            const Text('Đã đính kèm ảnh QR riêng tư.'),
                        ],
                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        if (_reloadRequired || (!_busy && _version == null))
                          TextButton(
                              onPressed: _load,
                              child: const Text('Tải lại thông tin')),
                      ])))),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Đóng')),
        FilledButton(
            onPressed:
                _busy || _version == null || _reloadRequired ? null : _save,
            child: const Text('Lưu tài khoản'))
      ],
    );
  }
}
