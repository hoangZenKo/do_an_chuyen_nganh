import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/messaging/messaging_launcher.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/lease.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../tenants/tenant_providers.dart';
import 'room_providers.dart';
import 'service_tariff_dialog.dart';
import 'widgets/room_image.dart';

/// Read-only detail for a single room, redesigned with property-listing
/// style: hero image, floating nav, tab bar, sticky bottom CTA.
class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen(
      {super.key, required this.roomId, this.initialTab = 0});

  final String roomId;
  final int initialTab;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: widget.initialTab.clamp(0, 3),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomDetailProvider(widget.roomId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: roomAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (error, _) => _ErrorBody(
          message: '$error',
          onRetry: () => ref.invalidate(roomDetailProvider(widget.roomId)),
        ),
        data: (room) => _RoomDetailBody(
          room: room,
          tabController: _tabController,
          onDeactivate: () => _setActive(room, false),
          onReactivate: () => _setActive(room, true),
          onDelete: () => _delete(room),
        ),
      ),
    );
  }

  Future<void> _setActive(Room room, bool isActive) async {
    final confirmed = await _confirm(
      title: isActive ? 'Kích hoạt lại phòng?' : 'Ngưng sử dụng phòng?',
      message: isActive
          ? 'Phòng sẽ quay lại danh sách đang sử dụng và có thể tạo hợp đồng mới.'
          : 'Phòng sẽ bị ẩn khỏi danh sách vận hành. Nếu đang có hợp đồng active, backend sẽ chặn thao tác này.',
      confirmLabel: isActive ? 'Kích hoạt' : 'Ngưng sử dụng',
      destructive: !isActive,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(roomFormControllerProvider.notifier).setActive(
            propertyId: room.propertyId,
            roomId: room.id,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(isActive ? 'Đã kích hoạt phòng' : 'Đã ngưng sử dụng phòng'),
        ),
      );
    } catch (error) {
      _showError(error, 'Không thể cập nhật phòng.');
    }
  }

  Future<void> _delete(Room room) async {
    final confirmed = await _confirm(
      title: 'Xóa vĩnh viễn phòng?',
      message:
          'Chỉ xóa được phòng chưa có hợp đồng, chỉ số điện nước hoặc hóa đơn. Phòng đã có lịch sử nên dùng Ngưng sử dụng.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(roomFormControllerProvider.notifier).delete(
            propertyId: room.propertyId,
            roomId: room.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${room.name}')),
      );
      context.pop();
    } catch (error) {
      _showError(error, 'Không thể xóa phòng.');
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

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: Color(0xFF2E3348)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8891A8))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Thử lại',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

// Color tokens
const _kDarkNavy = Color(0xFF141C2E);
const _kOrangeAccent = Color(0xFFFF6600);
const _kTextPrimary = Color(0xFF0F1117);
const _kTextMuted = Color(0xFF8891A8);
const _kDivider = Color(0xFFF0F2F8);

class _RoomDetailBody extends ConsumerWidget {
  const _RoomDetailBody({
    required this.room,
    required this.tabController,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onDelete,
  });

  final Room room;
  final TabController tabController;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        // ── Background: dark navy behind the white card ─────────────────
        Container(color: _kDarkNavy),

        // ── Scrollable content ──────────────────────────────────────────
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image (full width, tall)
              _HeroSection(room: room),

              // Dark navy info band
              _RoomInfoHeader(
                room: room,
                onDeactivate: onDeactivate,
                onReactivate: onReactivate,
                onDelete: onDelete,
              ),

