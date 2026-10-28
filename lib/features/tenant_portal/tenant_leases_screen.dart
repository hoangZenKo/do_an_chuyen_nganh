import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/tenant_portal.dart';
import '../listings/listing_widgets.dart';
import '../listings/handover_screen.dart';
import 'tenant_portal_providers.dart';
import '../listings/review_composer.dart';
import '../listings/reviews_providers.dart';
import '../tenants/tenant_lifecycle_screen.dart';

const _background = Color(0xFFF7F7F7);
const _panel = Color(0xFFFFFFFF);
const _panelAlt = Color(0xFFF7F7F7);
const _line = Color(0xFFEBEBEB);
const _muted = Color(0xFF717171);
const _ink = Color(0xFF222222);
const _success = Color(0xFF0F8A6A);

enum _TenantLeaseFilter {
  all,
  active,
  ended;

  String get label => switch (this) {
        _TenantLeaseFilter.all => 'Tất cả',
        _TenantLeaseFilter.active => 'Đang thuê',
        _TenantLeaseFilter.ended => 'Đã kết thúc',
      };
}

class TenantLeasesScreen extends ConsumerStatefulWidget {
  const TenantLeasesScreen({super.key});

  @override
  ConsumerState<TenantLeasesScreen> createState() => _TenantLeasesScreenState();
}

