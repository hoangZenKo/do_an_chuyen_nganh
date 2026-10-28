import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../auth/auth_navigation.dart';
import '../listings/listing_widgets.dart';
import 'tenant_portal_providers.dart';

const _background = Color(0xFFF7F7F7);
const _panel = Color(0xFFFFFFFF);
const _panelAlt = Color(0xFFF7F7F7);
const _line = Color(0xFFEBEBEB);
const _muted = Color(0xFF717171);
const _ink = Color(0xFF222222);
const _success = Color(0xFF0F8A6A);
const _warning = Color(0xFFD97706);
const _danger = Color(0xFFDC2626);

enum _TenantInvoiceFilter {
  all,
  open,
  overdue,
  pendingProof,
  paid;

  String get label => switch (this) {
        _TenantInvoiceFilter.all => 'Tất cả',
        _TenantInvoiceFilter.open => 'Chưa trả',
        _TenantInvoiceFilter.overdue => 'Trễ hạn',
        _TenantInvoiceFilter.pendingProof => 'Chờ duyệt',
        _TenantInvoiceFilter.paid => 'Đã trả',
      };
}

class TenantInvoicesScreen extends ConsumerStatefulWidget {
  const TenantInvoicesScreen({super.key});

  @override
  ConsumerState<TenantInvoicesScreen> createState() =>
      _TenantInvoicesScreenState();
}

class _TenantInvoicesScreenState extends ConsumerState<TenantInvoicesScreen> {
  var _filter = _TenantInvoiceFilter.all;

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(tenantPortalInvoicesProvider.future),
      ref.refresh(tenantPortalDashboardProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(tenantPortalInvoicesProvider);
    final dashboardAsync = ref.watch(tenantPortalDashboardProvider);

    return ListingTheme(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'Hóa đơn của tôi',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          color: kAirbnbRose,
          onRefresh: _refresh,
          child: invoicesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                _EmptyPanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được hóa đơn',
                  subtitle: '$error',
                  action: TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(tenantPortalInvoicesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ),
              ],
            ),
            data: (invoices) {
              final visible = invoices
                  .where((invoice) => _matchesFilter(invoice, _filter))
                  .toList(growable: false);
              final openAmount = invoices
                  .where((invoice) =>
                      !invoice.isDemo &&
                      invoice.status != InvoiceStatus.cancelled &&
                      invoice.remainingAmount > 0)
                  .fold<int>(
                      0, (sum, invoice) => sum + invoice.remainingAmount);
              final pendingProofs = invoices
                  .expand((invoice) => invoice.paymentProofs)
                  .where((proof) => proof.status == 'pending')
                  .length;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _SummaryPanel(
                    openAmount: openAmount,
                    invoiceCount: invoices.length,
                    pendingProofCount: pendingProofs,
                    overdueCount: dashboardAsync.maybeWhen(
                      data: (dashboard) => dashboard.overdueInvoiceCount,
                      orElse: () => invoices
                          .where((item) => !item.isDemo && item.isOverdue)
                          .length,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                  if (invoices.isEmpty)
                    const _EmptyPanel(
                      icon: Icons.receipt_long_outlined,
                      title: 'Chưa có hóa đơn',
                      subtitle: 'Khi chủ trọ lập hóa đơn, bạn sẽ thấy ở đây.',
                    )
                  else if (visible.isEmpty)
                    _EmptyPanel(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Không có hóa đơn phù hợp',
                      subtitle: 'Đổi bộ lọc để xem các hóa đơn khác.',
                      action: TextButton(
                        onPressed: () => setState(
                          () => _filter = _TenantInvoiceFilter.all,
                        ),
                        child: const Text('Xem tất cả'),
                      ),
                    )
                  else
                    for (final invoice in visible) ...[
                      _InvoiceTile(
                        invoice: invoice,
                        onTap: () => context.push(
                          tenantInvoiceDetailPath(invoice.id),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _matchesFilter(Invoice invoice, _TenantInvoiceFilter filter) {
  return switch (filter) {
    _TenantInvoiceFilter.all => true,
    _TenantInvoiceFilter.open => invoice.remainingAmount > 0,
    _TenantInvoiceFilter.overdue => invoice.isOverdue,
    _TenantInvoiceFilter.pendingProof => _hasPendingProof(invoice),
    _TenantInvoiceFilter.paid => invoice.status == InvoiceStatus.paid,
  };
}

bool _hasPendingProof(Invoice invoice) {
  return invoice.paymentProofs.any((proof) => proof.status == 'pending');
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.openAmount,
    required this.invoiceCount,
    required this.pendingProofCount,
    required this.overdueCount,
  });

  final int openAmount;
  final int invoiceCount;
  final int pendingProofCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final clear = openAmount <= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(
                icon: clear
                    ? Icons.check_circle_rounded
                    : Icons.account_balance_wallet_rounded,
                color: clear ? _success : _danger,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clear ? 'Không còn khoản phải trả' : 'Còn phải trả',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrencyVnd(openAmount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: clear ? _success : _danger,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                icon: Icons.receipt_long_rounded,
                label: '$invoiceCount hóa đơn',
              ),
              _MetricChip(
                icon: Icons.schedule_rounded,
                label: '$overdueCount trễ hạn',
                color: overdueCount > 0 ? _danger : _muted,
              ),
              _MetricChip(
                icon: Icons.hourglass_top_rounded,
                label: '$pendingProofCount chờ duyệt',
                color: pendingProofCount > 0 ? _warning : _muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _TenantInvoiceFilter value;
  final ValueChanged<_TenantInvoiceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TenantInvoiceFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: value == filter,
              onSelected: (_) => onChanged(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _invoiceStatus(invoice);
    return Material(
      color: _panel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(icon: status.icon, color: status.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hóa đơn ${formatMonth(invoice.billingMonth)}${invoice.isDemo ? ' · Kiểm thử' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${invoice.roomName ?? 'Phòng'} · Hạn ${formatDate(invoice.dueDate)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusPill(label: status.label, color: status.color),
                        if (_hasPendingProof(invoice))
                          const _StatusPill(
                            label: 'Chờ chủ trọ duyệt chứng từ',
                            color: _warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrencyVnd(invoice.remainingAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: invoice.remainingAmount > 0 ? _danger : _success,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_InvoiceStatusView _invoiceStatus(Invoice invoice) {
  if (invoice.status == InvoiceStatus.paid) {
    return const _InvoiceStatusView(
      label: 'Đã thanh toán',
      color: _success,
      icon: Icons.check_circle_rounded,
    );
  }
  if (invoice.status == InvoiceStatus.cancelled) {
    return const _InvoiceStatusView(
      label: 'Đã hủy',
      color: _muted,
      icon: Icons.block_rounded,
    );
  }
  if (invoice.isOverdue) {
    return _InvoiceStatusView(
      label: 'Quá hạn ${invoice.daysOverdue} ngày',
      color: _danger,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (invoice.isDueSoon) {
    return const _InvoiceStatusView(
      label: 'Sắp đến hạn',
      color: _warning,
      icon: Icons.event_busy_rounded,
    );
  }
  return _InvoiceStatusView(
    label: invoice.status.label,
    color: invoice.status.color,
    icon: Icons.receipt_long_rounded,
  );
}

class _InvoiceStatusView {
  const _InvoiceStatusView({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.color = _muted,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}
