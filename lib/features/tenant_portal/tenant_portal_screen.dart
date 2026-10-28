import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/messaging/messaging_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import '../../core/utils/format.dart';
import '../../models/billing.dart';
import '../billing/widgets/invoice_line_items.dart';
import '../../models/maintenance.dart';
import '../../models/notification_delivery.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../listings/listing_widgets.dart';
import '../listings/handover_screen.dart';
import 'tenant_portal_providers.dart';

const _tenantBackground = Color(0xFFF7F7F7);
const _tenantPanel = Color(0xFFFFFFFF);
const _tenantPanelAlt = Color(0xFFF7F7F7);
const _tenantLine = Color(0xFFEBEBEB);
const _tenantMuted = Color(0xFF717171);
const _tenantInk = Color(0xFF222222);
const _tenantRose = Color(0xFFFF385C);
const _tenantSuccess = Color(0xFF0F8A6A);
const _tenantWarning = Color(0xFFD97706);
const _tenantDanger = Color(0xFFDC2626);

class TenantPortalScreen extends ConsumerStatefulWidget {
  const TenantPortalScreen({super.key});

  @override
  ConsumerState<TenantPortalScreen> createState() => _TenantPortalScreenState();
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

    return ListingTheme(
      child: Scaffold(
        backgroundColor: _tenantBackground,
        bottomNavigationBar: const ListingNavigation(selectedIndex: 1),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _tenantInk,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Phòng đang thuê của tôi',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _tenantInk,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
                tooltip: 'Trung tâm hỗ trợ',
                onPressed: () => context.push(supportCenterRoute),
                icon: const Icon(Icons.support_agent_outlined,
                    color: _tenantInk)),
            IconButton(
              tooltip: 'Đổi mật khẩu',
              onPressed: () => context.push(tenantPasswordRoute),
              icon: const Icon(Icons.lock_reset_rounded, color: _tenantInk),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded, color: _tenantInk),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _tenantRose,
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: liquidTaskbarBottomPadding(context),
            ),
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
              invoicesAsync.maybeWhen(
                data: (invoices) {
                  if (invoices.isEmpty) return const SizedBox.shrink();
                  final latest = invoices.first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _TenantSection(
                      title:
                          'Chỉ số Điện · Nước tháng ${formatMonth(latest.billingMonth)}',
                      trailing: TextButton(
                        onPressed: () =>
                            context.push(tenantInvoiceDetailPath(latest.id)),
                        child: const Text(
                          'Chi tiết →',
                          style: TextStyle(
                            color: _tenantRose,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      child: _UtilityBreakdownGrid(invoice: latest),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              _TenantSection(
                title: 'Lối tắt',
                child: _ActionGrid(
                  onInvoices: () => context.push(tenantInvoicesRoute),
                  onMaintenance: () => context.push(tenantMaintenanceRoute),
                  onZalo: () => _openTenantMessenger(context, dashboardAsync),
                  onNotifications: () => context.push(tenantNotificationsRoute),
                ),
              ),
              const SizedBox(height: 12),
              _TenantSection(
                key: _zaloKey,
                title: 'Zalo từ chủ trọ',
                trailing: zaloMessagesAsync.maybeWhen(
                  data: (messages) {
                    final unread =
                        messages.where((message) => !message.read).length;
                    return Text(
                      unread > 0
                          ? '$unread chưa đọc'
                          : '${messages.length} tin',
                      style: TextStyle(
                        color: unread > 0 ? _tenantDanger : _tenantMuted,
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
                    onRetry: () =>
                        ref.invalidate(tenantPortalZaloMessagesProvider),
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
              const SizedBox(height: 12),
              _TenantSection(
                key: _invoicesKey,
                title: 'Hóa đơn',
                trailing: dashboardAsync.maybeWhen(
                  data: (dashboard) => Text(
                    formatCurrencyVnd(
                      dashboard.outstandingAmount > 0
                          ? dashboard.outstandingAmount
                          : 0,
                    ),
                    style: TextStyle(
                      color: dashboard.outstandingAmount > 0
                          ? _tenantDanger
                          : _tenantSuccess,
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
                    final openInvoices = invoices
                        .where((invoice) => invoice.remainingAmount > 0)
                        .toList();
                    final totalDebt = openInvoices.fold<int>(
                      0,
                      (sum, invoice) => sum + invoice.remainingAmount,
                    );
                    final nextInvoice =
                        openInvoices.isEmpty ? null : openInvoices.first;
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
                              for (var i = 0;
                                  i < invoices.take(4).length;
                                  i++) ...[
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
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
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.push(tenantInvoicesRoute),
                                child: const Text('Xem tất cả'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _TenantSection(
                key: _maintenanceKey,
                title: 'Sửa chữa',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => context.push(tenantMaintenanceRoute),
                      child: const Text('Xem tất cả'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Báo sửa chữa',
                      onPressed: () => _showMaintenanceDialog(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: _tenantRose.withValues(alpha: 0.12),
                        foregroundColor: _tenantRose,
                      ),
                    ),
                  ],
                ),
                child: maintenanceAsync.when(
                  loading: () => const _SectionLoading(),
                  error: (error, _) => _SectionError(
                    message: 'Không tải được sửa chữa: $error',
                    onRetry: () =>
                        ref.invalidate(tenantPortalMaintenanceProvider),
                  ),
                  data: (tickets) {
                    if (tickets.isEmpty) {
                      return const _EmptyState(
                        title: 'Chưa có yêu cầu sửa chữa.',
                        subtitle:
                            'Bạn có thể gửi báo hỏng ngay từ nút + ở góc phải.',
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
              const SizedBox(height: 12),
              _TenantSection(
                key: _leasesKey,
                title: 'Hợp đồng',
                trailing: leasesAsync.maybeWhen(
                  data: (leases) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${leases.length} mục',
                        style: const TextStyle(
                          color: _tenantMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => context.push(tenantLeasesRoute),
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  orElse: () => TextButton(
                    onPressed: () => context.push(tenantLeasesRoute),
                    child: const Text('Xem tất cả'),
                  ),
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
                        subtitle:
                            'Thông tin hợp đồng sẽ xuất hiện ở đây khi có dữ liệu.',
                      );
                    }
                    final activeLease = leases.firstWhere(
                      (lease) => lease.isActive,
                      orElse: () => leases.first,
                    );
                    final history = leases
                        .where((lease) => lease.id != activeLease.id)
                        .toList();
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
              const SizedBox(height: 12),
              _TenantSection(
                key: _notificationsKey,
                title: 'Thông báo',
                trailing: notificationsAsync.maybeWhen(
                  data: (items) {
                    final unread = items.where((item) => !item.read).length;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          unread > 0
                              ? '$unread chưa đọc'
                              : '${items.length} tin',
                          style: TextStyle(
                            color: unread > 0 ? _tenantDanger : _tenantMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () =>
                              context.push(tenantNotificationsRoute),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    );
                  },
                  orElse: () => TextButton(
                    onPressed: () => context.push(tenantNotificationsRoute),
                    child: const Text('Xem tất cả'),
                  ),
                ),
                child: notificationsAsync.when(
                  loading: () => const _SectionLoading(),
                  error: (error, _) => _SectionError(
                    message: 'Không tải được thông báo: $error',
                    onRetry: () =>
                        ref.invalidate(tenantPortalNotificationsProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptyState(
                        title: 'Chưa có thông báo.',
                        subtitle:
                            'Các nhắc nhở và cập nhật mới sẽ xuất hiện tại đây.',
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
                                    .read(tenantNotificationControllerProvider
                                        .notifier)
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
    final statusColor = hasDebt ? _tenantDanger : _tenantSuccess;
    final dueText = nextInvoice == null
        ? 'Chưa có hóa đơn cần xử lý.'
        : nextInvoice.isOverdue
            ? 'Quá hạn ${nextInvoice.daysOverdue} ngày'
            : 'Hạn ${formatDate(nextInvoice.dueDate)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            decoration: BoxDecoration(
              color: _tenantInk,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF222222),
                          Color(0xFF2D1F2D),
                          Color(0xFF3E1E29),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.16),
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
                                const SizedBox(height: 5),
                                Text(
                                  lease == null
                                      ? 'Chủ trọ: ${profile.landlordName}'
                                      : 'Phòng ${lease.roomName} · ${lease.propertyName}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StatusPill(
                            icon: lease == null
                                ? Icons.hourglass_empty_rounded
                                : Icons.verified_rounded,
                            label: lease == null
                                ? 'Chưa có hợp đồng'
                                : 'Đang thuê',
                          ),
                        ],
                      ),
                      if (lease?.propertyAddress?.trim().isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 12),
                        _HeroAddress(address: lease!.propertyAddress!),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _InvoiceStatusBadge(
                                  icon: hasDebt
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_rounded,
                                  label: hasDebt ? 'Cần thanh toán' : 'Ổn định',
                                  color: statusColor,
                                ),
                                const Spacer(),
                                Text(
                                  dueText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              hasDebt
                                  ? 'Còn phải thanh toán'
                                  : 'Số dư hiện tại',
                              style: const TextStyle(
                                color: _tenantMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatCurrencyVnd(dashboard.outstandingAmount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _tenantInk,
                                fontSize: 31,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextInvoice == null
                                  ? 'Chưa có hóa đơn mới. Bạn có thể gửi yêu cầu sửa chữa khi cần.'
                                  : nextInvoice.isOverdue
                                      ? 'Hóa đơn ${formatMonth(nextInvoice.billingMonth)} đã quá hạn, mở chi tiết để gửi minh chứng thanh toán.'
                                      : 'Hóa đơn ${formatMonth(nextInvoice.billingMonth)} đang chờ đến hạn ${formatDate(nextInvoice.dueDate)}.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _tenantMuted,
                                fontSize: 12,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onPrimaryAction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _tenantRose,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: Icon(
                                  nextInvoice == null
                                      ? Icons.construction_rounded
                                      : Icons.receipt_long_rounded,
                                  size: 19,
                                ),
                                label: Text(
                                  nextInvoice == null
                                      ? 'Báo sửa chữa'
                                      : 'Mở hóa đơn cần trả',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;
                          final statWidth = compact
                              ? (constraints.maxWidth - 8) / 2
                              : (constraints.maxWidth - 24) / 4;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroStatChip(
                                width: statWidth,
                                icon: Icons.receipt_long_rounded,
                                label: 'Hóa đơn mở',
                                value: '${dashboard.openInvoiceCount}',
                              ),
                              _HeroStatChip(
                                width: statWidth,
                                icon: Icons.warning_amber_rounded,
                                label: 'Quá hạn',
                                value: '${dashboard.overdueInvoiceCount}',
                              ),
                              _HeroStatChip(
                                width: statWidth,
                                icon: Icons.construction_rounded,
                                label: 'Sửa chữa',
                                value: '${dashboard.openMaintenanceCount}',
                              ),
                              _HeroStatChip(
                                width: statWidth,
                                icon: Icons.notifications_rounded,
                                label: 'Chưa đọc',
                                value: '${dashboard.unreadNotificationCount}',
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroAddress extends StatelessWidget {
  const _HeroAddress({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  const _InvoiceStatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLoadingBand extends StatelessWidget {
  const _HeroLoadingBand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 170, height: 22, tint: Colors.white),
                SizedBox(height: 12),
                _SkeletonLine(
                    width: double.infinity, height: 170, tint: Colors.white),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SkeletonLine(height: 64, tint: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _SkeletonLine(height: 64, tint: Colors.white),
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

class _HeroErrorBand extends StatelessWidget {
  const _HeroErrorBand({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(28),
            ),
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
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tenantPanel,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _tenantLine),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B302A).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: title,
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
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: _tenantInk,
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
    return Material(
      color: _tenantPanelAlt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _tenantLine),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _tenantRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: _tenantRose),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _tenantInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A39B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    this.width,
    required this.height,
    this.tint = AppTheme.primary,
  });

  final double? width;
  final double height;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final base = tint == Colors.white
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFEAECEF);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(14),
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
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải...',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 170, height: 16, tint: AppTheme.primary),
          SizedBox(height: 12),
          _SkeletonLine(height: 48, tint: AppTheme.primary),
          SizedBox(height: 8),
          _SkeletonLine(height: 48, tint: AppTheme.primary),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 19,
        color: color,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tenantDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tenantDanger.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _tenantDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _tenantDanger,
                height: 1.4,
                fontWeight: FontWeight.w700,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tenantPanelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tenantLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconBubble(
            icon: Icons.inbox_rounded,
            color: AppTheme.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _tenantInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _tenantMuted,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
        ? _tenantDanger
        : invoice.isDueSoon
            ? _tenantWarning
            : const Color(0xFF0F766E);

    return Material(
      color: _tenantPanelAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _tenantLine),
          ),
          child: Row(
            children: [
              _IconBubble(
                icon: Icons.payments_rounded,
                color: color,
              ),
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
                        color: _tenantInk,
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
              Flexible(
                child: Text(
                  formatCurrencyVnd(invoice.remainingAmount),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
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
        ? _tenantDanger
        : invoice.isDueSoon
            ? _tenantWarning
            : invoice.status.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            _IconBubble(
              icon: Icons.receipt_long_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tháng ${formatMonth(invoice.billingMonth)}${invoice.isDemo ? ' · Kiểm thử' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _tenantInk,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: invoice.remainingAmount > 0
                    ? _tenantDanger
                    : _tenantSuccess,
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBubble(
              icon: ticket.status.icon,
              color: ticket.status.color,
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
                      color: _tenantInk,
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
                      color: _tenantMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (ticket.comments.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${ticket.comments.length}',
                  style: const TextStyle(
                    color: _tenantInk,
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

class _UtilityBreakdownGrid extends StatelessWidget {
  const _UtilityBreakdownGrid({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    if (invoice.lineItems.isNotEmpty) {
      return InvoiceLineItems(items: invoice.lineItems);
    }
    final serviceAndOther = invoice.waterAmount + invoice.otherAmount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = constraints.maxWidth >= 340
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: colWidth,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _tenantPanelAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _tenantLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⚡ Điện sinh hoạt',
                          style: TextStyle(
                            color: _tenantMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.bolt_rounded,
                            size: 16, color: _tenantWarning),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrencyVnd(invoice.electricityAmount),
                      style: const TextStyle(
                        color: _tenantInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tiền phòng: ${formatCurrencyVnd(invoice.rentAmount)}',
                      style: const TextStyle(
                        color: _tenantMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: colWidth,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _tenantPanelAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _tenantLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '💧 Nước & Dịch vụ',
                          style: TextStyle(
                            color: _tenantMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(Icons.water_drop_rounded,
                            size: 15, color: _tenantSuccess),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrencyVnd(serviceAndOther),
                      style: const TextStyle(
                        color: _tenantInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Nước ${formatCurrencyVnd(invoice.waterAmount)} · Khác ${formatCurrencyVnd(invoice.otherAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _tenantMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LeaseHighlight extends StatelessWidget {
  const _LeaseHighlight({required this.lease});

  final TenantPortalLease lease;

  double get _progress {
    final start = lease.startDate;
    final end = lease.endDate;
    if (start == null || end == null || !end.isAfter(start)) return 0.45;
    final total = end.difference(start).inDays;
    if (total <= 0) return 0.45;
    final elapsed = DateTime.now().difference(start).inDays;
    return (elapsed / total).clamp(0.08, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tenantPanelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tenantLine),
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
                    color: _tenantInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _tenantSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  lease.occupancyLabel,
                  style: TextStyle(
                    color: lease.isActive ? _tenantSuccess : _tenantMuted,
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
                color: _tenantMuted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bắt đầu: ${formatDate(lease.startDate)}',
                style: const TextStyle(
                  color: _tenantMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Kết thúc: ${lease.endDate == null ? 'Chưa kết thúc' : formatDate(lease.endDate)}',
                style: const TextStyle(
                  color: _tenantMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(_tenantRose),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _TinyInfo(
                label: 'Tiền thuê cố định',
                value: '${formatCurrencyVnd(lease.monthlyRent)}/tháng',
              ),
              _TinyInfo(
                label: 'Tiền cọc đang giữ',
                value: formatCurrencyVnd(lease.depositBalance),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => HandoverScreen(leaseId: lease.id))),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Bàn giao & tiền cọc')),
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
    final color = active ? _tenantSuccess : _tenantMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _IconBubble(
            icon: active ? Icons.home_rounded : Icons.history_rounded,
            color: color,
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
                    color: _tenantInk,
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
                    color: _tenantMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            lease.occupancyLabel,
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
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBubble(
              icon: icon,
              color: color,
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
                      color: _tenantInk,
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
                      color: _tenantMuted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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

    return Material(
      color: _tenantPanelAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _tenantLine),
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
                          color: _tenantDanger,
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
                              color: _tenantInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          unread > 0
                              ? '$unread chưa đọc'
                              : '${messages.length} tin',
                          style: TextStyle(
                            color: unread > 0 ? _tenantDanger : _tenantMuted,
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
                        color:
                            latest.read ? const Color(0xFF4B5563) : _tenantInk,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight:
                            latest.read ? FontWeight.w500 : FontWeight.w700,
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
        color: _tenantPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tenantLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _tenantMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: _tenantInk,
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
  final imageUrls = <String>[];
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
                      const TextStyle(fontSize: 12, color: Color(0xFF8891A8)),
                ),
                Text(comment.body),
                if (comment.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < comment.imageUrls.length; i += 1)
                        Chip(label: Text('File ${i + 1}')),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
              ],
              TextField(
                controller: body,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Phản hồi'),
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
                          .comment(
                            ticketId: ticket.id,
                            body: body.text,
                            imageUrls: imageUrls,
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
