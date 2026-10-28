import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/messaging/messaging_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../../models/maintenance.dart';
import '../../models/notification_delivery.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'tenant_portal_providers.dart';

class TenantPortalScreen extends ConsumerStatefulWidget {
  const TenantPortalScreen({super.key});

  @override
  ConsumerState<TenantPortalScreen> createState() =>
      _TenantPortalScreenState();
}

class _TenantPortalScreenState extends ConsumerState<TenantPortalScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _zaloKey = GlobalKey();
  final GlobalKey _invoicesKey = GlobalKey();
  final GlobalKey _maintenanceKey = GlobalKey();
  final GlobalKey _leasesKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        ref.refresh(tenantPortalDashboardProvider.future),
        ref.refresh(tenantPortalInvoicesProvider.future),
        ref.refresh(tenantPortalLeasesProvider.future),
        ref.refresh(tenantPortalNotificationsProvider.future),
        ref.refresh(tenantPortalZaloMessagesProvider.future),
        ref.refresh(tenantPortalMaintenanceProvider.future),
      ]);
    } catch (_) {
      // Pull-to-refresh should complete even when one source errors.
    }
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tenantPortalDashboardProvider);
    final invoicesAsync = ref.watch(tenantPortalInvoicesProvider);
    final leasesAsync = ref.watch(tenantPortalLeasesProvider);
    final notificationsAsync = ref.watch(tenantPortalNotificationsProvider);
    final zaloMessagesAsync = ref.watch(tenantPortalZaloMessagesProvider);
    final maintenanceAsync = ref.watch(tenantPortalMaintenanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        title: const Text('Tổng quan thuê nhà'),
        actions: [
          IconButton(
            tooltip: 'Đổi mật khẩu',
            onPressed: () => context.push(tenantPasswordRoute),
            icon: const Icon(Icons.lock_reset_rounded),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            dashboardAsync.when(
              loading: () => const _HeroLoadingBand(),
              error: (error, _) => _HeroErrorBand(
                message: '$error',
                onRetry: () => ref.invalidate(tenantPortalDashboardProvider),
              ),
              data: (dashboard) => _HeroBand(
                dashboard: dashboard,
                onPrimaryAction: dashboard.nextInvoice == null
                    ? () => _scrollTo(_maintenanceKey)
                    : () => context.push(
                        tenantInvoiceDetailPath(dashboard.nextInvoice!.id),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              title: 'Lối tắt',
              icon: Icons.grid_view_rounded,
              child: _ActionGrid(
                onInvoices: () => _scrollTo(_invoicesKey),
                onMaintenance: () => _scrollTo(_maintenanceKey),
                onZalo: () => _openTenantMessenger(context, dashboardAsync),
                onNotifications: () => _scrollTo(_notificationsKey),
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              key: _zaloKey,
              title: 'Zalo từ chủ trọ',
              icon: Icons.chat_bubble_rounded,
              trailing: zaloMessagesAsync.maybeWhen(
                data: (messages) {
                  final unread = messages.where((message) => !message.read).length;
                  return Text(
                    unread > 0 ? '$unread chưa đọc' : '${messages.length} tin',
                    style: TextStyle(
                      color: unread > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              child: zaloMessagesAsync.when(
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(
                  message: 'Không tải được tin Zalo: $error',
                  onRetry: () => ref.invalidate(tenantPortalZaloMessagesProvider),
                ),
                data: (messages) => _ZaloPreview(
                  messages: messages,
                  onOpen: () => _openTenantMessenger(context, dashboardAsync),
                  onMarkRead: (message) => ref
                      .read(tenantNotificationControllerProvider.notifier)
                      .markZaloRead(message.id),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              key: _invoicesKey,
              title: 'Hóa đơn',
              icon: Icons.receipt_long_rounded,
              trailing: dashboardAsync.maybeWhen(
                data: (dashboard) => Text(
                  formatCurrencyVnd(
                    dashboard.outstandingAmount > 0
                        ? dashboard.outstandingAmount
                        : 0,
                  ),
                  style: TextStyle(
                    color: dashboard.outstandingAmount > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              child: invoicesAsync.when(
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(
                  message: 'Không tải được hóa đơn: $error',
                  onRetry: () => ref.invalidate(tenantPortalInvoicesProvider),
                ),
                data: (invoices) {
                  final openInvoices =
                      invoices.where((invoice) => invoice.remainingAmount > 0).toList();
                  final totalDebt = openInvoices.fold<int>(
                    0,
                    (sum, invoice) => sum + invoice.remainingAmount,
                  );
                  final nextInvoice = openInvoices.isEmpty ? null : openInvoices.first;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nextInvoice != null) ...[
                        _InvoiceLead(
                          invoice: nextInvoice,
                          onOpen: () => context.push(
                            tenantInvoiceDetailPath(nextInvoice.id),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (invoices.isEmpty)
                        const _EmptyState(
                          title: 'Chưa có hóa đơn.',
                          subtitle: 'Khi có hóa đơn mới, bạn sẽ thấy ở đây.',
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < invoices.take(4).length; i++) ...[
                              _InvoiceRow(
                                invoice: invoices[i],
                                onTap: () => context.push(
                                  tenantInvoiceDetailPath(invoices[i].id),
                                ),
                              ),
                              if (i < invoices.take(4).length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      if (invoices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          totalDebt > 0
                              ? 'Tổng còn phải thu: ${formatCurrencyVnd(totalDebt)}'
                              : 'Tất cả hóa đơn đã được thanh toán.',
                          style: TextStyle(
                            color: totalDebt > 0
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              key: _maintenanceKey,
              title: 'Sửa chữa',
              icon: Icons.construction_rounded,
              trailing: IconButton(
                tooltip: 'Báo sửa chữa',
                onPressed: () => _showMaintenanceDialog(context, ref),
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF6F2),
                  foregroundColor: AppTheme.primaryDark,
                ),
              ),
              child: maintenanceAsync.when(
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(
                  message: 'Không tải được sửa chữa: $error',
                  onRetry: () => ref.invalidate(tenantPortalMaintenanceProvider),
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const _EmptyState(
                      title: 'Chưa có yêu cầu sửa chữa.',
                      subtitle: 'Bạn có thể gửi báo hỏng ngay từ nút + ở góc phải.',
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < tickets.take(4).length; i++) ...[
                        _MaintenanceRow(
                          ticket: tickets[i],
                          onTap: () => _showMaintenanceCommentDialog(
                            context,
                            ref,
                            tickets[i],
                          ),
                        ),
                        if (i < tickets.take(4).length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              key: _leasesKey,
              title: 'Hợp đồng',
              icon: Icons.home_work_rounded,
              trailing: leasesAsync.maybeWhen(
                data: (leases) => Text(
                  '${leases.length} mục',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              child: leasesAsync.when(
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(
                  message: 'Không tải được hợp đồng: $error',
                  onRetry: () => ref.invalidate(tenantPortalLeasesProvider),
                ),
                data: (leases) {
                  if (leases.isEmpty) {
                    return const _EmptyState(
                      title: 'Chưa có lịch sử hợp đồng.',
                      subtitle: 'Thông tin hợp đồng sẽ xuất hiện ở đây khi có dữ liệu.',
                    );
                  }
                  final activeLease = leases.firstWhere(
                    (lease) => lease.isActive,
                    orElse: () => leases.first,
                  );
                  final history = leases.where((lease) => lease.id != activeLease.id).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeaseHighlight(lease: activeLease),
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (var i = 0; i < history.take(3).length; i++) ...[
                          _LeaseRow(lease: history[i]),
                          if (i < history.take(3).length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _TenantSection(
              key: _notificationsKey,
              title: 'Thông báo',
              icon: Icons.notifications_rounded,
              trailing: notificationsAsync.maybeWhen(
                data: (items) {
                  final unread = items.where((item) => !item.read).length;
                  return Text(
                    unread > 0 ? '$unread chưa đọc' : '${items.length} tin',
                    style: TextStyle(
                      color: unread > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              child: notificationsAsync.when(
                loading: () => const _SectionLoading(),
                error: (error, _) => _SectionError(
                  message: 'Không tải được thông báo: $error',
                  onRetry: () => ref.invalidate(tenantPortalNotificationsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptyState(
                      title: 'Chưa có thông báo.',
                      subtitle: 'Các nhắc nhở và cập nhật mới sẽ xuất hiện tại đây.',
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < items.take(4).length; i++) ...[
                        _NotificationRow(
                          item: items[i],
                          onTap: items[i].read
                              ? null
                              : () => ref
                                  .read(tenantNotificationControllerProvider.notifier)
                                  .markRead(items[i].id),
                        ),
                        if (i < items.take(4).length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTenantMessenger(
    BuildContext context,
    AsyncValue<TenantDashboard> dashboardAsync,
  ) {
    final profile = dashboardAsync.asData?.value.profile;
    openMessagingApp(
      context,
      tenantId: profile?.id,
      tenantName: profile?.fullName,
      roomName: profile?.activeLease?.roomName,
      template: 'call_back',
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.dashboard,
    required this.onPrimaryAction,
  });

  final TenantDashboard dashboard;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile;
    final lease = profile.activeLease;
    final nextInvoice = dashboard.nextInvoice;
    final hasDebt = dashboard.outstandingAmount > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      child: Text(
                        _initials(profile.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${profile.fullName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lease == null
                                ? 'Chủ trọ: ${profile.landlordName}'
                                : 'Phòng ${lease.roomName} · ${lease.propertyName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lease?.propertyAddress?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              lease!.propertyAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.74),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusPill(
                      icon: lease == null
                          ? Icons.hourglass_empty_rounded
                          : Icons.verified_rounded,
                      label: lease == null ? 'Chưa có hợp đồng' : 'Đang thuê',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDebt ? 'Còn phải thanh toán' : 'Số dư hiện tại',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrencyVnd(dashboard.outstandingAmount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextInvoice == null
                                ? 'Chưa có hóa đơn cần xử lý.'
                                : nextInvoice.isOverdue
                                    ? 'Hóa đơn ${formatMonth(nextInvoice.billingMonth)} đã quá hạn ${nextInvoice.daysOverdue} ngày.'
                                    : 'Hóa đơn ${formatMonth(nextInvoice.billingMonth)} đang chờ đến hạn ${formatDate(nextInvoice.dueDate)}.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onPrimaryAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        nextInvoice == null ? 'Báo sửa chữa' : 'Mở hóa đơn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroStatChip(
                      icon: Icons.receipt_long_rounded,
                      label: 'Hóa đơn mở',
                      value: '${dashboard.openInvoiceCount}',
                    ),
                    _HeroStatChip(
                      icon: Icons.warning_amber_rounded,
                      label: 'Quá hạn',
                      value: '${dashboard.overdueInvoiceCount}',
                    ),
                    _HeroStatChip(
                      icon: Icons.construction_rounded,
                      label: 'Sửa chữa',
                      value: '${dashboard.openMaintenanceCount}',
                    ),
                    _HeroStatChip(
                      icon: Icons.notifications_rounded,
                      label: 'Chưa đọc',
                      value: '${dashboard.unreadNotificationCount}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroLoadingBand extends StatelessWidget {
  const _HeroLoadingBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 36),
            child: _SectionLoading(
              tint: Colors.white,
              message: 'Đang tải tổng quan...',
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroErrorBand extends StatelessWidget {
  const _HeroErrorBand({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Không tải được tổng quan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantSection extends StatelessWidget {
  const _TenantSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: title,
                  icon: icon,
                  trailing: trailing,
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onInvoices,
    required this.onMaintenance,
    required this.onZalo,
    required this.onNotifications,
  });

  final VoidCallback onInvoices;
  final VoidCallback onMaintenance;
  final VoidCallback onZalo;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 4 ? 3.4 : 2.7,
          children: [
            _ActionButton(
              icon: Icons.receipt_long_rounded,
              label: 'Hóa đơn',
              onPressed: onInvoices,
            ),
            _ActionButton(
              icon: Icons.construction_rounded,
              label: 'Sửa chữa',
              onPressed: onMaintenance,
            ),
            _ActionButton(
              icon: Icons.chat_bubble_rounded,
              label: 'Zalo',
              onPressed: onZalo,
            ),
            _ActionButton(
              icon: Icons.notifications_rounded,
              label: 'Thông báo',
              onPressed: onNotifications,
            ),
          ],
        );
      },
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
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFF2F6F3),
        foregroundColor: AppTheme.ink,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8E4)),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({
    this.tint = AppTheme.primary,
    this.message = 'Đang tải...',
  });

  final Color tint;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: tint,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              color: tint == Colors.white ? Colors.white : const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceLead extends StatelessWidget {
  const _InvoiceLead({
    required this.invoice,
    required this.onOpen,
  });

  final Invoice invoice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = invoice.isOverdue
        ? 'Đã quá hạn ${invoice.daysOverdue} ngày'
        : invoice.isDueSoon
            ? 'Sắp đến hạn'
            : 'Đang chờ thanh toán';
    final color = invoice.isOverdue
        ? const Color(0xFFDC2626)
        : invoice.isDueSoon
            ? const Color(0xFFD97706)
            : const Color(0xFF0F766E);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E8E5)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.payments_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hóa đơn ${formatMonth(invoice.billingMonth)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$label · Hạn ${formatDate(invoice.dueDate)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatCurrencyVnd(invoice.remainingAmount),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.onTap,
  });

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusText = invoice.isOverdue
        ? 'Quá hạn ${invoice.daysOverdue} ngày'
        : invoice.isDueSoon
            ? 'Sắp đến hạn'
            : invoice.status.label;
    final color = invoice.isOverdue
        ? const Color(0xFFDC2626)
        : invoice.isDueSoon
            ? const Color(0xFFD97706)
            : invoice.status.color;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tháng ${formatMonth(invoice.billingMonth)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$statusText · Hạn ${formatDate(invoice.dueDate)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatCurrencyVnd(invoice.remainingAmount),
              style: TextStyle(
                color: invoice.remainingAmount > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  const _MaintenanceRow({
    required this.ticket,
    required this.onTap,
  });

  final MaintenanceTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ticket.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                ticket.status.icon,
                size: 18,
                color: ticket.status.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ticket.status.label} · ${ticket.priority.label}'
                    '${ticket.reportedAt != null ? ' · ${formatDate(ticket.reportedAt)}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (ticket.comments.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${ticket.comments.length}',
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaseHighlight extends StatelessWidget {
  const _LeaseHighlight({required this.lease});

  final TenantPortalLease lease;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phòng ${lease.roomName} · ${lease.propertyName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lease.isActive ? 'Đang thuê' : 'Đã kết thúc',
                  style: TextStyle(
                    color: lease.isActive
                        ? AppTheme.primaryDark
                        : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (lease.propertyAddress?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              lease.propertyAddress!,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _TinyInfo(
                label: 'Tiền thuê',
                value: formatCurrencyVnd(lease.monthlyRent),
              ),
              _TinyInfo(
                label: 'Cọc',
                value: formatCurrencyVnd(lease.deposit),
              ),
              _TinyInfo(
                label: 'Bắt đầu',
                value: formatDate(lease.startDate),
              ),
              _TinyInfo(
                label: 'Kết thúc',
                value: lease.endDate == null ? 'Chưa kết thúc' : formatDate(lease.endDate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaseRow extends StatelessWidget {
  const _LeaseRow({required this.lease});

  final TenantPortalLease lease;

  @override
  Widget build(BuildContext context) {
    final active = lease.isActive;
    final color = active ? const Color(0xFF10B981) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              active ? Icons.home_rounded : Icons.history_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng ${lease.roomName} · ${lease.propertyName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tiền thuê ${formatCurrencyVnd(lease.monthlyRent)} · Cọc ${formatCurrencyVnd(lease.deposit)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            active ? 'Đang thuê' : 'Đã kết thúc',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.onTap,
  });

  final TenantNotification item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = item.kind.startsWith('invoice')
        ? Icons.receipt_long_rounded
        : item.kind.startsWith('maintenance')
            ? Icons.construction_rounded
            : Icons.notifications_rounded;
    final color = item.read ? const Color(0xFF9CA3AF) : AppTheme.primaryDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: item.read ? FontWeight.w700 : FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!item.read)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(
                Icons.done_rounded,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZaloPreview extends StatelessWidget {
  const _ZaloPreview({
    required this.messages,
    required this.onOpen,
    required this.onMarkRead,
  });

  final List<NotificationDeliveryLog> messages;
  final VoidCallback onOpen;
  final ValueChanged<NotificationDeliveryLog> onMarkRead;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState(
        title: 'Chưa có tin Zalo.',
        subtitle: 'Khi chủ trọ gửi tin nhắn, nội dung sẽ hiện ở đây.',
      );
    }

    final latest = messages.first;
    final unread = messages.where((message) => !message.read).length;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E8E5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0068FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tin nhắn gần nhất',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        unread > 0 ? '$unread chưa đọc' : '${messages.length} tin',
                        style: TextStyle(
                          color: unread > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    latest.messageText(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: latest.read
                          ? const Color(0xFF4B5563)
                          : const Color(0xFF111827),
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: latest.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (!latest.read) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => onMarkRead(latest),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryDark,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Đánh dấu đã đọc'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  const _TinyInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return _firstLetter(parts.first);
  }
  final first = _firstLetter(parts.first);
  final last = _firstLetter(parts.last);
  return '$first$last';
}

String _firstLetter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

Future<void> _showMaintenanceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final imageUrl = TextEditingController();
  final imageUrls = <String>[];
  var priority = MaintenancePriority.medium;
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Báo sửa chữa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<MaintenancePriority>(
                value: priority,
                items: MaintenancePriority.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) => setState(() => priority = value ?? priority),
                decoration: const InputDecoration(labelText: 'Mức độ'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imageUrl,
                decoration: const InputDecoration(
                  labelText: 'Link ảnh sự cố hoặc ảnh đã upload',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        try {
                          final uploaded = await _pickAndUploadFile(ref);
                          if (uploaded != null) {
                            setState(() {
                              imageUrls.add(uploaded);
                              imageUrl.text = uploaded;
                            });
                          }
                        } catch (err) {
                          setState(() => error = '$err');
                        }
                      },
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  imageUrls.isEmpty
                      ? 'Upload ảnh'
                      : 'Đã upload ${imageUrls.length} ảnh',
                ),
              ),
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
                    if (title.text.trim().isEmpty) {
                      setState(() => error = 'Nhập tiêu đề sự cố.');
                      return;
                    }
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(tenantMaintenanceControllerProvider.notifier)
                          .submit(
                            title: title.text,
                            description: description.text,
                            priority: priority,
                            imageUrls: [
                              ...imageUrls,
                              if (imageUrl.text.trim().isNotEmpty &&
                                  !imageUrls.contains(imageUrl.text.trim()))
                                imageUrl.text.trim(),
                            ],
                          );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
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

  title.dispose();
  description.dispose();
  imageUrl.dispose();
}

Future<void> _showMaintenanceCommentDialog(
  BuildContext context,
  WidgetRef ref,
  MaintenanceTicket ticket,
) async {
  final body = TextEditingController();
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(ticket.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final comment in ticket.comments) ...[
                Text(
                  '${comment.authorName ?? comment.authorRole} · ${formatDate(comment.createdAt)}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                Text(comment.body),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: body,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Phản hồi'),
              ),
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
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: loading
                ? null
                : () async {
                    if (body.text.trim().isEmpty) {
                      setState(() => error = 'Nhập nội dung phản hồi.');
                      return;
                    }
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(tenantMaintenanceControllerProvider.notifier)
                          .comment(ticketId: ticket.id, body: body.text);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
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

  body.dispose();
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
      'pdf',
    ],
  );
  final path = result?.files.single.path;
  if (path == null) return null;
  final url = await ref.read(uploadApiProvider).uploadFile(path);
  return url.isEmpty ? null : ApiConfig.resolveUrl(url);
}
