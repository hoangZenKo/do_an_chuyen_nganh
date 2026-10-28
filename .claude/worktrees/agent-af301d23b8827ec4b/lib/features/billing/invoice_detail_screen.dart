import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/messaging/messaging_launcher.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'widgets/invoice_timeline.dart';
import 'invoice_pdf.dart';
import 'billing_providers.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final canRecordPayment = sessionHasPermission(session, 'billing.record_payment');
    final canCancelInvoice = sessionHasPermission(session, 'billing.cancel');
    final canApprovePaymentProof =
        sessionHasPermission(session, 'billing.approve_payment_proof');
    final canReversePayment =
        sessionHasPermission(session, 'billing.reverse_payment');
    final invoiceAsync = ref.watch(invoiceProvider(invoiceId));
    final pendingProofsAsync = ref.watch(pendingPaymentProofsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Chi tiết hóa đơn'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(invoiceProvider(invoiceId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (error, _) => _CenteredError(
          message: '$error',
          onRetry: () => ref.invalidate(invoiceProvider(invoiceId)),
        ),
        data: (invoice) => RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(invoiceProvider(invoiceId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _InvoiceHero(invoice: invoice),
              const SizedBox(height: 12),
              pendingProofsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (proofs) => InvoiceTimelineCard(
                  invoice: invoice,
                  pendingProofs:
                      proofs.where((proof) => proof.invoiceId == invoice.id).toList(),
                ),
              ),
              const SizedBox(height: 12),
              _ActionBar(
                invoice: invoice,
                canRecordPayment: canRecordPayment,
                canCancelInvoice: canCancelInvoice,
              ),
              const SizedBox(height: 12),
              _PaymentProofsCard(
                invoice: invoice,
                canApprovePaymentProof: canApprovePaymentProof,
              ),
              const SizedBox(height: 12),
              _AmountBreakdown(invoice: invoice),
              const SizedBox(height: 12),
              _PaymentHistory(
                invoice: invoice,
                canReversePayment: canReversePayment,
              ),
              if (invoice.note != null && invoice.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Ghi chú',
                  child: Text(
                    invoice.note!,
                    style: const TextStyle(color: Color(0xFF374151)),
                  ),
                ),
              ],
              if (invoice.status == InvoiceStatus.cancelled) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: 'Thông tin hủy',
                  child: Text(
                    [
                      if (invoice.cancelledAt != null)
                        'Ngày hủy: ${formatDate(invoice.cancelledAt)}',
                      if (invoice.cancelledNote != null)
                        'Lý do: ${invoice.cancelledNote}',
                    ].join('\n'),
                    style: const TextStyle(color: Color(0xFF374151)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentProofsCard extends ConsumerWidget {
  const _PaymentProofsCard({
    required this.invoice,
    required this.canApprovePaymentProof,
  });

  final Invoice invoice;
  final bool canApprovePaymentProof;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proofsAsync = ref.watch(pendingPaymentProofsProvider);
    return proofsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final proofs = items
            .where((proof) => proof.invoiceId == invoice.id)
            .toList(growable: false);
        if (proofs.isEmpty) return const SizedBox.shrink();
        return _InfoCard(
          title: 'Chứng từ tenant chờ duyệt',
          child: Column(
            children: [
              for (final proof in proofs) ...[
                _PaymentProofTile(
                  invoice: invoice,
                  proof: proof,
                  canApprovePaymentProof: canApprovePaymentProof,
                ),
                if (proof != proofs.last) const Divider(height: 18),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PaymentProofTile extends ConsumerWidget {
  const _PaymentProofTile({
    required this.invoice,
    required this.proof,
    required this.canApprovePaymentProof,
  });

  final Invoice invoice;
  final PaymentProof proof;
  final bool canApprovePaymentProof;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatCurrencyVnd(proof.amount),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          [
            proof.tenantName ?? invoice.tenantName ?? 'Tenant',
            formatDate(proof.submittedAt),
            if (proof.proofImageUrls.isNotEmpty)
              '${proof.proofImageUrls.length} file',
          ].join(' · '),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        if (proof.note != null && proof.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(proof.note!),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canApprovePaymentProof)
              FilledButton.icon(
                onPressed: () => _reviewPaymentProof(
                  context,
                  ref,
                  invoice,
                  proof,
                  'approved',
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Duyệt'),
              ),
            if (canApprovePaymentProof)
              OutlinedButton.icon(
                onPressed: () => _reviewPaymentProof(
                  context,
                  ref,
                  invoice,
                  proof,
                  'rejected',
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Từ chối'),
              ),
            if (proof.proofImageUrls.isNotEmpty)
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: proof.proofImageUrls.join('\n')),
                ),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Copy link file'),
              ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceHero extends StatelessWidget {
  const _InvoiceHero({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Hóa đơn ${formatMonth(invoice.billingMonth)}',
      trailing: _StatusChip(status: invoice.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phòng ${invoice.roomName ?? invoice.roomId}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            invoice.tenantName ?? 'Khách thuê',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Tổng',
                  value: formatCurrencyVnd(invoice.totalAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: 'Còn lại',
                  value: formatCurrencyVnd(invoice.remainingAmount),
                  color: invoice.remainingAmount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MetaText('Ngày lập: ${formatDate(invoice.issuedAt)}'),
              _MetaText('Hạn trả: ${formatDate(invoice.dueDate)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.invoice,
    required this.canRecordPayment,
    required this.canCancelInvoice,
  });

  final Invoice invoice;
  final bool canRecordPayment;
  final bool canCancelInvoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InfoCard(
      title: 'Thao tác',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canRecordPayment)
            FilledButton.icon(
              onPressed: invoice.canPay
                  ? () => _showPaymentDialog(context, ref, invoice)
                  : null,
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Thanh toán'),
            ),
          if (canCancelInvoice)
            OutlinedButton.icon(
              onPressed: invoice.canCancel
                  ? () => _showCancelDialog(context, ref, invoice)
                  : null,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Hủy hóa đơn'),
            ),
          OutlinedButton.icon(
            onPressed: () => _copyInvoice(context, invoice),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Copy hóa đơn'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showPrintableInvoice(context, invoice),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Bản in'),
          ),
          OutlinedButton.icon(
            onPressed: () => _exportPdf(context, invoice),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Xuất PDF'),
          ),
          OutlinedButton.icon(
            onPressed: invoice.remainingAmount > 0
                ? () => _copyReminder(context, invoice)
                : null,
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Nhắc nợ'),
          ),
          OutlinedButton.icon(
            onPressed: () => openMessagingApp(
              context,
              tenantId: invoice.tenantId,
              invoiceId: invoice.id,
              tenantName: invoice.tenantName,
              roomName: invoice.roomName,
              template: invoice.remainingAmount > 0
                  ? 'invoice_reminder'
                  : 'invoice_detail',
            ),
            icon: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/zalo_logo.png',
                width: 16,
                height: 16,
              ),
            ),
            label: const Text('Nhắn tin'),
          ),
        ],
      ),
    );
  }
}

class _AmountBreakdown extends StatelessWidget {
  const _AmountBreakdown({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Khoản thu',
      child: Column(
        children: [
          _MoneyRow(label: 'Tiền phòng', amount: invoice.rentAmount),
          _MoneyRow(label: 'Điện', amount: invoice.electricityAmount),
          _MoneyRow(label: 'Nước', amount: invoice.waterAmount),
          if (invoice.otherAmount > 0)
            _MoneyRow(label: 'Khác', amount: invoice.otherAmount),
          const Divider(height: 20),
          _MoneyRow(label: 'Tổng', amount: invoice.totalAmount, strong: true),
          _MoneyRow(label: 'Đã thu', amount: invoice.paidAmount),
          _MoneyRow(
            label: 'Còn lại',
            amount: invoice.remainingAmount,
            strong: true,
            color: invoice.remainingAmount > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory({
    required this.invoice,
    required this.canReversePayment,
  });

  final Invoice invoice;
  final bool canReversePayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = [...invoice.payments]
      ..sort((a, b) {
        final aDate = a.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return _InfoCard(
      title: 'Lịch sử thanh toán',
      child: payments.isEmpty
          ? const Text(
              'Chưa có thanh toán.',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          : Column(
              children: [
                for (final payment in payments) ...[
                  _PaymentTile(
                    invoice: invoice,
                    payment: payment,
                    reversed: payments.any(
                      (item) => item.reversalOfPaymentId == payment.id,
                    ),
                    canReversePayment: canReversePayment,
                  ),
                  if (payment != payments.last) const Divider(height: 18),
                ],
              ],
            ),
    );
  }
}

class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({
    required this.invoice,
    required this.payment,
    required this.reversed,
    required this.canReversePayment,
  });

  final Invoice invoice;
  final Payment payment;
  final bool reversed;
  final bool canReversePayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReverse = canReversePayment &&
        payment.canReverse &&
        !reversed &&
        invoice.status != InvoiceStatus.cancelled;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          payment.type == PaymentType.reversal
              ? Icons.undo_rounded
              : Icons.payments_rounded,
          color: payment.type == PaymentType.reversal
              ? const Color(0xFFF59E0B)
              : const Color(0xFF059669),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${payment.type.label} · ${payment.method.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  formatDate(payment.paidAt),
                  if (reversed) 'Đã hoàn tác',
                  if (payment.note != null && payment.note!.isNotEmpty)
                    payment.note!,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrencyVnd(payment.amount),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: payment.amount < 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF059669),
              ),
            ),
            TextButton(
              onPressed: canReverse
                  ? () => _showReverseDialog(context, ref, invoice, payment)
                  : null,
              child: const Text('Hoàn tác'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color ?? const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: status.color,
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.strong = false,
    this.color,
  });

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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          Text(
            formatCurrencyVnd(amount),
            style: TextStyle(
              fontSize: strong ? 15 : 13,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              color: color ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

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
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final amount = TextEditingController(text: invoice.remainingAmount.toString());
  final paidAt = TextEditingController(text: _todayIsoDate());
  final note = TextEditingController();
  var method = PaymentMethod.cash;
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ghi nhận thanh toán'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Số tiền'),
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
                      : (value) =>
                          setState(() => method = value ?? PaymentMethod.cash),
                  decoration:
                      const InputDecoration(labelText: 'Phương thức thanh toán'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: paidAt,
                  decoration: const InputDecoration(labelText: 'Ngày thanh toán'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
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
                      final value = int.tryParse(amount.text.trim()) ?? 0;
                      if (value <= 0) {
                        setState(() => error = 'Nhập số tiền hợp lệ.');
                        return;
                      }
                      if (DateTime.tryParse(paidAt.text.trim()) == null) {
                        setState(() => error = 'Nhập ngày thanh toán hợp lệ.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(billingPaymentControllerProvider.notifier)
                            .pay(
                              invoiceId: invoice.id,
                              amount: value,
                              method: method,
                              paidAt: paidAt.text.trim(),
                              note: note.text,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setState(() {
                          loading = false;
                          error = _friendlyError(e);
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      );
    },
  );

  amount.dispose();
  paidAt.dispose();
  note.dispose();
}

Future<void> _reviewPaymentProof(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
  PaymentProof proof,
  String status,
) async {
  final note = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(status == 'approved' ? 'Duyệt chứng từ?' : 'Từ chối chứng từ?'),
      content: TextField(
        controller: note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Ghi chú'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(status == 'approved' ? 'Duyệt' : 'Từ chối'),
        ),
      ],
    ),
  );
  final noteText = note.text;
  note.dispose();
  if (confirmed != true) return;

  try {
    await ref.read(billingPaymentControllerProvider.notifier).reviewPaymentProof(
          proofId: proof.id,
          invoiceId: invoice.id,
          status: status,
          note: noteText,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Đã duyệt chứng từ và ghi nhận thanh toán.'
                : 'Đã từ chối chứng từ.',
          ),
        ),
      );
    }
  } catch (error) {
    final message = error is ApiFailure ? error.message : '$error';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

Future<void> _showCancelDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) {
  return _showNoteActionDialog(
    context: context,
    title: 'Hủy hóa đơn',
    label: 'Lý do hủy',
    submitLabel: 'Hủy hóa đơn',
    onSubmit: (note) => ref
        .read(billingPaymentControllerProvider.notifier)
        .cancel(invoiceId: invoice.id, note: note),
  );
}

Future<void> _showReverseDialog(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
  Payment payment,
) {
  return _showNoteActionDialog(
    context: context,
    title: 'Hoàn tác thanh toán',
    label: 'Lý do hoàn tác',
    submitLabel: 'Hoàn tác',
    onSubmit: (note) => ref
        .read(billingPaymentControllerProvider.notifier)
        .reversePayment(
          invoiceId: invoice.id,
          paymentId: payment.id,
          note: note,
        ),
  );
}

Future<void> _showNoteActionDialog({
  required BuildContext context,
  required String title,
  required String label,
  required String submitLabel,
  required Future<Object?> Function(String note) onSubmit,
}) async {
  final note = TextEditingController();
  String? error;
  var loading = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(labelText: label),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final value = note.text.trim();
                      if (value.isEmpty) {
                        setState(() => error = 'Vui lòng nhập lý do.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await onSubmit(value);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        setState(() {
                          loading = false;
                          error = _friendlyError(e);
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(submitLabel),
            ),
          ],
        ),
      );
    },
  );
  note.dispose();
}

Future<void> _copyInvoice(BuildContext context, Invoice invoice) async {
  await Clipboard.setData(ClipboardData(text: _invoiceText(invoice)));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy nội dung hóa đơn.')),
    );
  }
}

Future<void> _exportPdf(BuildContext context, Invoice invoice) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Đang tạo PDF hóa đơn...')),
  );
  try {
    await shareInvoicePdf(invoice);
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã tạo PDF hóa đơn.')),
      );
    }
  } catch (error) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không tạo được PDF: $error')),
      );
    }
  }
}