class _TenantLeasesScreenState extends ConsumerState<TenantLeasesScreen> {
  var _filter = _TenantLeaseFilter.all;

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(tenantPortalLeasesProvider.future),
      ref.refresh(tenantPortalDashboardProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final leasesAsync = ref.watch(tenantPortalLeasesProvider);

    return ListingTheme(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'Hợp đồng của tôi',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          color: kAirbnbRose,
          onRefresh: _refresh,
          child: leasesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                _EmptyPanel(
                  icon: Icons.cloud_off_rounded,
                  title: 'Không tải được hợp đồng',
                  subtitle: '$error',
                  action: TextButton.icon(
                    onPressed: () => ref.invalidate(tenantPortalLeasesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                ),
              ],
            ),
            data: (leases) {
              final visible = leases
                  .where((lease) => _matchesFilter(lease, _filter))
                  .toList(growable: false);
              final activeLease = leases
                  .where((lease) => lease.isActive)
                  .cast<TenantPortalLease?>()
                  .firstOrNull;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _SummaryPanel(
                    lease: activeLease,
                    total: leases.length,
                    historyCount:
                        leases.where((lease) => !lease.isActive).length,
                  ),
                  const SizedBox(height: 14),
                  _FilterBar(
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 14),
                  if (leases.isEmpty)
                    const _EmptyPanel(
                      icon: Icons.home_work_outlined,
                      title: 'Chưa có hợp đồng',
                      subtitle:
                          'Khi chủ trọ kích hoạt hợp đồng, thông tin phòng và tiền thuê sẽ xuất hiện ở đây.',
                    )
                  else if (visible.isEmpty)
                    _EmptyPanel(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Không có hợp đồng phù hợp',
                      subtitle: 'Đổi bộ lọc để xem các hợp đồng khác.',
                      action: TextButton(
                        onPressed: () => setState(
                          () => _filter = _TenantLeaseFilter.all,
                        ),
                        child: const Text('Xem tất cả'),
                      ),
                    )
                  else
                    for (final lease in visible) ...[
                      _LeaseTile(
                        lease: lease,
                        onTap: () => _showLeaseDetailSheet(context, lease),
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

bool _matchesFilter(TenantPortalLease lease, _TenantLeaseFilter filter) {
  return switch (filter) {
    _TenantLeaseFilter.all => true,
    _TenantLeaseFilter.active => lease.isActive,
    _TenantLeaseFilter.ended => !lease.isActive,
  };
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.lease,
    required this.total,
    required this.historyCount,
  });

  final TenantPortalLease? lease;
  final int total;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    final active = lease;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBubble(
            icon: active == null ? Icons.home_work_outlined : Icons.home,
            color: active == null ? _muted : _success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active == null ? 'Chưa có hợp đồng hiệu lực' : 'Đang thuê',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active == null
                      ? '$total hợp đồng'
                      : 'Phòng ${active.roomName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active == null ? _muted : _success,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      icon: Icons.home_work_rounded,
                      label: active?.propertyName ?? 'Chưa có phòng đang thuê',
                      color: active == null ? _muted : _success,
                    ),
                    _MetricChip(
                      icon: Icons.history_rounded,
                      label: '$historyCount hợp đồng cũ',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _TenantLeaseFilter value;
  final ValueChanged<_TenantLeaseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TenantLeaseFilter.values) ...[
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

class _LeaseTile extends StatelessWidget {
  const _LeaseTile({required this.lease, required this.onTap});

  final TenantPortalLease lease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = lease.isActive ? _success : _muted;
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
              _IconBubble(
                icon: lease.isActive ? Icons.home_rounded : Icons.history,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phòng ${lease.roomName} · ${lease.propertyName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Tiền thuê ${formatCurrencyVnd(lease.monthlyRent)} · Cọc ${formatCurrencyVnd(lease.deposit)}',
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
                        _StatusPill(
                          label: lease.occupancyLabel,
                          color: color,
                        ),
                        _StatusPill(
                          label:
                              '${formatDate(lease.startDate)} - ${lease.endDate == null ? 'hiện tại' : formatDate(lease.endDate)}',
                          color: _muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showLeaseDetailSheet(
  BuildContext context,
  TenantPortalLease lease,
) {
  final color = lease.isActive ? _success : _muted;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: _panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBubble(
                  icon: lease.isActive ? Icons.home_rounded : Icons.history,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phòng ${lease.roomName}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusPill(
                        label: lease.occupancyLabel,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer(
                builder: (context, ref, _) => ref
                    .watch(reviewContextProvider(lease.id))
                    .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) =>
                            Text('Đánh giá: ${listingError(error)}'),
                        data: (reviewContext) =>
                            ReviewComposer(contextData: reviewContext))),
            const SizedBox(height: 16),
            _DetailLine(
              icon: Icons.apartment_rounded,
              label: 'Khu trọ',
              value: lease.propertyName,
            ),
            if (lease.propertyAddress?.trim().isNotEmpty == true)
              _DetailLine(
                icon: Icons.location_on_rounded,
                label: 'Địa chỉ',
                value: lease.propertyAddress!.trim(),
              ),
            _DetailLine(
              icon: Icons.payments_rounded,
              label: 'Tiền thuê',
              value: formatCurrencyVnd(lease.monthlyRent),
            ),
            _DetailLine(
              icon: Icons.savings_rounded,
              label: 'Cọc thỏa thuận',
              value: formatCurrencyVnd(lease.deposit),
            ),
            _DetailLine(
              icon: Icons.event_available_rounded,
              label: 'Ngày bắt đầu',
              value: formatDate(lease.startDate),
            ),
            _DetailLine(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Cọc đang giữ (đã ghi nhận)',
                value: formatCurrencyVnd(lease.depositBalance)),
            const SizedBox(height: 16),
            const Text('Lịch sử tiền cọc',
                style: TextStyle(fontWeight: FontWeight.w800)),
            if (lease.depositTransactions.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                      'Chưa có giao dịch cọc được ghi nhận. Số cọc thỏa thuận không đồng nghĩa đã thanh toán.')),
            for (final transaction in lease.depositTransactions)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${transaction.label} · ${formatCurrencyVnd(transaction.amount)}'),
                  subtitle: Text(
                      '${formatDate(transaction.occurredAt)}${transaction.note == null ? '' : '\n${transaction.note}'}')),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => TenantLifecycleScreen(
                            leaseId: lease.id, tenantLease: lease))),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Yêu cầu, người ở cùng & quyết toán')),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => HandoverScreen(leaseId: lease.id))),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Bàn giao & đối chiếu cọc')),
            _DetailLine(
              icon: Icons.event_busy_rounded,
              label: 'Ngày kết thúc',
              value: lease.endDate == null
                  ? 'Chưa kết thúc'
                  : formatDate(lease.endDate),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _muted, size: 18),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _line,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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
