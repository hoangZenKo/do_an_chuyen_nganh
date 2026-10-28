import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/messaging/messaging_launcher.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/lease.dart';
import '../../models/tenant.dart';
import '../auth/auth_navigation.dart';
import 'lease_pdf.dart';
import 'tenant_providers.dart';

/// Tenant profile with lease history and lifecycle actions.
class TenantDetailScreen extends ConsumerStatefulWidget {
  const TenantDetailScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends ConsumerState<TenantDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantDetailProvider(widget.tenantId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Chi tiết người thuê'),
        actions: [
          tenantAsync.maybeWhen(
            data: (tenant) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tenant.isActive)
                  TextButton.icon(
                    onPressed: () =>
                        context.push(tenantFormPath(tenantId: tenant.id)),
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppTheme.primary),
                    label: const Text('Sửa',
                        style: TextStyle(color: AppTheme.primary)),
                  ),
                _TenantActionsMenu(
                  tenant: tenant,
                  onDeactivate: () => _setActive(tenant, false),
                  onReactivate: () => _setActive(tenant, true),
                  onDelete: () => _delete(tenant),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: tenantAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => Center(
          child:
              Text('$error', style: const TextStyle(color: Color(0xFF6B7280))),
        ),
        data: (tenant) => _Body(tenant: tenant),
      ),
    );
  }

  Future<void> _setActive(Tenant tenant, bool isActive) async {
    final confirmed = await _confirm(
      title: isActive
          ? 'Kích hoạt lại người thuê?'
          : 'Ngưng hoạt động người thuê?',
      message: isActive
          ? 'Người thuê sẽ quay lại danh sách hoạt động và có thể tạo hợp đồng mới.'
          : 'Người thuê sẽ bị ẩn khỏi danh sách vận hành. Nếu đang có hợp đồng active, backend sẽ chặn thao tác này.',
      confirmLabel: isActive ? 'Kích hoạt' : 'Ngưng hoạt động',
      destructive: !isActive,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(tenantFormControllerProvider.notifier).setActive(
            tenantId: tenant.id,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? 'Đã kích hoạt người thuê'
                : 'Đã ngưng hoạt động người thuê',
          ),
        ),
      );
    } catch (error) {
      _showError(error, 'Không thể cập nhật người thuê.');
    }
  }

  Future<void> _delete(Tenant tenant) async {
    final confirmed = await _confirm(
      title: 'Xóa vĩnh viễn người thuê?',
      message:
          'Chỉ xóa được người thuê chưa có hợp đồng hoặc hóa đơn. Người thuê đã có lịch sử nên dùng Ngưng hoạt động.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(tenantFormControllerProvider.notifier).delete(tenant.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${tenant.fullName}')),
      );
      context.pop();
    } catch (error) {
      _showError(error, 'Không thể xóa người thuê.');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required bool destructive,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? const Color(0xFFEF4444) : AppTheme.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showError(Object error, String fallback) {
    if (!mounted) return;
    final message = error is ApiFailure ? error.message : fallback;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TenantActionsMenu extends StatelessWidget {
  const _TenantActionsMenu({
    required this.tenant,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onDelete,
  });

  final Tenant tenant;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'deactivate') onDeactivate();
        if (value == 'reactivate') onReactivate();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        if (tenant.isActive)
          const PopupMenuItem(
            value: 'deactivate',
            child: Text('Ngưng hoạt động'),
          )
        else
          const PopupMenuItem(
            value: 'reactivate',
            child: Text('Kích hoạt lại'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text(
            'Xóa vĩnh viễn',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leasesAsync = ref.watch(tenantLeasesProvider(tenant.id));
    final overviewAsync = ref.watch(tenantOverviewProvider(tenant.id));
    final hasActive = tenant.activeLease != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      tenant.fullName.trim().isNotEmpty
                          ? tenant.fullName.trim().characters.first.toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tenant.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            if (!tenant.isActive) const _InactiveBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (hasActive && tenant.activeLease?.roomName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.meeting_room_rounded, size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Đang thuê ${tenant.activeLease!.roomName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            tenant.phone ?? 'Chưa cập nhật SĐT',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: tenant.phone != null
                          ? () {
                              Clipboard.setData(ClipboardData(text: tenant.phone!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Đã copy SĐT ${tenant.phone}')),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Gọi SĐT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openMessagingApp(
                        context,
                        tenantId: tenant.id,
                        tenantName: tenant.fullName,
                        roomName: tenant.activeLease?.roomName,
                        template: 'call_back',
                      ),
                      icon: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset('assets/images/zalo_logo.png', width: 16, height: 16),
                      ),
                      label: const Text('Gửi Zalo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0068FF),
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              if (!tenant.isActive) ...[
                const SizedBox(height: 10),
                const _InactiveNotice(),
              ],
              if (hasActive) ...[
                const SizedBox(height: 10),
                const _ActiveLeaseNotice(),
              ],
              const SizedBox(height: 16),
              _Row(label: 'SĐT', value: tenant.phone ?? '—'),
              const _Divider(),
              _Row(label: 'CCCD/CMND', value: tenant.idNumber ?? '—'),
              const _Divider(),
              _Row(
                label: 'Tài khoản',
                value: tenant.accountEmail ?? 'Chưa tạo',
              ),
              if (tenant.note != null && tenant.note!.trim().isNotEmpty) ...[
                const _Divider(),
                _Row(label: 'Ghi chú', value: tenant.note!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        overviewAsync.when(
          loading: () => const _Card(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
          error: (error, _) => _Card(
            child: Text(
              '$error',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          data: (overview) => _TenantOverviewCard(
            tenant: tenant,
            overview: overview,
          ),
        ),
        const SizedBox(height: 16),
        // Primary action depends on whether the tenant currently rents a room.
        if (tenant.isActive && !hasActive)
          _ActionButton(
            icon: Icons.assignment_add,
            label: 'Tạo hợp đồng thuê',
            onPressed: () => context.push(leaseFormPath(tenantId: tenant.id)),
          ),
        if (tenant.isActive && tenant.accountEmail == null) ...[
          if (tenant.isActive && !hasActive) const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Tạo mã mời tenant',
            onPressed: () => _showTenantInviteDialog(context, ref, tenant),
          ),
        ],
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Lịch sử hợp đồng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 10),
        leasesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary)),
          ),
          error: (error, _) =>
              Text('$error', style: const TextStyle(color: Color(0xFF6B7280))),
          data: (leases) => leases.isEmpty
              ? _Card(
                  child: Text(
                    'Chưa có hợp đồng nào.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : Column(
                  children: leases
                      .map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LeaseCard(
                              lease: l,
                              tenant: tenant,
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _InactiveNotice extends StatelessWidget {
  const _InactiveNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Người thuê đang ngưng hoạt động nên không xuất hiện trong danh sách vận hành.',
        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _ActiveLeaseNotice extends StatelessWidget {
  const _ActiveLeaseNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Kết thúc hợp đồng active trước khi ngưng hoạt động hoặc xóa người thuê.',
        style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
      ),
    );
  }
}

class _TenantOverviewCard extends StatelessWidget {
  const _TenantOverviewCard({
    required this.tenant,
    required this.overview,
  });

  final Tenant tenant;
  final TenantOverview overview;

  @override
  Widget build(BuildContext context) {
    final financial = overview.financial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tổng quan tenant',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _AccountBadge(
                    email: overview.account?.email ?? tenant.accountEmail,
                    isActive: overview.account?.isActive ?? true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FinanceTile(
                    label: 'Còn nợ',
                    value: formatCurrencyVnd(financial.outstandingAmount),
                    icon: Icons.account_balance_wallet_rounded,
                    color: financial.outstandingAmount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                  ),
                  _FinanceTile(
                    label: 'Quá hạn',
                    value: formatCurrencyVnd(financial.overdueAmount),
                    icon: Icons.warning_amber_rounded,
                    color: financial.overdueAmount > 0
                        ? const Color(0xFFD97706)
                        : const Color(0xFF10B981),
                  ),
                  _FinanceTile(
                    label: 'Đã thu',
                    value: formatCurrencyVnd(financial.totalPaid),
                    icon: Icons.payments_rounded,
                    color: AppTheme.primary,
                  ),
                  _FinanceTile(
                    label: 'Số dư cọc',
                    value: formatCurrencyVnd(financial.depositBalance),
                    icon: Icons.savings_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat('Hóa đơn mở', '${financial.openInvoiceCount}'),
                  _MiniStat('Proof chờ', '${financial.pendingProofCount}'),
                  _MiniStat('Sửa chữa mở', '${financial.maintenanceOpenCount}'),
                  _MiniStat('Hợp đồng active', '${financial.activeLeaseCount}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _TimelineCard(events: overview.timeline),
      ],
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.email, required this.isActive});

  final String? email;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final hasAccount = email?.trim().isNotEmpty == true;
    final color = !hasAccount
        ? const Color(0xFF6B7280)
        : isActive
            ? const Color(0xFF10B981)
            : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasAccount ? (isActive ? 'Có tài khoản' : 'TK bị khóa') : 'Chưa có TK',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  const _FinanceTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<TenantTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Timeline vận hành',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text(
              'Chưa có sự kiện vận hành.',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            ...events.take(8).map(_TimelineRow.new),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.event);

  final TenantTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type, event.status);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_eventIcon(event.type), size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      formatDate(event.occurredAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (event.roomName?.trim().isNotEmpty == true)
                      'Phòng ${event.roomName}',
                    event.description,
                    if (event.amount != null) formatCurrencyVnd(event.amount!),
                  ].where((part) => part.trim().isNotEmpty).join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    return switch (type) {
      'lease_started' ||
      'lease_ended' ||
      'lease_changed' =>
        Icons.assignment_rounded,
      'invoice_created' => Icons.receipt_long_rounded,
      'payment' => Icons.payments_rounded,
      'payment_proof' => Icons.upload_file_rounded,
      'deposit' => Icons.savings_rounded,
      'maintenance' => Icons.construction_rounded,
      _ => Icons.history_rounded,
    };
  }

  Color _eventColor(String type, String? status) {
    if (status == 'cancelled' || status == 'reversal') {
      return const Color(0xFF6B7280);
    }
    if (status == 'unpaid' || status == 'pending') {
      return const Color(0xFFD97706);
    }
    return switch (type) {
      'payment' => const Color(0xFF10B981),
      'payment_proof' => const Color(0xFF2563EB),
      'maintenance' => const Color(0xFF7C3AED),
      'deposit' => const Color(0xFF0D6E62),
      _ => AppTheme.primary,
    };
  }
}

class _LeaseCard extends ConsumerStatefulWidget {
  const _LeaseCard({required this.lease, required this.tenant});

  final Lease lease;
  final Tenant tenant;

  @override
  ConsumerState<_LeaseCard> createState() => _LeaseCardState();
}

class _LeaseCardState extends ConsumerState<_LeaseCard> {
  bool _ending = false;

  Future<void> _end() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc hợp đồng?'),
        content: const Text(
          'Phòng sẽ được chuyển về trạng thái trống sau khi hợp đồng kết thúc.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);
    try {
      await ref.read(leaseFormControllerProvider.notifier).end(
            leaseId: widget.lease.id,
            tenantId: widget.tenant.id,
          );
    } catch (error) {
      if (!mounted) return;
      setState(() => _ending = false);
      final message =
          error is ApiFailure ? error.message : 'Không thể kết thúc hợp đồng.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lease = widget.lease;
    final isActive = lease.status == LeaseStatus.active;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lease.roomName ?? 'Phòng',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lease.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lease.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: lease.status.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Giá thuê: ${formatCurrencyVnd(lease.monthlyRent)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 2),
          Text(
            'Cọc hợp đồng: ${formatCurrencyVnd(lease.deposit)} · Số dư cọc: ${formatCurrencyVnd(lease.depositBalance)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 2),
          Text(
            'Từ ${formatDate(lease.startDate)}'
            '${lease.endDate != null ? ' đến ${formatDate(lease.endDate)}' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showRenewDialog(context, ref, lease, widget.tenant),
                    icon: const Icon(Icons.event_repeat_rounded, size: 18),
                    label: const Text('Gia hạn'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDepositDialog(context, ref, lease, widget.tenant),
                    icon: const Icon(Icons.savings_rounded, size: 18),
                    label: const Text('Cọc'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _ending ? null : _end,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _ending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFFEF4444)),
                      )
                    : const Text('Kết thúc hợp đồng'),
              ),
            ),
          ],
          if (lease.depositTransactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...lease.depositTransactions.take(3).map(
                  (item) => Text(
                    '${item.label}: ${formatCurrencyVnd(item.amount)} · ${formatDate(item.occurredAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => shareLeasePdf(
                lease: lease,
                tenant: widget.tenant,
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Xuất PDF hợp đồng'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

Future<void> _showTenantInviteDialog(
  BuildContext context,
  WidgetRef ref,
  Tenant tenant,
) async {
  final email = TextEditingController();
  String? error;
  Map<String, dynamic>? invite;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tạo mã mời tenant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (invite == null) ...[
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email đăng nhập'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tenant sẽ tự đặt mật khẩu bằng link kích hoạt.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ] else ...[
                  _InviteCopyRow(
                    label: 'Mã kích hoạt',
                    value: invite!['inviteCode']?.toString() ?? '',
                  ),
                  const SizedBox(height: 10),
                  _InviteCopyRow(
                    label: 'Link kích hoạt',
                    value: invite!['activationPath']?.toString() ?? '',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hết hạn: ${invite!['expiresAt'] ?? 'Không rõ'}',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
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
              child: Text(invite == null ? 'Hủy' : 'Đóng'),
            ),
            if (invite == null)
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final emailText = email.text.trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(emailText)) {
                          setState(() => error = 'Nhập email hợp lệ.');
                          return;
                        }
                        setState(() {
                          loading = true;
                          error = null;
                        });
                        try {
                          final result = await ref
                              .read(tenantFormControllerProvider.notifier)
                              .createInvite(
                                tenantId: tenant.id,
                                email: emailText,
                              );
                          setState(() {
                            invite = result;
                            loading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã tạo mã mời tenant.'),
                              ),
                            );
                          }
                        } catch (err) {
                          setState(() {
                            loading = false;
                            error = err is ApiFailure
                                ? err.message
                                : 'Không thể tạo mã mời.';
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo mã'),
              ),
          ],
        ),
      );
    },
  );

  email.dispose();
}

Future<void> _showDepositDialog(
  BuildContext context,
  WidgetRef ref,
  Lease lease,
  Tenant tenant,
) async {
  final amount = TextEditingController();
  final note = TextEditingController();
  var type = 'collected';
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Ghi nhận tiền cọc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'collected', child: Text('Thu cọc')),
                DropdownMenuItem(value: 'refunded', child: Text('Hoàn cọc')),
                DropdownMenuItem(value: 'deducted', child: Text('Khấu trừ')),
                DropdownMenuItem(
                    value: 'adjustment', child: Text('Điều chỉnh tăng')),
              ],
              onChanged: (value) => setState(() => type = value ?? type),
              decoration: const InputDecoration(labelText: 'Loại giao dịch'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Số tiền'),
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if ((int.tryParse(amount.text.trim()) ?? 0) <= 0) {
                setState(() => error = 'Nhập số tiền hợp lệ.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
  final parsedAmount = int.tryParse(amount.text.trim());
  final noteText = note.text;
  amount.dispose();
  note.dispose();
  if (confirmed != true || parsedAmount == null) return;

  try {
    await ref.read(leaseFormControllerProvider.notifier).depositTransaction(
          leaseId: lease.id,
          tenantId: tenant.id,
          type: type,
          amount: parsedAmount,
          note: noteText,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận giao dịch cọc.')),
      );
    }
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$err')));
    }
  }
}

Future<void> _showRenewDialog(
  BuildContext context,
  WidgetRef ref,
  Lease lease,
  Tenant tenant,
) async {
  final endDate = TextEditingController(
    text: lease.endDate?.toIso8601String().split('T').first ?? '',
  );
  final monthlyRent = TextEditingController(text: lease.monthlyRent.toString());
  final deposit = TextEditingController(text: lease.deposit.toString());
  final note = TextEditingController();
  String? error;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Gia hạn hợp đồng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endDate,
              decoration: const InputDecoration(
                labelText: 'Ngày kết thúc mới',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            TextField(
              controller: monthlyRent,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Tiền thuê mới'),
            ),
            TextField(
              controller: deposit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Tiền cọc hợp đồng'),
            ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (DateTime.tryParse(endDate.text.trim()) == null) {
                setState(() => error = 'Nhập ngày hợp lệ.');
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Gia hạn'),
          ),
        ],
      ),
    ),
  );
  final parsedEndDate = DateTime.tryParse(endDate.text.trim());
  final parsedRent = int.tryParse(monthlyRent.text.trim());
  final parsedDeposit = int.tryParse(deposit.text.trim());
  final noteText = note.text;
  endDate.dispose();
  monthlyRent.dispose();
  deposit.dispose();
  note.dispose();
  if (confirmed != true || parsedEndDate == null) return;

  try {
    await ref.read(leaseFormControllerProvider.notifier).renew(
          leaseId: lease.id,
          tenantId: tenant.id,
          endDate: parsedEndDate,
          monthlyRent: parsedRent,
          deposit: parsedDeposit,
          note: noteText,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gia hạn hợp đồng.')),
      );
    }
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$err')));
    }
  }
}

class _InviteCopyRow extends StatelessWidget {
  const _InviteCopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: value.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã copy $label')),
                      );
                    }
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFF3F4F6));
}
