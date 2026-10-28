import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../models/billing.dart';
import '../../../models/tenant_portal.dart';

enum InvoiceTimelineKind {
  created,
  due,
  proofSubmitted,
  proofReviewed,
  proofPending,
  payment,
  reversal,
  cancelled,
  settled,
}

class InvoiceTimelineEntry {
  const InvoiceTimelineEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.sortDate,
    required this.order,
    this.amount,
  });

  final InvoiceTimelineKind kind;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final DateTime? sortDate;
  final int order;
  final int? amount;
}

class InvoiceTimelineCard extends StatelessWidget {
  const InvoiceTimelineCard({
    super.key,
    required this.invoice,
    this.title = 'Dòng thời gian',
    this.pendingProofs = const [],
    this.currentProof,
  });

  final Invoice invoice;
  final String title;
  final List<PaymentProof> pendingProofs;
  final PaymentProof? currentProof;

  @override
  Widget build(BuildContext context) {
    final entries = buildInvoiceTimelineEntries(
      invoice,
      pendingProofs: pendingProofs,
      currentProof: currentProof,
    );
    if (entries.isEmpty) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                '${entries.length} mốc',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i += 1) ...[
            _TimelineRow(
              entry: entries[i],
              isLast: i == entries.length - 1,
            ),
            if (i != entries.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

List<InvoiceTimelineEntry> buildInvoiceTimelineEntries(
  Invoice invoice, {
  List<PaymentProof> pendingProofs = const [],
  PaymentProof? currentProof,
}) {
  final entries = <InvoiceTimelineEntry>[];
  var order = 0;

  void add(InvoiceTimelineEntry entry) {
    entries.add(entry);
    order += 1;
  }

  final createdAt = invoice.issuedAt ?? invoice.billingMonth;
  if (createdAt != null) {
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.created,
        title: 'Hóa đơn được tạo',
        subtitle: 'Kỳ ${formatMonth(invoice.billingMonth)}',
        color: AppTheme.primary,
        icon: Icons.receipt_long_rounded,
        sortDate: createdAt,
        order: order,
      ),
    );
  }

  if (invoice.dueDate != null) {
    final dueSubtitle = invoice.remainingAmount <= 0
        ? 'Đã đến hạn nhưng hiện không còn công nợ.'
        : invoice.isOverdue
            ? 'Quá hạn ${invoice.daysOverdue > 0 ? invoice.daysOverdue : _daysOverdue(invoice)} ngày'
            : invoice.isDueSoon
                ? 'Còn ${invoice.daysUntilDue ?? _daysUntilDue(invoice) ?? 0} ngày'
                : 'Hạn thanh toán ${formatDate(invoice.dueDate)}';
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.due,
        title: 'Đến hạn thanh toán',
        subtitle: dueSubtitle,
        color: const Color(0xFFD97706),
        icon: Icons.event_available_rounded,
        sortDate: invoice.dueDate,
        order: order,
      ),
    );
  }

  if (currentProof != null && currentProof.submittedAt != null) {
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.proofSubmitted,
        title: 'Đã gửi chứng từ',
        subtitle: _proofSummary(currentProof),
        color: const Color(0xFFD97706),
        icon: Icons.upload_file_rounded,
        sortDate: currentProof.submittedAt,
        order: order,
      ),
    );
    if (currentProof.reviewedAt != null || currentProof.status != 'pending') {
      final approved = currentProof.status == 'approved';
      add(
        InvoiceTimelineEntry(
          kind: InvoiceTimelineKind.proofReviewed,
          title: approved ? 'Chứng từ đã được duyệt' : 'Chứng từ bị từ chối',
          subtitle: currentProof.reviewNote?.trim().isNotEmpty == true
              ? currentProof.reviewNote!.trim()
              : approved
                  ? 'Chủ trọ đã xác nhận thanh toán.'
                  : 'Chủ trọ chưa chấp nhận chứng từ này.',
          color: approved ? const Color(0xFF059669) : const Color(0xFFDC2626),
          icon: approved ? Icons.verified_rounded : Icons.cancel_rounded,
          sortDate: currentProof.reviewedAt ?? currentProof.submittedAt,
          order: order,
        ),
      );
    }
  }

  final pendingIds = currentProof == null
      ? <String>{}
      : {currentProof.id};
  for (final proof in pendingProofs.where((proof) => proof.invoiceId == invoice.id)) {
    if (pendingIds.contains(proof.id)) continue;
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.proofPending,
        title: 'Chứng từ chờ duyệt',
        subtitle: _proofSummary(proof),
        color: const Color(0xFFD97706),
        icon: Icons.hourglass_top_rounded,
        sortDate: proof.submittedAt,
        order: order,
        amount: proof.amount,
      ),
    );
  }

  final payments = [...invoice.payments]
    ..sort((a, b) {
      final aDate = a.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
  for (final payment in payments) {
    final isReversal = payment.type == PaymentType.reversal;
    add(
      InvoiceTimelineEntry(
        kind: isReversal
            ? InvoiceTimelineKind.reversal
            : InvoiceTimelineKind.payment,
        title: isReversal ? 'Hoàn tác thanh toán' : 'Thanh toán đã ghi nhận',
        subtitle: [
          payment.method.label,
          if (payment.note != null && payment.note!.trim().isNotEmpty)
            payment.note!.trim(),
        ].join(' · '),
        color: isReversal ? const Color(0xFFF59E0B) : const Color(0xFF059669),
        icon: isReversal ? Icons.undo_rounded : Icons.payments_rounded,
        sortDate: payment.paidAt,
        order: order,
        amount: payment.amount,
      ),
    );
  }

  if (invoice.status == InvoiceStatus.cancelled) {
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.cancelled,
        title: 'Hóa đơn đã hủy',
        subtitle: invoice.cancelledNote?.trim().isNotEmpty == true
            ? invoice.cancelledNote!.trim()
            : 'Hóa đơn không còn hiệu lực.',
        color: const Color(0xFF6B7280),
        icon: Icons.cancel_outlined,
        sortDate: invoice.cancelledAt ?? invoice.issuedAt ?? invoice.billingMonth,
        order: order,
      ),
    );
  }

  if (invoice.status == InvoiceStatus.paid && invoice.remainingAmount == 0) {
    final lastPaymentDate = payments.isNotEmpty ? payments.last.paidAt : null;
    add(
      InvoiceTimelineEntry(
        kind: InvoiceTimelineKind.settled,
        title: 'Đã tất toán',
        subtitle: 'Không còn số tiền phải thu.',
        color: const Color(0xFF059669),
        icon: Icons.check_circle_rounded,
        sortDate: lastPaymentDate ?? invoice.issuedAt ?? invoice.billingMonth,
        order: order,
      ),
    );
  }

  entries.sort((a, b) {
    final aDate = a.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateCompare = aDate.compareTo(bDate);
    if (dateCompare != 0) return dateCompare;
    return a.order.compareTo(b.order);
  });

  return entries;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
  });

  final InvoiceTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.icon, size: 16, color: entry.color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                margin: const EdgeInsets.only(top: 3),
                color: const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (entry.amount != null)
                      Text(
                        formatCurrencyVnd(entry.amount!),
                        style: TextStyle(
                          color: entry.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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

String _proofSummary(PaymentProof proof) {
  final parts = <String>[
    formatCurrencyVnd(proof.amount),
    _paymentProofMethodLabel(proof.method),
  ];
  if (proof.proofImageUrls.isNotEmpty) {
    parts.add('${proof.proofImageUrls.length} file');
  }
  return parts.join(' · ');
}

String _paymentProofMethodLabel(String method) {
  return switch (method) {
    'bank_transfer' || 'bankTransfer' => 'Chuyển khoản',
    'cash' => 'Tiền mặt',
    'other' => 'Khác',
    _ => method,
  };
}

int _daysOverdue(Invoice invoice) {
  if (invoice.dueDate == null) return 0;
  return DateTime.now()
      .difference(DateTime(
        invoice.dueDate!.year,
        invoice.dueDate!.month,
        invoice.dueDate!.day,
      ))
      .inDays;
}

int? _daysUntilDue(Invoice invoice) {
  if (invoice.dueDate == null) return null;
  return DateTime(
    invoice.dueDate!.year,
    invoice.dueDate!.month,
    invoice.dueDate!.day,
  ).difference(DateTime.now()).inDays;
}
