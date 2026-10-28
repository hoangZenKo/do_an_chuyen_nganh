import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/request_key.dart';
import '../../models/billing.dart';
import '../auth/auth_providers.dart';
import 'tenant_portal_providers.dart';

Future<void> showTenantPaymentProofDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  int? initialAmount,
  String? reference,
  bool bankTransferOnly = false,
}) async {
  final owner = ref.read(sessionIdentityProvider);
  var invalidated = false;
  final subscription = ref.listenManual(sessionIdentityProvider, (_, next) {
    if (next != owner) invalidated = true;
  });
  bool sameOwner() =>
      context.mounted &&
      !invalidated &&
      owner != null &&
      ref.read(sessionIdentityProvider) == owner;
  if (!sameOwner()) {
    subscription.close();
    return;
  }
  final requestKey = newRequestKey();
  var amount = (initialAmount ?? invoice.remainingAmount).toString();
  var note = reference ?? '';
  final imageUrls = <String>[];
  var method = PaymentMethod.bankTransfer;
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(builder: (context, dialogRef, child) {
      if (dialogRef.watch(sessionIdentityProvider) != owner) invalidated = true;
      if (invalidated) {
        return AlertDialog(
            title: const Text('Phiên đã thay đổi'),
            content: const Text(
                'Đóng và mở lại hóa đơn. Chưa gửi yêu cầu thanh toán cho phiên mới.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Đóng'))
            ]);
      }
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Gửi chứng từ thanh toán'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Gửi chứng từ chỉ tạo yêu cầu chờ duyệt, chưa ghi nhận đã thu tiền. Chủ trọ sẽ kiểm tra tài khoản ngân hàng trước khi xác nhận.'),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: amount,
                  onChanged: (value) => amount = value,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(labelText: 'Số tiền đã trả'),
                ),
                const SizedBox(height: 10),
                if (!bankTransferOnly)
                  DropdownButtonFormField<PaymentMethod>(
                    value: method,
                    items: PaymentMethod.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: loading
                        ? null
                        : (value) => setState(
                              () =>
                                  method = value ?? PaymentMethod.bankTransfer,
                            ),
                    decoration: const InputDecoration(
                        labelText: 'Phương thức thanh toán'),
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: note,
                  onChanged: (value) => note = value,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          try {
                            final url =
                                await _pickAndUploadFile(ref, sameOwner);
                            if (url != null &&
                                dialogContext.mounted &&
                                sameOwner()) {
                              setState(() => imageUrls.add(url));
                            }
                          } catch (err) {
                            if (!dialogContext.mounted || !sameOwner()) return;
                            setState(() => error = '$err');
                          }
                        },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    imageUrls.isEmpty
                        ? 'Upload ảnh/chứng từ'
                        : 'Đã upload ${imageUrls.length} file',
                  ),
                ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < imageUrls.length; i += 1)
                          Chip(
                            label: Text('File ${i + 1}'),
                            onDeleted: loading
                                ? null
                                : () => setState(() => imageUrls.removeAt(i)),
                          ),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!sameOwner()) {
                        setState(() => error =
                            'Phiên đã thay đổi. Đóng và mở lại hóa đơn.');
                        return;
                      }
                      final parsedAmount = int.tryParse(amount.trim());
                      if (parsedAmount == null || parsedAmount <= 0) {
                        setState(() => error = 'Nhập số tiền hợp lệ.');
                        return;
                      }
                      if (parsedAmount >
                          (initialAmount ?? invoice.remainingAmount)) {
                        setState(() => error =
                            'Số tiền vượt quá dư nợ chưa có chứng từ chờ duyệt.');
                        return;
                      }
                      if (imageUrls.isEmpty) {
                        setState(
                          () => error =
                              'Upload ít nhất một ảnh hoặc file chứng từ.',
                        );
                        return;
                      }
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(tenantPaymentProofControllerProvider.notifier)
                            .submit(
                              requestKey: requestKey,
                              invoiceId: invoice.id,
                              amount: parsedAmount,
                              method: method.wire,
                              note: note,
                              proofImageUrls: imageUrls,
                            );
                        if (!sameOwner()) return;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Đã gửi chứng từ chờ chủ trọ duyệt.'),
                            ),
                          );
                        }
                      } catch (err) {
                        if (!dialogContext.mounted || !sameOwner()) return;
                        setState(() {
                          loading = false;
                          error = '$err';
                        });
                      }
                    },
              child: const Text('Gửi'),
            ),
          ],
        ),
      );
    }),
  );

  subscription.close();
}

Future<String?> _pickAndUploadFile(
    WidgetRef ref, bool Function() sameOwner) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
      'pdf'
    ],
  );
  final path = result?.files.single.path;
  if (path == null || !sameOwner()) return null;
  final url = await ref.read(uploadApiProvider).uploadFile(path);
  return url.isEmpty ? null : ApiConfig.resolveUrl(url);
}
