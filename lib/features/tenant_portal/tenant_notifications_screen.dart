import 'package:flutter/material.dart';
import 'tenant_announcements_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_navigation.dart';
import '../listings/listing_widgets.dart';
import 'tenant_portal_providers.dart';

const _background = Color(0xFFF7F7F7);
const _panel = Color(0xFFFFFFFF);
const _line = Color(0xFFEBEBEB);
const _muted = Color(0xFF717171);
const _ink = Color(0xFF222222);
const _success = Color(0xFF0F8A6A);
const _warning = Color(0xFFD97706);

enum _TenantNotificationFilter {
  all,
  unread,
  invoice,
  maintenance,
  other;

  String get label => switch (this) {
        _TenantNotificationFilter.all => 'Tất cả',
        _TenantNotificationFilter.unread => 'Chưa đọc',
        _TenantNotificationFilter.invoice => 'Hóa đơn',
        _TenantNotificationFilter.maintenance => 'Bảo trì',
        _TenantNotificationFilter.other => 'Khác',
      };
}

class TenantNotificationsScreen extends ConsumerStatefulWidget {
  const TenantNotificationsScreen({super.key});

  @override
  ConsumerState<TenantNotificationsScreen> createState() =>
      _TenantNotificationsScreenState();
}

class _TenantNotificationsScreenState
    extends ConsumerState<TenantNotificationsScreen> {
  var _filter = _TenantNotificationFilter.all;
  var _markingAll = false;

  Future<void> _refresh() async {
    await Future.wait([
      ref.refresh(tenantPortalNotificationsProvider.future),
      ref.refresh(tenantPortalDashboardProvider.future),
    ]);
  }

  Future<void> _markAllRead(List<TenantNotification> items) async {
    final unread = items.where((item) => !item.read).toList(growable: false);
    if (unread.isEmpty || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      for (final item in unread) {
        await ref
            .read(tenantNotificationControllerProvider.notifier)
            .markRead(item.id);
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(TenantNotification item) async {
    if (!item.read) {
      await ref
          .read(tenantNotificationControllerProvider.notifier)
          .markRead(item.id);
    }
    if (!mounted) return;

    if (item.invoiceId != null && item.invoiceId!.isNotEmpty) {
      context.push(tenantInvoiceDetailPath(item.invoiceId!));
      return;
    }
    if (item.maintenanceId != null && item.maintenanceId!.isNotEmpty) {
      context.push(tenantMaintenanceRoute);
      return;
    }
    await _showNotificationSheet(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(tenantPortalNotificationsProvider);

    return ListingTheme(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          actions: [TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TenantAnnouncementsScreen())), icon: const Icon(Icons.campaign_outlined), label: const Text('Chủ trọ'))],
          title: const Text(
            'Thông báo',
            style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          color: kAirbnbRose,
          onRefresh: _refresh,
        child: notificationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              _EmptyPanel(
                icon: Icons.cloud_off_rounded,
                title: 'Không tải được thông báo',
                subtitle: '$error',
                action: TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(tenantPortalNotificationsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ),
            ],
          ),
          data: (items) {
            final visible = items
                .where((item) => _matchesFilter(item, _filter))
                .toList(growable: false);
            final unread = items.where((item) => !item.read).length;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SummaryPanel(
                  total: items.length,
                  unread: unread,
                  onMarkAllRead: unread == 0 ? null : () => _markAllRead(items),
                  loading: _markingAll,
                ),
                const SizedBox(height: 14),
                _FilterBar(
                  value: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const _EmptyPanel(
                    icon: Icons.notifications_none_rounded,
                    title: 'Chưa có thông báo',
                    subtitle:
                        'Nhắc tiền, cập nhật bảo trì và tin vận hành sẽ xuất hiện ở đây.',
                  )
                else if (visible.isEmpty)
                  _EmptyPanel(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Không có thông báo phù hợp',
                    subtitle: 'Đổi bộ lọc để xem các thông báo khác.',
                    action: TextButton(
                      onPressed: () => setState(
                        () => _filter = _TenantNotificationFilter.all,
                      ),
                      child: const Text('Xem tất cả'),
                    ),
                  )
                else
                  for (final item in visible) ...[
                    _NotificationTile(
                      item: item,
                      onTap: () => _openNotification(item),
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

bool _matchesFilter(
  TenantNotification item,
  _TenantNotificationFilter filter,
) {
  final type = _notificationType(item);
  return switch (filter) {
    _TenantNotificationFilter.all => true,
    _TenantNotificationFilter.unread => !item.read,
    _TenantNotificationFilter.invoice => type == _NotificationType.invoice,
    _TenantNotificationFilter.maintenance =>
      type == _NotificationType.maintenance,
    _TenantNotificationFilter.other => type == _NotificationType.other,
  };
}

enum _NotificationType { invoice, maintenance, other }

_NotificationType _notificationType(TenantNotification item) {
  if (item.kind.startsWith('invoice') || item.invoiceId != null) {
    return _NotificationType.invoice;
  }
  if (item.kind.startsWith('maintenance') || item.maintenanceId != null) {
    return _NotificationType.maintenance;
  }
  return _NotificationType.other;
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.total,
    required this.unread,
    required this.onMarkAllRead,
    required this.loading,
  });

  final int total;
  final int unread;
  final VoidCallback? onMarkAllRead;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final clear = unread == 0;
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
            icon: clear
                ? Icons.mark_email_read_rounded
                : Icons.notifications_active_rounded,
            color: clear ? _success : _warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear ? 'Đã đọc hết thông báo' : 'Cần xem lại',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unread chưa đọc',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clear ? _success : _warning,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$total thông báo trong hộp tin của bạn',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: loading ? null : onMarkAllRead,
            icon: loading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            label: const Text('Đọc hết'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _TenantNotificationFilter value;
  final ValueChanged<_TenantNotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _TenantNotificationFilter.values) ...[
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final TenantNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = _notificationMeta(item);
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
            border: Border.all(color: item.read ? _line : AppTheme.primary),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBubble(
                icon: meta.icon,
                color: item.read ? _muted : meta.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight:
                                  item.read ? FontWeight.w700 : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!item.read) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.body,
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
                        _StatusPill(label: meta.label, color: meta.color),
                        if (item.createdAt != null)
                          _StatusPill(
                            label: formatDate(item.createdAt),
                            color: _muted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                item.invoiceId != null || item.maintenanceId != null
                    ? Icons.chevron_right_rounded
                    : Icons.open_in_full_rounded,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_NotificationMeta _notificationMeta(TenantNotification item) {
  return switch (_notificationType(item)) {
    _NotificationType.invoice => const _NotificationMeta(
        label: 'Hóa đơn',
        icon: Icons.receipt_long_rounded,
        color: _warning,
      ),
    _NotificationType.maintenance => const _NotificationMeta(
        label: 'Bảo trì',
        icon: Icons.construction_rounded,
        color: AppTheme.primary,
      ),
    _NotificationType.other => const _NotificationMeta(
        label: 'Thông báo',
        icon: Icons.notifications_rounded,
        color: _muted,
      ),
  };
}

class _NotificationMeta {
  const _NotificationMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

Future<void> _showNotificationSheet(
  BuildContext context,
  TenantNotification item,
) {
  final meta = _notificationMeta(item);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: _panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 14),
          _IconBubble(icon: meta.icon, color: meta.color),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ),
        ],
      ),
    ),
  );
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