              // White card body — rounded top corners
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Overview section
                    _OverviewSection(room: room),
                    // About section
                    _AboutSection(room: room),
                    // Details tab content (fees, assets, inspections, leases)
                    _ExpandedTabContent(
                      room: room,
                      tabController: tabController,
                    ),
                    // Bottom padding for CTA
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Floating back + more buttons ────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: _FloatingNavBar(
            room: room,
            onDeactivate: onDeactivate,
            onReactivate: onReactivate,
            onDelete: onDelete,
          ),
        ),

        // ── Sticky bottom CTA ───────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _StickyBottomBar(room: room),
        ),
      ],
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final imageSource = RoomImageCatalog.imageFor(room);

    return SizedBox(
      height: 290,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Room photo
          RoomImageView(
            source: imageSource,
            fit: BoxFit.cover,
            placeholder: _HeroPlaceholder(room: room),
          ),
          // Subtle bottom gradient bleeding into dark navy band
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    _kDarkNavy.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final statusColor = room.status.color;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.30),
            const Color(0xFF141C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.meeting_room_rounded,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            room.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating nav bar (back, share, menu) ──────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.room,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onDelete,
  });

  final Room room;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FloatingButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.pop(),
        ),
        const Spacer(),
        if (room.isActive) ...[
          _FloatingButton(
            icon: Icons.edit_outlined,
            onTap: () => context.push(roomFormPath(roomId: room.id)),
          ),
          const SizedBox(width: 8),
        ],
        _FloatingButton(
          icon: Icons.share_outlined,
          onTap: () {},
        ),
        const SizedBox(width: 8),
        _ActionsMenuButton(
          room: room,
          onDeactivate: onDeactivate,
          onReactivate: onReactivate,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF374151)),
      ),
    );
  }
}

class _ActionsMenuButton extends StatelessWidget {
  const _ActionsMenuButton({
    required this.room,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onDelete,
  });

  final Room room;
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
        if (room.isActive)
          const PopupMenuItem(
            value: 'deactivate',
            child: Text('Ngưng sử dụng'),
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
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_vert_rounded,
            size: 20, color: Color(0xFF374151)),
      ),
    );
  }
}

// ── Room info header (dark navy band) ─────────────────────────────────────────

class _RoomInfoHeader extends StatelessWidget {
  const _RoomInfoHeader({
    required this.room,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onDelete,
  });

