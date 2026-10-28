import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'billing_providers.dart';

enum _InvoiceFilter {
  all('Tất cả'),
  overdue('Trễ hạn'),
  dueSoon('Sắp hạn'),
  unpaid('Chưa thu'),
  partial('Thu một phần'),
  paid('Đã thu'),
  cancelled('Đã hủy');

  const _InvoiceFilter(this.label);
  final String label;
}

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  _InvoiceFilter _filter = _InvoiceFilter.all;
  final _search = TextEditingController();
  final _month = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshFilters);
    _month.addListener(_refreshFilters);
  }

  @override
  void dispose() {
    _search.removeListener(_refreshFilters);
    _month.removeListener(_refreshFilters);
    _search.dispose();
    _month.dispose();
    super.dispose();
  }

  void _refreshFilters() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final canCreateInvoices = sessionHasPermission(session, 'billing.create');
    final canRecordPayment =
        sessionHasPermission(session, 'billing.record_payment');
    final canApprovePaymentProof =
        sessionHasPermission(session, 'billing.approve_payment_proof');
    final invoicesAsync = ref.watch(invoicesProvider);
    final pendingProofsAsync = canApprovePaymentProof
        ? ref.watch(pendingPaymentProofsProvider)
        : const AsyncValue<List<PaymentProof>>.data([]);

    return invoicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (error, _) => _BillingError(
        message: '$error',
        onRetry: () => ref.invalidate(invoicesProvider),
      ),
      data: (invoices) {
        final visible = _visibleInvoices(invoices);
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(invoicesProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _BillingHeader(
                  invoices: invoices,
                  onAdd: canCreateInvoices
                      ? () => context.push(billingFormRoute)
                      : null,
                  onBulkAdd: canCreateInvoices
                      ? () => context.push(bulkBillingRoute)
                      : null,
                ),
              ),
              if (canApprovePaymentProof)
                SliverToBoxAdapter(
                  child: _PendingProofsPanel(
                    proofsAsync: pendingProofsAsync,
                    onOpenInvoice: (invoiceId) =>
                        context.push(billingDetailPath(invoiceId)),
                    onReview: (proof, status) => _showReviewPaymentProofDialog(
                      context,
                      ref,
                      proof,
                      status,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _InvoiceFilterBar(
                  selected: _filter,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
              ),
              SliverToBoxAdapter(
                child: _InvoiceSearchBar(
                  search: _search,
                  month: _month,
                ),
              ),
              if (invoices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyBilling(
                    onAdd: canCreateInvoices
                        ? () => context.push(billingFormRoute)
                        : null,
                    onBulkAdd: canCreateInvoices
                        ? () => context.push(bulkBillingRoute)
                        : null,
                  ),
                )
              else if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFilteredBilling(filter: _filter),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) => _InvoiceCard(
                      invoice: visible[index],
                      overdue: _isOverdue(visible[index]),
                      dueSoon: _isDueSoon(visible[index]),
                      onOpen: () => context.push(
                        billingDetailPath(visible[index].id),
                      ),
                      onPay: canRecordPayment
                          ? () =>
                              _showPaymentDialog(context, ref, visible[index])
                          : null,
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: visible.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Invoice> _visibleInvoices(List<Invoice> invoices) {
    final filtered = invoices.where((invoice) {
      final statusMatches = switch (_filter) {
        _InvoiceFilter.all => true,
        _InvoiceFilter.overdue => _isOverdue(invoice),
        _InvoiceFilter.dueSoon => _isDueSoon(invoice),
        _InvoiceFilter.unpaid => invoice.status == InvoiceStatus.unpaid,
        _InvoiceFilter.partial => invoice.status == InvoiceStatus.partial,
        _InvoiceFilter.paid => invoice.status == InvoiceStatus.paid,
        _InvoiceFilter.cancelled => invoice.status == InvoiceStatus.cancelled,
      };
      if (!statusMatches) return false;

      final month = _month.text.trim();
      if (month.isNotEmpty) {
        final billingMonth = invoice.billingMonth;
        final invoiceMonth = billingMonth == null
            ? ''
            : '${billingMonth.year}-${billingMonth.month.toString().padLeft(2, '0')}';
        if (!invoiceMonth.startsWith(month)) return false;
      }

      final query = _search.text.toLowerCase().trim();
      if (query.isEmpty) return true;
      final haystack = [
        invoice.roomName,
        invoice.roomId,
        invoice.propertyName,
        invoice.propertyId,
        invoice.tenantName,
        invoice.tenantId,
        formatMonth(invoice.billingMonth),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    if (_filter == _InvoiceFilter.overdue) {
      filtered.sort((a, b) {
        final aDate = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }
    return filtered;
  }
}

bool _isOverdue(Invoice invoice) {
  if (invoice.isOverdue) return true;
  if (invoice.status != InvoiceStatus.unpaid &&
      invoice.status != InvoiceStatus.partial) {
    return false;
  }
  if (invoice.remainingAmount <= 0 || invoice.dueDate == null) return false;
  return _localDate(invoice.dueDate!).isBefore(_localDate(DateTime.now()));
}

bool _isDueSoon(Invoice invoice) {
  if (invoice.isDueSoon && !_isOverdue(invoice)) return true;
  if (invoice.status != InvoiceStatus.unpaid &&
      invoice.status != InvoiceStatus.partial) {
    return false;
  }
  if (invoice.remainingAmount <= 0 || invoice.dueDate == null) return false;
  final days = _daysUntilDue(invoice);
  return days != null && days >= 0 && days <= 7;
}

DateTime _localDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _daysOverdue(Invoice invoice) {
  if (invoice.daysOverdue > 0) return invoice.daysOverdue;
  if (invoice.dueDate == null) return 0;
  return _localDate(DateTime.now())
      .difference(_localDate(invoice.dueDate!))
      .inDays;
}

int? _daysUntilDue(Invoice invoice) {
  if (invoice.daysUntilDue != null) return invoice.daysUntilDue;
  if (invoice.dueDate == null) return null;
  return _localDate(invoice.dueDate!)
      .difference(_localDate(DateTime.now()))
      .inDays;
}

class _BillingHeader extends StatelessWidget {
  const _BillingHeader({
    required this.invoices,
    this.onAdd,
    this.onBulkAdd,
  });

  final List<Invoice> invoices;
  final VoidCallback? onAdd;
  final VoidCallback? onBulkAdd;

  @override
  Widget build(BuildContext context) {
    final billable =
        invoices.where((invoice) => invoice.status != InvoiceStatus.cancelled);
    final receivable = billable.fold<int>(
      0,
      (sum, invoice) => sum + invoice.remainingAmount,
    );
    final collected = billable.fold<int>(
      0,
      (sum, invoice) => sum + invoice.paidAmount,
    );
    final overdueAmount = billable
        .where(_isOverdue)
        .fold<int>(0, (sum, invoice) => sum + invoice.remainingAmount);
    final dueSoonAmount = billable
        .where(_isDueSoon)
        .fold<int>(0, (sum, invoice) => sum + invoice.remainingAmount);
    final overdueCount = billable.where(_isOverdue).length;
    final dueSoonCount = billable.where(_isDueSoon).length;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hóa đơn',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (onBulkAdd != null)
                  TextButton.icon(
                    onPressed: onBulkAdd,
                    icon:
                        const Icon(Icons.auto_awesome_motion_rounded, size: 18),
                    label: const Text('Tạo tháng'),
                  ),
                if (onAdd != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Tạo hóa đơn',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Còn phải thu',
                    value: formatCurrencyVnd(receivable),
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryTile(
                    label: 'Đã thu',
                    value: formatCurrencyVnd(collected),
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            if (overdueCount > 0 || dueSoonCount > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Quá hạn ($overdueCount)',
                      value: formatCurrencyVnd(overdueAmount),
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Sắp hạn ($dueSoonCount)',
                      value: formatCurrencyVnd(dueSoonAmount),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingProofsPanel extends StatelessWidget {
  const _PendingProofsPanel({
    required this.proofsAsync,
    required this.onOpenInvoice,
    required this.onReview,
  });

  final AsyncValue<List<PaymentProof>> proofsAsync;
  final ValueChanged<String> onOpenInvoice;
  final void Function(PaymentProof proof, String status) onReview;

  @override
  Widget build(BuildContext context) {
    return proofsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (proofs) {
        if (proofs.isEmpty) return const SizedBox.shrink();
        final total = proofs.fold<int>(0, (sum, proof) => sum + proof.amount);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${proofs.length} chứng từ chờ duyệt',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      formatCurrencyVnd(total),
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final proof in proofs.take(3)) ...[
                  _PendingProofRow(
                    proof: proof,
                    onOpenInvoice: () => onOpenInvoice(proof.invoiceId),
                    onApprove: () => onReview(proof, 'approved'),
                    onReject: () => onReview(proof, 'rejected'),
                  ),
                  if (proof != proofs.take(3).last) const Divider(height: 16),
                ],
                if (proofs.length > 3) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Còn ${proofs.length - 3} chứng từ khác trong chi tiết hóa đơn.',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingProofRow extends StatelessWidget {
  const _PendingProofRow({
    required this.proof,
    required this.onOpenInvoice,
    required this.onApprove,
    required this.onReject,
  });

  final PaymentProof proof;
  final VoidCallback onOpenInvoice;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${proof.roomName ?? 'Phòng'} · ${proof.tenantName ?? 'Tenant'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      _paymentProofMethodLabel(proof.method),
                      formatDate(proof.submittedAt),
                      if (proof.proofImageUrls.isNotEmpty)
                        '${proof.proofImageUrls.length} file',
                    ].join(' · '),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrencyVnd(proof.amount),
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Duyệt'),
            ),
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Từ chối'),
            ),
            TextButton.icon(
              onPressed: onOpenInvoice,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Mở hóa đơn'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InvoiceFilterBar extends StatelessWidget {
  const _InvoiceFilterBar({required this.selected, required this.onChanged});

  final _InvoiceFilter selected;
  final ValueChanged<_InvoiceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final filter in _InvoiceFilter.values) ...[
            _FilterChip(
              label: filter.label,
              selected: selected == filter,
              color: switch (filter) {
                _InvoiceFilter.overdue => const Color(0xFFEF4444),
                _InvoiceFilter.dueSoon => const Color(0xFFF59E0B),
                _ => AppTheme.primary,
              },
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _InvoiceSearchBar extends StatelessWidget {
  const _InvoiceSearchBar({
    required this.search,
    required this.month,
  });

  final TextEditingController search;
  final TextEditingController month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Tìm phòng, khách thuê',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: month,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_month_rounded),
                hintText: '2026-08',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.overdue,
    required this.dueSoon,
    required this.onOpen,
    this.onPay,
  });

  final Invoice invoice;
  final bool overdue;
  final bool dueSoon;
  final VoidCallback onOpen;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final canPay = onPay != null &&
        invoice.status != InvoiceStatus.cancelled &&
        invoice.remainingAmount > 0;
    final dueText = overdue
        ? 'Hạn thanh toán: ${formatDate(invoice.dueDate)} · Quá hạn ${_daysOverdue(invoice)} ngày'
        : dueSoon
            ? 'Hạn thanh toán: ${formatDate(invoice.dueDate)} · Còn ${_daysUntilDue(invoice) ?? 0} ngày'
            : 'Hạn thanh toán: ${formatDate(invoice.dueDate)}';
    final dueColor = overdue
        ? const Color(0xFFDC2626)
        : dueSoon
            ? const Color(0xFFD97706)
            : const Color(0xFF6B7280);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: overdue
                ? const Color(0xFFFCA5A5)
                : dueSoon
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Phòng ${invoice.roomName ?? invoice.roomId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (overdue) ...[
                  const _OverdueChip(),
                  const SizedBox(width: 6),
                ] else if (dueSoon) ...[
                  const _DueSoonChip(),
                  const SizedBox(width: 6),
                ],
                _StatusChip(status: invoice.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${invoice.tenantName ?? 'Khách thuê'} • ${formatMonth(invoice.billingMonth)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (invoice.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                dueText,
                style: TextStyle(
                  fontSize: 12,
                  color: dueColor,
                  fontWeight:
                      overdue || dueSoon ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _MoneyRow(label: 'Tiền phòng', amount: invoice.rentAmount),
            _MoneyRow(label: 'Điện', amount: invoice.electricityAmount),
            _MoneyRow(label: 'Nước', amount: invoice.waterAmount),
            if (invoice.otherAmount > 0)
              _MoneyRow(label: 'Khác', amount: invoice.otherAmount),
            const Divider(height: 18),
            _MoneyRow(
              label: 'Tổng',
              amount: invoice.totalAmount,
              strong: true,
            ),
            _MoneyRow(label: 'Đã thu', amount: invoice.paidAmount),
            _MoneyRow(
              label: 'Còn lại',
              amount: invoice.remainingAmount,
              strong: true,
              color: invoice.remainingAmount > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
            ),
            if (canPay) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Ghi nhận thanh toán'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverdueChip extends StatelessWidget {
  const _OverdueChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Trễ hạn',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }
}

class _DueSoonChip extends StatelessWidget {
  const _DueSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Sắp hạn',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFD97706),
        ),
      ),
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
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
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

class _EmptyBilling extends StatelessWidget {
  const _EmptyBilling({this.onAdd, this.onBulkAdd});

  final VoidCallback? onAdd;
  final VoidCallback? onBulkAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 14),
            const Text(
              'Chưa có hóa đơn',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tạo hóa đơn đầu tiên từ hợp đồng đang thuê.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            if (onBulkAdd != null)
              ElevatedButton.icon(
                onPressed: onBulkAdd,
                icon: const Icon(Icons.auto_awesome_motion_rounded),
                label: const Text('Tạo hóa đơn tháng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            if (onAdd != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo một hóa đơn'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyFilteredBilling extends StatelessWidget {
  const _EmptyFilteredBilling({required this.filter});

  final _InvoiceFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 14),
            Text(
              filter == _InvoiceFilter.overdue
                  ? 'Không có hóa đơn quá hạn.'
                  : filter == _InvoiceFilter.dueSoon
                      ? 'Không có hóa đơn sắp đến hạn.'
                      : 'Không có hóa đơn ${filter.label.toLowerCase()}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingError extends StatelessWidget {
  const _BillingError({required this.message, required this.onRetry});

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
  final amount = TextEditingController(
    text: invoice.remainingAmount.toString(),
  );
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
                  decoration: const InputDecoration(
                      labelText: 'Phương thức thanh toán'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: paidAt,
                  decoration:
                      const InputDecoration(labelText: 'Ngày thanh toán'),
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
                          error = '$e';
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

Future<void> _showReviewPaymentProofDialog(
  BuildContext context,
  WidgetRef ref,
  PaymentProof proof,
  String status,
) async {
  final note = TextEditingController();
  String? error;
  var loading = false;
  final approving = status == 'approved';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(approving ? 'Duyệt chứng từ' : 'Từ chối chứng từ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${proof.tenantName ?? 'Tenant'} · ${proof.roomName ?? 'Phòng'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrencyVnd(proof.amount)} · ${_paymentProofMethodLabel(proof.method)}',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        approving ? 'Ghi chú cho thanh toán' : 'Lý do từ chối',
                  ),
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
                      if (!approving && note.text.trim().isEmpty) {
                        setState(() => error = 'Nhập lý do từ chối.');
                        return;
                      }
                      setState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(billingPaymentControllerProvider.notifier)
                            .reviewPaymentProof(
                              proofId: proof.id,
                              invoiceId: proof.invoiceId,
                              status: status,
                              note: note.text,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                approving
                                    ? 'Đã duyệt chứng từ thanh toán.'
                                    : 'Đã từ chối chứng từ thanh toán.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          loading = false;
                          error = '$e';
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(approving ? 'Duyệt' : 'Từ chối'),
            ),
          ],
        ),
      );
    },
  );

  note.dispose();
}

String _paymentProofMethodLabel(String method) {
  return switch (method) {
    'bank_transfer' || 'bankTransfer' => 'Chuyển khoản',
    'cash' => 'Tiền mặt',
    'other' => 'Khác',
    _ => method,
  };
}

String _todayIsoDate() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
