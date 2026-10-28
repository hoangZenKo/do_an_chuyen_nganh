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
import '../tenants/tenant_providers.dart';
import 'room_providers.dart';
import 'widgets/room_image.dart';

/// Read-only detail for a single room, redesigned with property-listing
/// style: hero image, floating nav, tab bar, sticky bottom CTA.
class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      backgroundColor: const Color(0xFFF5F7FA),
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
                size: 56, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280))),
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
        // Scrollable content
        CustomScrollView(
          slivers: [
            // ── Hero image ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _HeroSection(room: room)),
            // ── Status + name + address ───────────────────────────────────
            SliverToBoxAdapter(
              child: _RoomInfoHeader(
                room: room,
                onDeactivate: onDeactivate,
                onReactivate: onReactivate,
                onDelete: onDelete,
              ),
            ),
            // ── Tab bar ───────────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(tabController: tabController),
            ),
            // ── Tab content ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _TabContent(
                room: room,
                tabController: tabController,
              ),
            ),
            // Bottom padding for sticky bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        // ── Floating back/share/menu buttons ─────────────────────────────
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
        // ── Sticky bottom CTA ─────────────────────────────────────────────
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
    final hasImage = imageSource != null && imageSource.isNotEmpty;

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RoomImageView(
            source: imageSource,
            placeholder: _HeroPlaceholder(room: room),
          ),
          // Gradient overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Photo strip at bottom if needed (single image for now)
          if (hasImage)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '1 ảnh',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
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
            statusColor.withValues(alpha: 0.20),
            AppTheme.primary.withValues(alpha: 0.35),
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
              color: Colors.white.withValues(alpha: 0.25),
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

// ── Room info header ──────────────────────────────────────────────────────────

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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Row(
            children: [
              _StatusBadge(room: room),
              const Spacer(),
              // Occupancy rate chip
              if (room.capacity != null && room.capacity! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '${room.capacity} người tối đa',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Room name
          Text(
            room.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          // Address / property hint
          if (!room.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      size: 16, color: Color(0xFF6B7280)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Phòng đang ngưng sử dụng',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Quick info chips row (Beds / Bath / sqft style)
          _InfoChipsRow(room: room),
          const SizedBox(height: 16),
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
    final color = room.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            room.status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (room.floor != null)
        _InfoChip(
          icon: Icons.layers_rounded,
          label: 'Tầng ${room.floor}',
        ),
      if (room.areaSqm != null)
        _InfoChip(
          icon: Icons.square_foot_rounded,
          label: formatArea(room.areaSqm),
        ),
      if (room.capacity != null)
        _InfoChip(
          icon: Icons.people_outline_rounded,
          label: '${room.capacity} người',
        ),
      if (room.amenities.isNotEmpty)
        _InfoChip(
          icon: Icons.wifi_rounded,
          label: '${room.amenities.length} tiện ích',
        ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final chip in chips) chip,
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabController});
  final TabController tabController;

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: tabController,
            isScrollable: true,
            labelPadding: const EdgeInsets.symmetric(horizontal: 18),
            labelColor: AppTheme.primary,
            unselectedLabelColor: const Color(0xFF9CA3AF),
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Thông tin'),
              Tab(text: 'Ảnh'),
              Tab(text: 'Chỉ số'),
              Tab(text: 'Hợp đồng'),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabController != tabController;
}

// ── Tab content ───────────────────────────────────────────────────────────────

class _TabContent extends StatefulWidget {
  const _TabContent({required this.room, required this.tabController});
  final Room room;
  final TabController tabController;

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: switch (widget.tabController.index) {
        0 => _InfoTab(room: widget.room),
        1 => _PhotosTab(room: widget.room),
        2 => _MetersTab(room: widget.room),
        3 => _ContractTab(room: widget.room),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// ── Tab: Thông tin ────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesAsync = ref.watch(roomServiceFeesProvider(room.id));
    final assetsAsync = ref.watch(roomAssetsProvider(room.id));

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
            onPressed: () => _showServiceFeeDialog(context, ref, room.id),
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
                      onToggle: (v) => ref
                          .read(roomOperationsControllerProvider.notifier)
                          .setServiceFeeActive(
                            roomId: room.id,
                            feeId: fee.id,
                            isActive: v,
                          ),
                      onDelete: () => ref
                          .read(roomOperationsControllerProvider.notifier)
                          .deleteServiceFee(roomId: room.id, feeId: fee.id),
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
      BuildContext context, WidgetRef ref, String roomId) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm phí cố định'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'Tên phí',
                      hintText: 'Internet, rác, gửi xe...')),
              TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số tiền')),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Ghi chú')),
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
    await ref.read(roomOperationsControllerProvider.notifier).createServiceFee(
          roomId: roomId,
          fee: RoomServiceFee(
            id: '',
            roomId: roomId,
            name: name.text.trim(),
            amount: int.tryParse(amount.text) ?? 0,
            isActive: true,
            note: note.text.trim().isEmpty ? null : note.text.trim(),
          ),
        );
  }

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
      {required this.fee, required this.onToggle, required this.onDelete});
  final RoomServiceFee fee;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: fee.isActive,
      onChanged: onToggle,
      activeColor: AppTheme.primary,
      title: Text(fee.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(formatCurrencyVnd(fee.amount),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      secondary: IconButton(
        tooltip: 'Xóa phí',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFF9CA3AF), size: 20),
      ),
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
      color: const Color(0xFFF3F4F6),
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
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
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
                              TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
                                    color: Color(0xFF111827),
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
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _DetailRow(
                          label: 'Giá thuê',
                          value: formatCurrencyVnd(active.monthlyRent)),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _DetailRow(
                          label: 'Tiền cọc',
                          value: formatCurrencyVnd(active.deposit)),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Giá thuê',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              Text(
                formatCurrencyVnd(room.basePrice),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  height: 1,
                ),
              ),
              const Text(
                '/tháng',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: room.isActive
                  ? () => context.push(isOccupied
                      ? billingFormRoute
                      : leaseFormPath(tenantId: ''))
                  : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: room.isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF0D6E62), Color(0xFF0A5A50)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: room.isActive ? null : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: room.isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    room.isActive
                        ? (isOccupied ? 'Tạo hóa đơn' : 'Ký hợp đồng')
                        : 'Phòng ngưng sử dụng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: room.isActive
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                    color: Color(0xFF6B7280),
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