  final Room room;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkNavy,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(room: room),
            ],
          ),
          const SizedBox(height: 6),
          // Property hint subtitle
          const Text(
            'Nhà trọ của bạn',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8891A8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!room.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22263A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      size: 15, color: Color(0xFF8891A8)),
                  SizedBox(width: 6),
                  Text(
                    'Phòng đang ngưng sử dụng',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8891A8)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCurrencyVnd(room.basePrice),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _kOrangeAccent,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '/ tháng',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8891A8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    // Color matched to mockup: green for occupied, amber for vacant, indigo for maintenance
    final (bg, fg) = switch (room.status) {
      RoomStatus.occupied => (const Color(0xFF1A4731), const Color(0xFF4ADE80)),
      RoomStatus.vacant => (const Color(0xFF3D2E00), const Color(0xFFFBBF24)),
      RoomStatus.maintenance => (
          const Color(0xFF2E1B5E),
          const Color(0xFFA78BFA)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        room.status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ── Overview section ───────────────────────────────────────────────────────────

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leasesAsync = ref.watch(roomLeasesProvider(room.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tenants row
                leasesAsync.when(
                  loading: () => const _OverviewRow(
                    icon: Icons.people_alt_outlined,
                    iconColor: Color(0xFF6B7280),
                    title: '...',
                    subtitle: 'Khách thuê',
                    isFirst: true,
                    isLast: false,
                  ),
                  error: (_, __) => _OverviewRow(
                    icon: Icons.people_alt_outlined,
                    iconColor: const Color(0xFF6B7280),
                    title: room.tenantName ?? 'Không có',
                    subtitle: 'Khách thuê',
                    isFirst: true,
                    isLast: false,
                  ),
                  data: (leases) {
                    final activeLeases = leases
                        .where((l) => l.status == LeaseStatus.active)
                        .toList();
                    final count = activeLeases.length;
                    final names = activeLeases
                        .take(2)
                        .map((l) => l.tenantName ?? 'Khách thuê')
                        .join(' & ');
                    return _OverviewRow(
                      icon: Icons.people_alt_outlined,
                      iconColor: const Color(0xFF6B7280),
                      title: count == 0
                          ? 'Chưa có khách thuê'
                          : '$count khách thuê',
                      subtitle: count == 0 ? 'Phòng trống' : names,
                      isFirst: true,
                      isLast: false,
                    );
                  },
                ),
                // Area row
                if (room.areaSqm != null)
                  _OverviewRow(
                    icon: Icons.straighten_rounded,
                    iconColor: const Color(0xFF6B7280),
                    title: formatArea(room.areaSqm),
                    subtitle: 'Diện tích phòng',
                    isFirst: false,
                    isLast: room.floor == null,
                  ),
                // Floor / capacity
                if (room.floor != null)
                  _OverviewRow(
                    icon: Icons.layers_rounded,
                    iconColor: const Color(0xFF6B7280),
                    title: 'Tầng ${room.floor}',
                    subtitle: room.capacity != null
                        ? 'Sức chứa: ${room.capacity} người'
                        : 'Tầng phòng',
                    isFirst: false,
                    isLast: false,
                  ),
                // Due date — from the first active lease
                leasesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (leases) {
                    if (leases.isEmpty) {
                      return const _OverviewRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: Color(0xFF6B7280),
                        title: 'Chưa có hợp đồng',
                        subtitle: 'Kỳ thu tiền tiếp theo',
                        isFirst: false,
                        isLast: true,
                      );
                    }

                    Lease? active;
                    for (final lease in leases) {
                      if (lease.status == LeaseStatus.active) {
                        active = lease;
                        break;
                      }
                    }
                    active ??= leases.first;

                    // Estimate next due = start day of month + 1 month.
                    final start = active.startDate;
                    final now = DateTime.now();
                    var nextDue =
                        DateTime(now.year, now.month, start?.day ?? 1);
                    if (nextDue.isBefore(now)) {
                      nextDue =
                          DateTime(now.year, now.month + 1, start?.day ?? 1);
                    }
                    final diff = nextDue.difference(now).inDays;
                    return _OverviewRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor:
                          diff <= 5 ? _kOrangeAccent : const Color(0xFF6B7280),
                      title: diff <= 0 ? 'Đến hạn hôm nay' : 'Còn $diff ngày',
                      subtitle:
                          'Thu tiền tiếp theo ${nextDue.day}/${nextDue.month}/${nextDue.year}',
                      isFirst: false,
                      isLast: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isFirst,
    required this.isLast,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 76,
            endIndent: 18,
            color: _kDivider,
          ),
      ],
    );
  }
}

