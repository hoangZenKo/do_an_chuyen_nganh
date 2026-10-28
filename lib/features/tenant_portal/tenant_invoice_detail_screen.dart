import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'tenant_online_payment_screen.dart';
import 'tenant_manual_payment_screen.dart';
import 'tenant_payment_proof_dialog.dart';

import '../../core/messaging/messaging_launcher.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import '../billing/widgets/invoice_timeline.dart';
import '../billing/invoice_pdf.dart';
import '../listings/listing_widgets.dart';
import 'tenant_portal_providers.dart';

class TenantInvoiceDetailScreen extends ConsumerWidget {
  const TenantInvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(tenantPortalInvoiceProvider(invoiceId));
    final submittedProof =
        ref.watch(tenantPaymentProofControllerProvider).value;
    return ListingTheme(
      child: Scaffold(
        backgroundColor: kAirbnbSurface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            'Chi tiết hóa đơn',
            style: TextStyle(fontWeight: FontWeight.w800, color: kAirbnbInk),
          ),
        ),
        body: invoiceAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: kAirbnbRose),
          ),
          error: (error, _) => Center(child: Text('$error')),
          data: (invoice) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: invoice.remainingAmount > 0
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            invoice.status == InvoiceStatus.cancelled
                                ? 'Đã hủy'
                                : invoice.remainingAmount <= 0
                                    ? 'Đã thanh toán'
                                    : invoice.paymentProofs.any((proof) =>
                                            proof.status == 'pending')
                                        ? 'Chờ chủ trọ xác nhận'
                                        : 'Đang chờ thanh toán',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: invoice.remainingAmount > 0
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF0F8A6A),
                            ),
                          ),
                        ),
                        Text(
                          'Hạn: ${formatDate(invoice.dueDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kAirbnbMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Hóa đơn ${formatMonth(invoice.billingMonth)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kAirbnbInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (invoice.isDemo)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Môi trường kiểm thử — không thu tiền thật.',
                          style: TextStyle(color: kAirbnbMuted, fontSize: 12),
                        ),
                      ),
                    Text(
                      'Hạn thanh toán: ${formatDate(invoice.dueDate)}',
                      style: const TextStyle(color: kAirbnbMuted, fontSize: 13),
                    ),
                    const Divider(height: 24, color: kAirbnbLine),
                    _MoneyRow('Tiền phòng', invoice.rentAmount),
                    _MoneyRow('Điện', invoice.electricityAmount),
                    _MoneyRow('Nước', invoice.waterAmount),
                    if (invoice.otherAmount > 0)
                      _MoneyRow('Khác', invoice.otherAmount),
                    const Divider(height: 24, color: kAirbnbLine),
                    _MoneyRow('Tổng', invoice.totalAmount, strong: true),
                    _MoneyRow('Đã thanh toán', invoice.paidAmount),
                    _MoneyRow(
                      'Còn lại',
                      invoice.remainingAmount,
                      strong: true,
                      color: invoice.remainingAmount > 0
                          ? kAirbnbRose
                          : const Color(0xFF10B981),
                    ),
                    if (invoice.remainingAmount > 0 &&
                        invoice.status != InvoiceStatus.cancelled) ...[
                      const SizedBox(height: 16),
                      if (!invoice.isDemo)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => TenantManualPaymentScreen(
                                        invoiceId: invoice.id))),
                            style: FilledButton.styleFrom(
                              backgroundColor: kAirbnbRose,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text(
                              'Thanh toán chuyển khoản',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (!invoice.isDemo && _unreservedAmount(invoice) > 0)
                        TextButton.icon(
                          onPressed: () => showTenantPaymentProofDialog(
                              context, ref, invoice,
                              initialAmount: _unreservedAmount(invoice)),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Gửi chứng từ khoản đã thanh toán'),
                        ),
                      if (invoice.isDemo)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openOnlinePayment(context, ref, invoice.id),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text(
                                'Thử thanh toán thẻ (không trừ tiền)'),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _copyInvoice(context, invoice),
                            icon: const Icon(Icons.content_copy_rounded),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => openMessagingApp(
                              context,
                              tenantId: invoice.tenantId,
                              invoiceId: invoice.id,
                              tenantName: invoice.tenantName,
                              roomName: invoice.roomName,
                              template: invoice.remainingAmount > 0
                                  ? 'payment_question'
                                  : 'invoice_detail',
                              message: _invoiceText(invoice),
                            ),
                            icon: const Icon(Icons.chat_bubble_rounded),
                            label: const Text('Nhắn chủ trọ'),
                          ),
                        ),
                      ],
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
              if (invoice.paymentProofs.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chứng từ thanh toán',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      ...invoice.paymentProofs.map(
                        (proof) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(formatCurrencyVnd(proof.amount)),
                          subtitle: Text(
                            [
                              _proofStatusTitle(proof.status),
                              formatDate(proof.submittedAt),
                              if (proof.status == 'rejected' &&
                                  proof.reviewNote?.trim().isNotEmpty == true)
                                'Lý do: ${proof.reviewNote}',
                            ].join(' · '),
                          ),
                          trailing:
                              Text(_paymentProofMethodLabel(proof.method.name)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử thanh toán',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
      ),
    );
  }

  Future<void> _openOnlinePayment(
      BuildContext context, WidgetRef ref, String invoiceId) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TenantOnlinePaymentScreen(invoiceId: invoiceId)));
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

Future<void> _copyInvoice(BuildContext context, Invoice invoice) async {
  await Clipboard.setData(ClipboardData(text: _invoiceText(invoice)));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy nội dung hóa đơn.')),
    );
  }
}

String _invoiceText(Invoice invoice) {
  return [
    'HÓA ĐƠN PHÒNG ${invoice.roomName ?? invoice.roomId}',
    'Tháng: ${formatMonth(invoice.billingMonth)}',
    'Hạn thanh toán: ${formatDate(invoice.dueDate)}',
    '',
    'Tiền phòng: ${formatCurrencyVnd(invoice.rentAmount)}',
    'Điện: ${formatCurrencyVnd(invoice.electricityAmount)}',
    'Nước: ${formatCurrencyVnd(invoice.waterAmount)}',
    if (invoice.otherAmount > 0)
      'Khác: ${formatCurrencyVnd(invoice.otherAmount)}',
    'Tổng: ${formatCurrencyVnd(invoice.totalAmount)}',
    'Đã thanh toán: ${formatCurrencyVnd(invoice.paidAmount)}',
    'Còn lại: ${formatCurrencyVnd(invoice.remainingAmount)}',
  ].join('\n');
}

int _unreservedAmount(Invoice invoice) => (invoice.remainingAmount -
        invoice.paymentProofs
            .where((proof) => proof.status == 'pending')
            .fold<int>(0, (sum, proof) => sum + proof.amount))
    .clamp(0, invoice.remainingAmount < 0 ? 0 : invoice.remainingAmount);

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
                    color: kAirbnbInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCurrencyVnd(proof.amount)} · ${_paymentProofMethodLabel(proof.method)} · ${proof.proofImageUrls.length} file',
            style: const TextStyle(
              color: Color(0xFF8891A8),
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

String _proofStatusTitle(String status) {
  return switch (status) {
    'approved' => 'Đã duyệt',
    'rejected' => 'Bị từ chối',
    _ => 'Chờ duyệt',
  };
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAirbnbLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? kAirbnbInk : kAirbnbMuted,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatCurrencyVnd(amount),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: color ?? kAirbnbInk,
            ),
          ),
        ],
      ),
    );
  }
}
