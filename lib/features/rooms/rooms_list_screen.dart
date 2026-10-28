import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import '../../core/utils/format.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import 'room_providers.dart';
import 'widgets/room_image.dart';

// ── Color tokens ──────────────────────────────────────────────────────────────
const _kDarkNavy = Color(0xFF141C2E);
const _kOrange = Color(0xFFFF6600);
const _kBg = Color(0xFFF5F7FB);
const _kTextPrimary = Color(0xFF0F1117);
const _kTextMuted = Color(0xFF8891A8);
const _kWhite = Colors.white;

/// Rooms tab: dark navy header, search bar, status filter chips,
/// stats cards, and a modern list of room cards per the provided mockup.
class RoomsListScreen extends ConsumerStatefulWidget {
  const RoomsListScreen({super.key});

  @override
  ConsumerState<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends ConsumerState<RoomsListScreen> {
  RoomStatus? _filter;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  var _showInactive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final selectedId = ref.watch(selectedPropertyProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: propertiesAsync.when(
        loading: () => const _CenteredLoader(),
        error: (error, _) => ListView(
          padding: EdgeInsets.only(bottom: liquidTaskbarBottomPadding(context)),
          children: [
            _CenteredError(
              message: '$error',
              onRetry: () => ref.invalidate(propertiesProvider),
            ),
          ],
        ),
        data: (properties) {
          if (properties.isEmpty) {
            return ListView(
              padding:
                  EdgeInsets.only(bottom: liquidTaskbarBottomPadding(context)),
              children: [
                _EmptyState(
                  icon: Icons.apartment_rounded,
                  title: 'Chưa có khu trọ',
                  message: 'Tạo khu trọ để bắt đầu quản lý phòng.',
                  actionLabel: 'Tạo khu trọ',
                  onAction: () => context.push(propertyFormRoute),
                ),
              ],
            );
          }
          final property = properties.firstWhere(
            (p) => p.id == selectedId,
            orElse: () => properties.first,
          );
          return Column(
            children: [
              // ── Dark navy header ──────────────────────────────────────
              _RoomsHeader(
                property: property,
                properties: properties,
                onSelect: (id) {
                  ref.read(selectedPropertyProvider.notifier).state = id;
                  setState(() {
                    _filter = null;
                    _showInactive = false;
                  });
                },
              ),

              // ── White rounded card body ───────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: _kBg,
                  ),
                  child: Column(
                    children: [
                      // Search bar
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                      ),

                      // Filter chips (All, Occupied, Vacant + Filters button)
                      _StatusFilterRow(
                        selected: _filter,
                        showInactive: _showInactive,
                        onChanged: (v) => setState(() => _filter = v),
                        onToggleInactive: (v) =>
                            setState(() => _showInactive = v),
                      ),

                      // Stats row
                      _StatsRow(
                        propertyId: property.id,
                        totalProperties: properties.length,
                      ),

                      // Room list
                      Expanded(
                        child: _RoomsList(
                          propertyId: property.id,
                          filter: _showInactive ? null : _filter,
                          showInactive: _showInactive,
                          searchQuery: _searchQuery,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Dark navy header ──────────────────────────────────────────────────────────

class _RoomsHeader extends StatelessWidget {
  const _RoomsHeader({
    required this.property,
    required this.properties,
    required this.onSelect,
  });

  final Property property;
  final List<Property> properties;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkNavy,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        20,
      ),
      child: Row(
        children: [
          // Orange house icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.home_rounded, color: _kOrange, size: 22),
          ),
          const SizedBox(width: 12),

          // Title + property picker
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rooms',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (properties.length > 1)
                  GestureDetector(
                    onTap: () => _showPropertySheet(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            property.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 14, color: _kTextMuted),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: _kOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 10),

          // Add room button
          GestureDetector(
            onTap: () => context.push(roomFormPath()),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _showPropertySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn khu trọ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            for (final p in properties)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.home_rounded, color: _kOrange, size: 18),
                ),
                title: Text(p.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('${p.roomCount} phòng',
                    style: const TextStyle(color: _kTextMuted, fontSize: 12)),
                trailing: p.id == property.id
                    ? const Icon(Icons.check_circle_rounded,
                        color: _kOrange, size: 20)
                    : null,
                onTap: () {
                  onSelect(p.id);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkNavy,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 14,
            color: _kTextPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: const InputDecoration(
            hintText: 'Search rooms by name or number...',
            hintStyle: TextStyle(
              color: _kTextMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon:
                Icon(Icons.search_rounded, color: _kTextMuted, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ── Status filter row ─────────────────────────────────────────────────────────

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({
    required this.selected,
    required this.showInactive,
    required this.onChanged,
    required this.onToggleInactive,
  });

  final RoomStatus? selected;
  final bool showInactive;
  final ValueChanged<RoomStatus?> onChanged;
  final ValueChanged<bool> onToggleInactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // All chip
          _Chip(
            label: 'All',
            color: _kOrange,
            dot: false,
            selected: selected == null && !showInactive,
            onTap: () {
              onToggleInactive(false);
              onChanged(null);
            },
          ),
          // Occupied chip
          _Chip(
            label: 'Occupied',
            color: const Color(0xFF22C55E),
            dot: true,
            selected: selected == RoomStatus.occupied && !showInactive,
            onTap: () {
              onToggleInactive(false);
              onChanged(RoomStatus.occupied);
            },
          ),
          // Vacant chip
          _Chip(
            label: 'Vacant',
            color: _kTextMuted,
            dot: true,
            selected: selected == RoomStatus.vacant && !showInactive,
            onTap: () {
              onToggleInactive(false);
              onChanged(RoomStatus.vacant);
            },
          ),

          // Filters button
          GestureDetector(
            onTap: () => onToggleInactive(!showInactive),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: showInactive
                    ? _kOrange.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: showInactive ? _kOrange : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: showInactive ? _kOrange : _kTextMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: showInactive ? _kOrange : _kTextMuted,
                    ),
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool dot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : _kTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends ConsumerWidget {
  const _StatsRow({
    required this.propertyId,
    required this.totalProperties,
  });

  final String propertyId;
  final int totalProperties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider(propertyId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: roomsAsync.when(
        loading: () => const SizedBox(height: 72),
        error: (_, __) => const SizedBox.shrink(),
        data: (rooms) {
          final total = rooms.length;
          final occupied =
              rooms.where((r) => r.status == RoomStatus.occupied).length;
          final occupancyPct = total == 0 ? 0 : (occupied * 100 ~/ total);

          return Row(
            children: [
              // Total rooms card
              Expanded(
                child: _StatCard(
                  label: 'Total rooms',
                  value: '$total',
                  sub:
                      'Across $totalProperties propert${totalProperties == 1 ? 'y' : 'ies'}',
                ),
              ),
              const SizedBox(width: 12),
              // Occupancy card
              Expanded(
                child: _StatCard(
                  label: 'Occupancy',
                  value: '$occupancyPct%',
                  sub: '$occupied of $total rooms',
                  valueColor: occupancyPct >= 80
                      ? const Color(0xFF16A34A)
                      : occupancyPct >= 50
                          ? _kOrange
                          : const Color(0xFFEF4444),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final String sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: valueColor ?? _kTextPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: _kTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rooms list ────────────────────────────────────────────────────────────────

class _RoomsList extends ConsumerWidget {
  const _RoomsList({
    required this.propertyId,
    required this.filter,
    required this.showInactive,
    required this.searchQuery,
  });

  final String propertyId;
  final RoomStatus? filter;
  final bool showInactive;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = showInactive
        ? inactiveRoomsProvider(propertyId)
        : roomsProvider(propertyId);
    final roomsAsync = ref.watch(provider);

    return roomsAsync.when(
      loading: () => const _CenteredLoader(),
      error: (error, _) => ListView(
        padding: EdgeInsets.only(bottom: liquidTaskbarBottomPadding(context)),
        children: [
          _CenteredError(
            message: '$error',
            onRetry: () => ref.invalidate(provider),
          ),
        ],
      ),
      data: (rooms) {
        var visible = filter == null
            ? rooms
            : rooms.where((r) => r.status == filter).toList(growable: false);

        if (searchQuery.isNotEmpty) {
          visible = visible
              .where((r) => r.name.toLowerCase().contains(searchQuery))
              .toList(growable: false);
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(provider),
          child: visible.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                      bottom: liquidTaskbarBottomPadding(context)),
                  children: [
                    const SizedBox(height: 60),
                    _EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: showInactive
                          ? 'Không có phòng ngưng sử dụng'
                          : 'Không có phòng',
                      message: searchQuery.isNotEmpty
                          ? 'Không tìm thấy phòng khớp với "$searchQuery".'
                          : showInactive
                              ? 'Phòng ngưng sử dụng sẽ xuất hiện ở đây.'
                              : 'Chưa có phòng nào khớp bộ lọc này.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      16, 14, 16, liquidTaskbarBottomPadding(context)),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RoomCard(room: visible[i]),
                ),
        );
      },
    );
  }
}

// ── Room card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final (statusBg, statusFg) = switch (room.status) {
      RoomStatus.occupied => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      RoomStatus.vacant => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      RoomStatus.maintenance => (
          const Color(0xFFEDE9FE),
          const Color(0xFF7C3AED)
        ),
    };

    return GestureDetector(
      onTap: () => context.push(roomDetailPath(room.id)),
      child: Container(
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Room photo ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: SizedBox(
                width: 110,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RoomImageView(
                      source: RoomImageCatalog.imageFor(room),
                      fit: BoxFit.cover,
                      placeholder: _RoomThumbnailPlaceholder(room: room),
                    ),
                    // Status badge overlaid on image
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusFg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Room info ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room name
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Tenant count / name
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 13, color: _kTextMuted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            room.tenantName != null
                                ? room.tenantName!
                                : room.status == RoomStatus.occupied
                                    ? '${room.capacity ?? 1} tenant${(room.capacity ?? 1) > 1 ? 's' : ''}'
                                    : '0 tenants',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatCurrencyVnd(room.basePrice),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kTextPrimary,
                          ),
                        ),
                        const Text(
                          ' / month',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Area / floor info
                    if (room.areaSqm != null || room.floor != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 11, color: _kOrange),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if (room.floor != null) 'Tầng ${room.floor}',
                              if (room.areaSqm != null)
                                formatArea(room.areaSqm),
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                    if (!room.isActive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Ngưng sử dụng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Chevron
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomThumbnailPlaceholder extends StatelessWidget {
  const _RoomThumbnailPlaceholder({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: room.status.color.withValues(alpha: 0.10),
      child: Icon(
        Icons.meeting_room_rounded,
        color: room.status.color.withValues(alpha: 0.6),
        size: 32,
      ),
    );
  }
}

// ── Shared state widgets ──────────────────────────────────────────────────────

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

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
                size: 56, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMuted),
            ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child:
                  Icon(icon, size: 40, color: _kOrange.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kTextMuted, fontSize: 14),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: _kOrange,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