// ── About this room section ───────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final note = room.note?.trim();
    final amenities = room.amenities;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this room',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _kTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note != null && note.isNotEmpty
                ? note
                : 'Phòng tiện nghi, đầy đủ nội thất. Vui lòng liên hệ để biết thêm chi tiết.',
            style: const TextStyle(
              fontSize: 14,
              color: _kTextMuted,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _kOrangeAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _kOrangeAccent.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          a,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kOrangeAccent,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Expanded tab content (details, fees, inspections, leases) ─────────────────

class _ExpandedTabContent extends StatefulWidget {
  const _ExpandedTabContent({
    required this.room,
    required this.tabController,
  });
  final Room room;
  final TabController tabController;

  @override
  State<_ExpandedTabContent> createState() => _ExpandedTabContentState();
}

class _ExpandedTabContentState extends State<_ExpandedTabContent> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header + tab selector pill
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Row(
            children: [
              const Text(
                'Chi tiết phòng',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kTextPrimary,
                ),
              ),
              const Spacer(),
              // Compact tab pill switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      GestureDetector(
                        onTap: () {
                          widget.tabController.animateTo(i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: widget.tabController.index == i
                                ? _kOrangeAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            ['Info', 'Ảnh', 'Lịch', 'Hợp đồng'][i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.tabController.index == i
                                  ? Colors.white
                                  : _kTextMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: switch (widget.tabController.index) {
            0 => _InfoTab(room: widget.room),
            1 => _PhotosTab(room: widget.room),
            2 => _MetersTab(room: widget.room),
            3 => _ContractTab(room: widget.room),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

// ── Chip helpers ──────────────────────────────────────────────────────────────

// ── (TabBarDelegate removed — tabs moved into _ExpandedTabContent) ─────────────

// ── Tab: Thông tin ────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(roomServiceFeesProvider(room.id));
    final assetsAsync = ref.watch(roomAssetsProvider(room.id));
    final session = ref.watch(sessionControllerProvider).session;
    final canActivateTariff = session?.user.role == 'landlord' &&
        sessionHasPermission(session, 'room.manage');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description / note
        if (room.note != null && room.note!.trim().isNotEmpty) ...[
          _SectionCard(
            title: 'Mô tả',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.note!,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF374151), height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Amenities
        if (room.amenities.isNotEmpty) ...[
          _SectionCard(
            title: 'Tiện ích',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  room.amenities.map((a) => _AmenityChip(label: a)).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Service fees
        _SectionCard(
          title: 'Phí cố định hàng tháng',
          trailing: IconButton(
            tooltip: 'Thêm phí',
            onPressed: canActivateTariff
                ? () => _showServiceFeeDialog(context, ref, room.id)
                : null,
            icon: const Icon(Icons.add_card_rounded,
                color: AppTheme.primary, size: 22),
            visualDensity: VisualDensity.compact,
          ),
          child: feesAsync.when(
            loading: () =>
                const LinearProgressIndicator(color: AppTheme.primary),
            error: (e, _) => Text('$e'),
            data: (fees) {
              if (fees.isEmpty) {
                return const Text(
                  'Chưa có phí cố định.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                );
              }
              final activeTotal = fees
                  .where((f) => f.isActive)
                  .fold<int>(0, (sum, f) => sum + f.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng phí active: ${formatCurrencyVnd(activeTotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...fees.map(
                    (fee) => _FeeRow(
                      fee: fee,
                      onHistory: () => showServiceTariffHistory(context, fee),
                      onEdit: canActivateTariff
                          ? () => _showServiceFeeDialog(context, ref, room.id,
                              fee: fee)
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Assets
        _SectionCard(
          title: 'Tài sản phòng',
          trailing: IconButton(
            tooltip: 'Thêm tài sản',
            onPressed: () => _showAssetDialog(context, ref, room.id),
            icon: const Icon(Icons.add_rounded,
                color: AppTheme.primary, size: 22),
            visualDensity: VisualDensity.compact,
          ),
          child: assetsAsync.when(
            loading: () =>
                const LinearProgressIndicator(color: AppTheme.primary),
            error: (e, _) => Text('$e'),
            data: (assets) {
              if (assets.isEmpty) {
                return const Text(
                  'Chưa ghi nhận tài sản.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                );
              }
              return Column(
                children: assets
                    .map(
                      (a) => _AssetRow(
                        asset: a,
                        onDelete: () => ref
                            .read(roomOperationsControllerProvider.notifier)
                            .deleteAsset(roomId: room.id, assetId: a.id),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _showServiceFeeDialog(
          BuildContext context, WidgetRef ref, String roomId,
          {RoomServiceFee? fee}) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ServiceTariffDialog(roomId: roomId, fee: fee),
      );

  Future<void> _showAssetDialog(
      BuildContext context, WidgetRef ref, String roomId) async {
    final name = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final condition = TextEditingController(text: 'good');
    final value = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm tài sản'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên tài sản')),
              TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số lượng')),
              TextField(
                  controller: condition,
                  decoration: const InputDecoration(labelText: 'Tình trạng')),
              TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Giá trị')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (submitted != true) return;
    await ref.read(roomOperationsControllerProvider.notifier).createAsset(
          roomId: roomId,
          asset: RoomAsset(
            id: '',
            roomId: roomId,
            name: name.text.trim(),
            quantity: int.tryParse(quantity.text) ?? 1,
            condition:
                condition.text.trim().isEmpty ? 'good' : condition.text.trim(),
            value: int.tryParse(value.text),
          ),
        );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow(
      {required this.fee, required this.onHistory, required this.onEdit});
  final RoomServiceFee fee;
  final VoidCallback onHistory;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onEdit,
      title: Text(fee.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${formatCurrencyVnd(fee.amount)} · ${fee.isActive ? 'Đang thu' : 'Chưa / ngừng thu'}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF8891A8))),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'Tạo phiên bản mới',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_calendar_rounded,
                color: AppTheme.primary, size: 20)),
        IconButton(
            tooltip: 'Lịch sử biểu phí',
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded,
                color: AppTheme.primary, size: 20)),
      ]),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.onDelete});
  final RoomAsset asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
      title: Text(asset.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
        'SL ${asset.quantity} · ${asset.condition}'
        '${asset.value == null ? '' : ' · ${formatCurrencyVnd(asset.value!)}'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Xóa tài sản',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFF9CA3AF), size: 20),
      ),
    );
  }
}

// ── Tab: Ảnh ─────────────────────────────────────────────────────────────────

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final photos = RoomImageCatalog.galleryFor(room);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'ẢNH CHI TIẾT',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    _PhotoTile(
                      source: photos[i],
                      width: tileWidth,
                      index: i,
                      onTap: () => _showPhotoViewer(context, photos, i),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _showPhotoViewer(
    BuildContext context,
    List<String> photos,
    int initialIndex,
  ) async {
    final controller = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: photos.length,
                onPageChanged: (index) => setState(() => currentIndex = index),
                itemBuilder: (context, index) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: RoomImageView(
                      source: photos[index],
                      fit: BoxFit.contain,
                      placeholder: const _PhotoViewerPlaceholder(),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    _PhotoViewerButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${currentIndex + 1}/${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.source,
    required this.width,
    required this.index,
    required this.onTap,
  });

  final String source;
  final double width;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          height: width * 0.72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RoomImageView(
                source: source,
                placeholder: const _PhotoTilePlaceholder(),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

class _PhotoTilePlaceholder extends StatelessWidget {
  const _PhotoTilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF22263A),
      child: const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
    );
  }
}

class _PhotoViewerPlaceholder extends StatelessWidget {
  const _PhotoViewerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.broken_image_outlined,
        color: Colors.white54, size: 48);
  }
}

class _PhotoViewerButton extends StatelessWidget {
  const _PhotoViewerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Tab: Chỉ số điện nước ─────────────────────────────────────────────────────

class _MetersTab extends ConsumerWidget {
  const _MetersTab({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionsAsync = ref.watch(roomInspectionsProvider(room.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Lịch kiểm tra phòng',
          trailing: IconButton(
            tooltip: 'Lên lịch kiểm tra',
            onPressed: () => _showInspectionDialog(context, ref, room.id),
            icon: const Icon(Icons.add_task_rounded,
                color: AppTheme.primary, size: 22),
            visualDensity: VisualDensity.compact,
          ),
          child: inspectionsAsync.when(
            loading: () =>
                const LinearProgressIndicator(color: AppTheme.primary),
            error: (e, _) => Text('$e'),
            data: (items) {
              if (items.isEmpty) {
                return const Text(
                  'Chưa có lịch kiểm tra.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item.isCompleted,
                        activeColor: AppTheme.primary,
                        onChanged: item.isCompleted
                            ? null
                            : (_) => ref
                                .read(roomOperationsControllerProvider.notifier)
                                .completeInspection(
                                  roomId: room.id,
                                  inspectionId: item.id,
                                ),
                        title: Text(item.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('Hạn: ${formatDate(item.dueAt)}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Link to billing for meter readings
        Container(
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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.electric_bolt_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉ số điện, nước',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Nhập qua màn hình Tạo hóa đơn',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF2E3348)),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _showInspectionDialog(
      BuildContext context, WidgetRef ref, String roomId) async {
    final title = TextEditingController(text: 'Kiểm tra định kỳ');
    var dueAt = DateTime.now().add(const Duration(days: 7));
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Lên lịch kiểm tra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Hạn: ${formatDate(dueAt)}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => dueAt = picked);
                    },
                    child: const Text('Chọn ngày'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    await ref.read(roomOperationsControllerProvider.notifier).createInspection(
          roomId: roomId,
          inspection: RoomInspection(
            id: '',
            roomId: roomId,
            title: title.text.trim(),
            dueAt: dueAt,
          ),
        );
  }
}

// ── Tab: Hợp đồng ─────────────────────────────────────────────────────────────

class _ContractTab extends ConsumerWidget {
  const _ContractTab({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leasesAsync = ref.watch(roomLeasesProvider(room.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leasesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
          error: (_, __) => _SectionCard(
            title: 'Khách thuê',
            child: Text(room.tenantName ?? 'Chưa có'),
          ),
          data: (leases) {
            Lease? active;
            for (final l in leases) {
              if (l.status == LeaseStatus.active) {
                active = l;
                break;
              }
            }

            if (active == null) {
              return const Column(
                children: [
                  _SectionCard(
                    title: 'Khách thuê',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 20, color: Color(0xFF9CA3AF)),
                        SizedBox(width: 10),
                        Text(
                          'Phòng đang trống — chưa có khách thuê',
                          style:
                              TextStyle(fontSize: 14, color: Color(0xFF8891A8)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _SectionCard(
                  title: 'NGƯỜI THUÊ HIỆN TẠI',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (active.tenantName ?? '?').trim().isNotEmpty
                                    ? active.tenantName!
                                        .trim()
                                        .characters
                                        .first
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  active.tenantName ?? 'Khách thuê',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF0F2FF),
                                  ),
                                ),
                                const Text(
                                  'Đang thuê',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context
                                .push(tenantDetailPath(active!.tenantId)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Hồ sơ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => openMessagingApp(
                              context,
                              tenantId: active!.tenantId,
                              tenantName: active.tenantName,
                              roomName: active.roomName ?? room.name,
                              template: 'call_back',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0068FF)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Nhắn',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0068FF),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFF22263A)),
                      _DetailRow(
                          label: 'Giá thuê',
                          value: formatCurrencyVnd(active.monthlyRent)),
                      const Divider(height: 1, color: Color(0xFF22263A)),
                      _DetailRow(
                          label: 'Tiền cọc',
                          value: formatCurrencyVnd(active.deposit)),
                      const Divider(height: 1, color: Color(0xFF22263A)),
                      _DetailRow(
                          label: 'Ngày bắt đầu',
                          value: formatDate(active.startDate)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Kết thúc hợp đồng active trước khi ngưng sử dụng hoặc xóa phòng.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Sticky Bottom Bar ─────────────────────────────────────────────────────────

class _StickyBottomBar extends ConsumerWidget {
  const _StickyBottomBar({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOccupied = room.status == RoomStatus.occupied;
    final label = room.isActive
        ? (isOccupied ? 'Tạo hóa đơn  →' : 'Ký hợp đồng  →')
        : 'Phòng ngưng sử dụng';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: GestureDetector(
        onTap: room.isActive
            ? () => context.push(
                isOccupied ? billingFormRoute : leaseFormPath(tenantId: ''))
            : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: room.isActive ? _kOrangeAccent : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(20),
            boxShadow: room.isActive
                ? [
                    BoxShadow(
                      color: _kOrangeAccent.withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: room.isActive ? Colors.white : const Color(0xFF9CA3AF),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared section card ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8891A8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF8891A8))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF0F2FF),
            ),
          ),
        ],
      ),
    );
  }
}