Future<void> _showPrintableInvoice(BuildContext context, Invoice invoice) async {
  final text = _invoiceText(invoice);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bản in hóa đơn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 420),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Copy bản in'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _copyReminder(BuildContext context, Invoice invoice) async {
  await Clipboard.setData(ClipboardData(text: _reminderText(invoice)));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy nội dung nhắc thanh toán.')),
    );
  }
}

String _invoiceText(Invoice invoice) {
  return [
    'HÓA ĐƠN PHÒNG ${invoice.roomName ?? invoice.roomId}',
    'Khách thuê: ${invoice.tenantName ?? 'Khách thuê'}',
    'Tháng: ${formatMonth(invoice.billingMonth)}',
    'Hạn thanh toán: ${formatDate(invoice.dueDate)}',
    '',
    'Tiền phòng: ${formatCurrencyVnd(invoice.rentAmount)}',
    'Điện: ${formatCurrencyVnd(invoice.electricityAmount)}',
    'Nước: ${formatCurrencyVnd(invoice.waterAmount)}',
    if (invoice.otherAmount > 0)
      'Khác: ${formatCurrencyVnd(invoice.otherAmount)}',
    'Tổng: ${formatCurrencyVnd(invoice.totalAmount)}',
    'Đã thu: ${formatCurrencyVnd(invoice.paidAmount)}',
    'Còn lại: ${formatCurrencyVnd(invoice.remainingAmount)}',
  ].join('\n');
}

