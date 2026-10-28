import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import '../billing/widgets/invoice_timeline.dart';
import '../billing/invoice_pdf.dart';
import 'tenant_portal_providers.dart';

class TenantInvoiceDetailScreen extends ConsumerWidget {
  const TenantInvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(tenantPortalInvoiceProvider(invoiceId));
    final submittedProof =
        ref.watch(tenantPaymentProofControllerProvider).value;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Chi tiết hóa đơn')),
      body: invoiceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => Center(child: Text('$error')),
        data: (invoice) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hóa đơn ${formatMonth(invoice.billingMonth)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Hạn thanh toán: ${formatDate(invoice.dueDate)}'),
                  const Divider(height: 24),
                  _MoneyRow('Tiền phòng', invoice.rentAmount),
                  _MoneyRow('Điện', invoice.electricityAmount),
                  _MoneyRow('Nước', invoice.waterAmount),
                  if (invoice.otherAmount > 0)
                    _MoneyRow('Khác', invoice.otherAmount),
                  const Divider(height: 24),
                  _MoneyRow('Tổng', invoice.totalAmount, strong: true),
                  _MoneyRow('Đã thanh toán', invoice.paidAmount),
                  _MoneyRow(
                    'Còn lại',
                    invoice.remainingAmount,
                    strong: true,
                    color: invoice.remainingAmount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                  ),
                  if (invoice.remainingAmount > 0) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPaymentProofDialog(
                          context,
                          ref,
                          invoice,
                        ),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Tôi đã thanh toán'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportPdf(context, invoice),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Tải/chia sẻ PDF'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InvoiceTimelineCard(
              invoice: invoice,
              currentProof: submittedProof != null &&
                      submittedProof.invoiceId == invoice.id
                  ? submittedProof
                  : null,
            ),
            if (submittedProof != null &&
                submittedProof.invoiceId == invoice.id) ...[
              const SizedBox(height: 12),
              _SubmittedProofCard(proof: submittedProof),
            ],
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch sử thanh toán',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (invoice.payments.isEmpty)
                    const Text('Chưa có thanh toán.')
                  else
                    ...invoice.payments.map((payment) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(formatCurrencyVnd(payment.amount)),
                          subtitle: Text(formatDate(payment.paidAt)),
                          trailing: Text(payment.method.label),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _exportPdf(BuildContext context, Invoice invoice) async {
  try {
    await shareInvoicePdf(invoice);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không xuất được PDF: $error')),
    );
  }
}

Future<void> _showPaymentProofDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final amount =
      TextEditingController(text: invoice.remainingAmount.toString());
  final note = TextEditingController();
  final imageUrls = <String>[];
  var method = PaymentMethod.bankTransfer;
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Gửi chứng từ thanh toán'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Số tiền đã trả'),
              ),
              const SizedBox(height: 10),
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
                          () => method = value ?? PaymentMethod.bankTransfer,
                        ),
                decoration:
                    const InputDecoration(labelText: 'Phương thức thanh toán'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        try {
                          final url = await _pickAndUploadFile(ref);
                          if (url != null) {
                            setState(() => imageUrls.add(url));
                          }
                        } catch (err) {
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
                Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
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
                    final parsedAmount = int.tryParse(amount.text.trim());
                    if (parsedAmount == null || parsedAmount <= 0) {
                      setState(() => error = 'Nhập số tiền hợp lệ.');
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
                            invoiceId: invoice.id,
                            amount: parsedAmount,
                            method: method.wire,
                            note: note.text,
                            proofImageUrls: imageUrls,
                          );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi chứng từ chờ chủ trọ duyệt.'),
                          ),
                        );
                      }
                    } catch (err) {
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
    ),
  );

  amount.dispose();
  note.dispose();
}

Future<String?> _pickAndUploadFile(WidgetRef ref) async {
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
  if (path == null) return null;
  final url = await ref.read(uploadApiProvider).uploadFile(path);
  return url.isEmpty ? null : ApiConfig.resolveUrl(url);
}

class _SubmittedProofCard extends StatelessWidget {
  const _SubmittedProofCard({required this.proof});

  final PaymentProof proof;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _proofStatusTitle(proof.status),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCurrencyVnd(proof.amount)} · ${_paymentProofMethodLabel(proof.method)} · ${proof.proofImageUrls.length} file',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (proof.note != null && proof.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              proof.note!,
              style: const TextStyle(color: Color(0xFF374151)),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Chủ trọ sẽ kiểm tra chứng từ và cập nhật trạng thái hóa đơn sau khi duyệt.',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _proofStatusTitle(String status) {
    return switch (status) {
      'approved' => 'Chứng từ đã được duyệt',
      'rejected' => 'Chứng từ bị từ chối',
      _ => 'Chứng từ đang chờ duyệt',
    };
  }
}

String _paymentProofMethodLabel(String method) {
  return switch (method) {
    'bank_transfer' || 'bankTransfer' => 'Chuyển khoản',
    'cash' => 'Tiền mặt',
    'other' => 'Khác',
    _ => method,
  };
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(this.label, this.amount, {this.strong = false, this.color});
  final String label;
  final int amount;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatCurrencyVnd(amount),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