String _reminderText(Invoice invoice) {
  return [
    'Chào ${invoice.tenantName ?? 'anh/chị'},',
    'Mình nhắc hóa đơn phòng ${invoice.roomName ?? invoice.roomId} tháng ${formatMonth(invoice.billingMonth)} còn ${formatCurrencyVnd(invoice.remainingAmount)}.',
    'Hạn thanh toán: ${formatDate(invoice.dueDate)}.',
    'Cảm ơn anh/chị.',
  ].join('\n');
}

String _todayIsoDate() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

String _friendlyError(Object error) {
  if (error is ApiFailure) {
    return switch (error.code) {
      'PAYMENT_EXCEEDS_REMAINING' => 'Số tiền vượt quá số còn phải thu.',
      'INVOICE_ALREADY_PAID' => 'Hóa đơn đã thu đủ.',
      'INVOICE_CANCELLED' => 'Hóa đơn đã hủy.',
      'INVOICE_HAS_PAYMENTS' => 'Không thể hủy hóa đơn đã có thanh toán.',
      'PAYMENT_ALREADY_REVERSED' => 'Thanh toán này đã được hoàn tác.',
      'PAYMENT_REVERSAL_NOT_ALLOWED' =>
        'Không thể hoàn tác một giao dịch hoàn tác.',
      _ => error.message,
    };
  }
  return '$error';
}
