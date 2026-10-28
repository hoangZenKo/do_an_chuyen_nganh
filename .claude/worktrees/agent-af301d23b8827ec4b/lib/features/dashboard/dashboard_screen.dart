import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/dashboard.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../billing/billing_screen.dart';
import '../rooms/room_providers.dart';
import '../rooms/rooms_list_screen.dart';
import '../rooms/widgets/room_image.dart';
import 'dashboard_providers.dart';

const _tencentBlue = Color(0xFF0D6E62);
// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final canViewRooms = sessionHasAnyPermission(session, const [
      'property.view',
      'property.manage',
      'room.view',
      'room.manage',
      'tenant.view',
      'tenant.manage',
    ]);
    final canViewTenants =
        sessionHasAnyPermission(session, const ['tenant.view', 'tenant.manage']);
    final canViewBilling =
        sessionHasAnyPermission(session, const ['billing.view', 'billing.create']);
    final canCreateRoom = sessionHasPermission(session, 'room.manage');
    final canCreateInvoice = sessionHasPermission(session, 'billing.create');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: switch (_selectedTab) {
          0 => _OverviewTab(
              canOpenNotifications:
                  sessionHasPermission(session, 'notification.view'),
              canOpenProperties: canViewRooms,
            ),
          1 => const RoomsListScreen(),
          2 => const BillingScreen(),
          _ => _PlaceholderTab(
              label: [
                'Tổng quan',
                'Phòng',
                'Thu tiền',
                'Hóa đơn',
                'Thêm'
              ][_selectedTab],
            ),
        },
      ),
      bottomNavigationBar: _BottomNav(
        selected: _selectedTab,
        onTap: (i) {
          if (i == 1 && !canViewRooms) {
            context.push(settingsRoute);
            return;
          }
          if (i == 2 && !canViewBilling) {
            context.push(settingsRoute);
            return;
          }
          if (i == 3) {
            if (canViewTenants) {
              context.push(tenantsRoute);
            } else {
              context.push(settingsRoute);
            }
            return;
          }
          setState(() => _selectedTab = i);
        },
      ),
      floatingActionButton: _AddFab(
        onTap: switch (_selectedTab) {
          1 when canCreateRoom => () => context.push(roomFormPath()),
          2 when canCreateInvoice => () => context.push(billingFormRoute),
          _ => null,
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.home_rounded, label: 'Tổng quan'),
      _NavItem(icon: Icons.meeting_room_rounded, label: 'Phòng'),
      _NavItem(icon: Icons.add, label: ''),
      _NavItem(icon: Icons.receipt_long_rounded, label: 'Hóa đơn'),
      _NavItem(icon: Icons.more_horiz_rounded, label: 'Thêm'),
    ];

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
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              if (i == 2) return const SizedBox(width: 64);
              final item = items[i];
              final realIndex = i > 2 ? i - 1 : i;
              final isSelected = selected == realIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(realIndex),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _AddFab extends StatelessWidget {
  const _AddFab({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF0D6E62), Color(0xFF0A5A50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({
    required this.canOpenNotifications,
    required this.canOpenProperties,
  });

  final bool canOpenNotifications;
  final bool canOpenProperties;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  RoomStatus? _categoryFilter;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final selectedId = ref.watch(selectedPropertyProvider);
    final properties = propertiesAsync.valueOrNull ?? const <Property>[];
    final property = _selectedProperty(properties, selectedId);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final months = ref.watch(dashboardMonthsProvider);

    return RefreshIndicator(
      color: _tencentBlue,
      onRefresh: () => _refreshDashboard(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _LocationHeader(
              property: property,
              properties: properties,
              isLoadingProperties: propertiesAsync.isLoading,
              canOpenNotifications: widget.canOpenNotifications,
              canOpenProperties: widget.canOpenProperties,
              onSelectProperty: (id) {
                ref.read(selectedPropertyProvider.notifier).state = id;
                ref.invalidate(dashboardMetricsProvider);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: _SearchBar(
              controller: _searchController,
              onFilter: () => context.push(propertiesRoute),
            ),
          ),
          SliverToBoxAdapter(
            child: _CategoryChips(
              selected: _categoryFilter,
              onChanged: (v) => setState(() => _categoryFilter = v),
            ),
          ),
          ...metricsAsync.when(
            loading: () => _loadingSlivers,
            error: (error, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CenteredError(
                  message: '$error',
                  onRetry: () => ref.invalidate(dashboardMetricsProvider),
                ),
              ),
            ],
            data: (metrics) => _contentSlivers(
              metrics: metrics,
              months: months,
              onMonthsChanged: (value) =>
                  ref.read(dashboardMonthsProvider.notifier).state = value,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Property? _selectedProperty(List<Property> properties, String? selectedId) {
    if (properties.isEmpty) return null;
    return properties.firstWhere(
      (property) => property.id == selectedId,
      orElse: () => properties.first,
    );
  }

  List<Widget> _contentSlivers({
    required DashboardMetrics metrics,
    required int months,
    required ValueChanged<int> onMonthsChanged,
  }) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(child: _StatsRow(stats: metrics.roomStats)),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _FinanceSummary(currentMonth: metrics.currentMonth),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Phòng cần chú ý',
            actionLabel: 'Xem hết',
            onAction: () {},
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _FeaturedRoomsSection(items: metrics.attentionItems),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _RevenueChart(
            points: metrics.revenueTrend,
            months: months,
            onMonthsChanged: onMonthsChanged,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Hóa đơn gần đây',
            actionLabel: 'Tất cả',
            onAction: () {},
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        sliver: SliverToBoxAdapter(
          child: _RecentInvoicesSection(invoices: metrics.recentInvoices),
        ),
      ),
    ];
  }
}

Future<void> _refreshDashboard(WidgetRef ref) async {
  ref.invalidate(propertiesProvider);
  ref.invalidate(dashboardMetricsProvider);
  try {
    await Future.wait([
      ref.read(propertiesProvider.future),
      ref.read(dashboardMetricsProvider.future),
    ]);
  } catch (_) {}
}

List<Widget> get _loadingSlivers => const [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        sliver: SliverToBoxAdapter(child: _StatsSkeleton()),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(child: _WideSkeleton(height: 94)),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
        sliver: SliverToBoxAdapter(child: _WideSkeleton(height: 220)),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
        sliver: SliverToBoxAdapter(child: _WideSkeleton(height: 128)),
      ),
    ];

// ── Location-picker style Header ──────────────────────────────────────────────

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.property,
    required this.properties,
    required this.isLoadingProperties,
    required this.canOpenNotifications,
    required this.canOpenProperties,
    required this.onSelectProperty,
  });

  final Property? property;
  final List<Property> properties;
  final bool isLoadingProperties;
  final bool canOpenNotifications;
  final bool canOpenProperties;
  final ValueChanged<String> onSelectProperty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Khu trọ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _PropertyPicker(
                  property: property,
                  properties: properties,
                  isLoading: isLoadingProperties,
                  onSelect: onSelectProperty,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.notifications_outlined,
                color: const Color(0xFF0D6E62),
                bgColor: const Color(0xFFE6F4F2),
                onTap: canOpenNotifications
                    ? () => context.push(notificationsRoute)
                    : () => context.push(settingsRoute),
                tooltip: 'Thông báo',
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.manage_accounts_outlined,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                onTap: canOpenProperties
                    ? () => context.push(propertiesRoute)
                    : () => context.push(settingsRoute),
                tooltip: 'Quản lý khu trọ',
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.settings_outlined,
                color: const Color(0xFF6B7280),
                bgColor: const Color(0xFFF3F4F6),
                onTap: () => context.push(settingsRoute),
                tooltip: 'Cài đặt',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PropertyPicker extends StatelessWidget {
  const _PropertyPicker({
    required this.property,
    required this.properties,
    required this.isLoading,
    required this.onSelect,
  });

  final Property? property;
  final List<Property> properties;
  final bool isLoading;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
          SizedBox(width: 6),
          Text(
            'Đang tải...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      );
    }

    final label = property?.name ?? 'Chưa có khu trọ';

    if (properties.length <= 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      );
    }

    return PopupMenuButton<String>(
      onSelected: onSelect,
      itemBuilder: (_) => properties
          .map((p) => PopupMenuItem(
                value: p.id,
                child: Text(p.name),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF6B7280)),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onFilter});

  final TextEditingController controller;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Tìm phòng, khách thuê...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFB0B7C3)),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: Color(0xFFB0B7C3)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onFilter,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final RoomStatus? selected;
  final ValueChanged<RoomStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _CategoryChip(
                  label: 'Tất cả',
                  icon: Icons.grid_view_rounded,
                  isSelected: selected == null,
                  onTap: () => onChanged(null),
                ),
                const SizedBox(width: 12),
                _CategoryChip(
                  label: 'Đang thuê',
                  icon: Icons.people_alt_outlined,
                  isSelected: selected == RoomStatus.occupied,
                  onTap: () => onChanged(RoomStatus.occupied),
                ),
                const SizedBox(width: 12),
                _CategoryChip(
                  label: 'Phòng trống',
                  icon: Icons.meeting_room_outlined,
                  isSelected: selected == RoomStatus.vacant,
                  onTap: () => onChanged(RoomStatus.vacant),
                ),
                const SizedBox(width: 12),
                _CategoryChip(
                  label: 'Bảo trì',
                  icon: Icons.construction_rounded,
                  isSelected: selected == RoomStatus.maintenance,
                  onTap: () => onChanged(RoomStatus.maintenance),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final DashboardRoomStats stats;

  @override
  Widget build(BuildContext context) {
    final vacantRate =
        stats.total == 0 ? 0 : (stats.vacant / stats.total * 100).round();
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.grid_view_rounded,
            iconColor: const Color(0xFF3B82F6),
            label: 'TỔNG PHÒNG',
            value: '${stats.total}',
            sub: stats.maintenance > 0
                ? '${stats.maintenance} sửa chữa'
                : 'Tất cả',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'ĐANG THUÊ',
            value: '${stats.occupied}',
            sub: '${stats.occupancyRate}%',
            subColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.meeting_room_outlined,
            iconColor: const Color(0xFFF59E0B),
            label: 'PHÒNG TRỐNG',
            value: '${stats.vacant}',
            sub: '$vacantRate%',
            subColor: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    this.subColor,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subColor ?? const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Finance Summary ───────────────────────────────────────────────────────────

class _FinanceSummary extends StatelessWidget {
  const _FinanceSummary({required this.currentMonth});

  final DashboardCurrentMonth currentMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D6E62), Color(0xFF0A5A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _FinanceItem(
              label: 'Thực thu tháng này',
              value: formatCurrencyVnd(currentMonth.receivedAmount),
              valueColor: Colors.white,
              subLabel: 'Đã nhận',
              subColor: Colors.white.withValues(alpha: 0.7),
              icon: Icons.payments_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _FinanceItem(
                label: 'Chưa thu',
                value: '${currentMonth.outstandingInvoiceCount} hóa đơn',
                valueColor: const Color(0xFFFFD280),
                subLabel: formatCurrencyVnd(currentMonth.outstandingAmount),
                subColor: const Color(0xFFFFD280).withValues(alpha: 0.8),
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceItem extends StatelessWidget {
  const _FinanceItem({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subLabel,
    required this.subColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final String subLabel;
  final Color subColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 12,
            color: subColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Featured Rooms section ────────────────────────────────────────────────────

class _FeaturedRoomsSection extends StatefulWidget {
  const _FeaturedRoomsSection({required this.items});

  final List<DashboardAttentionItem> items;

  @override
  State<_FeaturedRoomsSection> createState() => _FeaturedRoomsSectionState();
}

class _FeaturedRoomsSectionState extends State<_FeaturedRoomsSection> {
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.76);
    _controller.addListener(_syncPage);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncPage);
    _controller.dispose();
    super.dispose();
  }

  void _syncPage() {
    if (!_controller.hasClients || !_controller.position.hasPixels) return;
    setState(
        () => _page = _controller.page ?? _controller.initialPage.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final sourceItems = widget.items;
    if (sourceItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded,
                    size: 36, color: Color(0xFFD1D5DB)),
                SizedBox(height: 8),
                Text(
                  'Không có phòng hoặc hóa đơn cần chú ý.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final items = _withPreviewItems(sourceItems);

    return SizedBox(
      height: 342,
      child: PageView.builder(
        controller: _controller,
        clipBehavior: Clip.none,
        padEnds: true,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final distance = (_page - index).abs().clamp(0.0, 1.0);
          final scale = 1 - (distance * 0.15);
          final opacity = 1 - (distance * 0.38);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 18),
              child: _FeaturedRoomCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }

  List<DashboardAttentionItem> _withPreviewItems(
    List<DashboardAttentionItem> sourceItems,
  ) {
    const minimumCards = 6;
    if (sourceItems.length >= minimumCards) return sourceItems;
    final existingIds = sourceItems.map((item) => item.roomId).toSet();
    final extras = _previewAttentionItems
        .where((item) => !existingIds.contains(item.roomId))
        .take(minimumCards - sourceItems.length);
    return [...sourceItems, ...extras];
  }

  static final _previewAttentionItems = [
    DashboardAttentionItem(
      kind: DashboardAttentionKind.maintenanceRoom,
      roomId: 'preview-p302',
      roomName: 'P.302',
      propertyName: 'Nhà trọ Minh Khai',
      updatedAt: DateTime(2026, 8, 10),
    ),
    DashboardAttentionItem(
      kind: DashboardAttentionKind.maintenanceRoom,
      roomId: 'preview-p204',
      roomName: 'P.204',
      propertyName: 'Khu trọ Hoa Sen',
      updatedAt: DateTime(2026, 8, 9),
    ),
    DashboardAttentionItem(
      kind: DashboardAttentionKind.dueSoonInvoice,
      roomId: 'preview-p105',
      roomName: 'P.105',
      tenantName: 'Trần Minh Anh',
      propertyName: 'Nhà trọ API',
      invoiceId: 'preview-i105',
      remainingAmount: 2800000,
      dueDate: DateTime(2026, 8, 15),
    ),
    DashboardAttentionItem(
      kind: DashboardAttentionKind.maintenanceRoom,
      roomId: 'preview-p401',
      roomName: 'P.401',
      propertyName: 'Khu trọ Bình Minh',
      updatedAt: DateTime(2026, 8, 8),
    ),
    DashboardAttentionItem(
      kind: DashboardAttentionKind.overdueInvoice,
      roomId: 'preview-p208',
      roomName: 'P.208',
      tenantName: 'Lê Hoàng Nam',
      propertyName: 'Khu trọ Hoa Sen',
      invoiceId: 'preview-i208',
      remainingAmount: 3200000,
      dueDate: DateTime(2026, 8, 5),
    ),
    DashboardAttentionItem(
      kind: DashboardAttentionKind.maintenanceRoom,
      roomId: 'preview-p503',
      roomName: 'P.503',
      propertyName: 'Nhà trọ Minh Khai',
      updatedAt: DateTime(2026, 8, 7),
    ),
  ];
}

class _FeaturedRoomCard extends StatelessWidget {
  const _FeaturedRoomCard({required this.item});
  final DashboardAttentionItem item;

  @override
  Widget build(BuildContext context) {
    final isOverdue = item.kind == DashboardAttentionKind.overdueInvoice;
    final isDueSoon = item.kind == DashboardAttentionKind.dueSoonInvoice;
    final accentColor = isOverdue
        ? const Color(0xFFDC2626)
        : isDueSoon
            ? const Color(0xFFD97706)
            : const Color(0xFF0D6E62);
    final badge = isOverdue
        ? 'Trễ hạn'
        : isDueSoon
            ? 'Sắp hạn'
            : 'Bảo trì';
    final badgeIcon = isOverdue
        ? Icons.warning_amber_rounded
        : isDueSoon
            ? Icons.event_available_outlined
            : Icons.handyman_outlined;
    final imageSource =
        RoomImageCatalog.defaultImageForKey('${item.roomId}:${item.roomName}');
    final roomLabel = _roomLabel(item.roomName);
    final propertyLabel = (item.propertyName ?? '').trim().isEmpty
        ? 'Chưa rõ khu trọ'
        : item.propertyName!.trim();
    final date = formatDate(item.dueDate ?? item.updatedAt);
    final tenantLabel = item.tenantName?.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 138,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RoomImageView(
                  source: imageSource,
                  placeholder: _AttentionRoomImagePlaceholder(
                    color: accentColor,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x22000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _AttentionBadge(
                    label: badge,
                    icon: badgeIcon,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          propertyLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 15, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (tenantLabel != null && tenantLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 15, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tenantLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isOverdue || isDueSoon) ...[
                    const Spacer(),
                    Text(
                      formatCurrencyVnd(item.remainingAmount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _roomLabel(String roomName) {
    final name = roomName.trim().isEmpty ? 'Phòng' : roomName.trim();
    return name.toLowerCase().startsWith('phòng') ? name : 'Phòng $name';
  }
}

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionRoomImagePlaceholder extends StatelessWidget {
  const _AttentionRoomImagePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

// ── Revenue Chart ─────────────────────────────────────────────────────────────

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({
    required this.points,
    required this.months,
    required this.onMonthsChanged,
  });

  final List<RevenuePoint> points;
  final int months;
  final ValueChanged<int> onMonthsChanged;

  @override
  Widget build(BuildContext context) {
    final data =
        points.map((point) => point.amount.toDouble()).toList(growable: false);
    final labels = points
        .map((point) => _formatChartMonth(point.month))
        .toList(growable: false);
    final maxValue = data.isEmpty ? 0.0 : data.reduce(math.max);
    final yMax = maxValue <= 0 ? 1.0 : maxValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'XU HƯỚNG DOANH THU',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
              PopupMenuButton<int>(
                onSelected: onMonthsChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 6, child: Text('6 tháng gần nhất')),
                  PopupMenuItem(value: 12, child: Text('12 tháng gần nhất')),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$months tháng',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _LineChart(
              data: data,
              labels: labels,
              maxLabel: _formatCompactAmount(yMax.round()),
              midLabel: _formatCompactAmount((yMax / 2).round()),
              lowLabel: _formatCompactAmount((yMax / 4).round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.data,
    required this.labels,
    required this.maxLabel,
    required this.midLabel,
    required this.lowLabel,
  });
  final List<double> data;
  final List<String> labels;
  final String maxLabel;
  final String midLabel;
  final String lowLabel;

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 1.0 : math.max(1.0, data.reduce(math.max));
    final labelIndexes = <int>{
      if (labels.isNotEmpty) 0,
      if (labels.length > 2) labels.length ~/ 2,
      if (labels.length > 1) labels.length - 1,
    }.toList()
      ..sort();

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _yLabel(maxLabel),
                    _yLabel(midLabel),
                    _yLabel(lowLabel),
                  ],
                ),
              ),
              Positioned.fill(
                right: 44,
                child: CustomPaint(
                  painter: _LinePainter(
                    data: data,
                    maxVal: maxVal,
                    lineColor: AppTheme.primary,
                    fillColor: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 44),
          child: labelIndexes.isEmpty
              ? const SizedBox(height: 12)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final index in labelIndexes)
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 9,
                          color: index == labels.length - 1
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                          fontWeight: index == labels.length - 1
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _yLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.data,
    required this.maxVal,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> data;
  final double maxVal;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= 3; i++) {
      final y = size.height * (1 - i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.isEmpty) return;

    final points = <Offset>[];
    final step = data.length <= 1 ? 0.0 : size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = data.length <= 1 ? size.width / 2 : i * step;
      final y = size.height - (data[i] / maxVal) * size.height;
      points.add(Offset(x, y.clamp(0.0, size.height).toDouble()));
    }

    final path = _buildSmoothPath(points);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            fillColor.withValues(alpha: 0.4),
            fillColor.withValues(alpha: 0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final last = points.last;
    canvas.drawCircle(last, 5, Paint()..color = lineColor);
    canvas.drawCircle(last, 3, Paint()..color = Colors.white);
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.data != data || old.lineColor != lineColor || old.maxVal != maxVal;
}

// ── Recent Invoices (Nearby Property list style) ──────────────────────────────

class _RecentInvoicesSection extends StatelessWidget {
  const _RecentInvoicesSection({required this.invoices});

  final List<DashboardRecentInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: invoices.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 32, color: Color(0xFFD1D5DB)),
                  SizedBox(width: 12),
                  Text(
                    'Chưa có hóa đơn nào.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            )
          : Column(
              children: List.generate(invoices.length, (i) {
                return _InvoiceListTile(
                  invoice: invoices[i],
                  isLast: i == invoices.length - 1,
                );
              }),
            ),
    );
  }
}

class _InvoiceListTile extends StatelessWidget {
  const _InvoiceListTile({required this.invoice, required this.isLast});
  final DashboardRecentInvoice invoice;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = invoice.status.color;
    final initial = invoice.roomName.trim().isEmpty
        ? 'H'
        : invoice.roomName.trim().characters.first;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        invoice.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phòng ${invoice.roomName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Tiền phòng ${formatMonth(invoice.billingMonth)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrencyVnd(invoice.totalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: Color(0xFFD1D5DB)),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 82,
            endIndent: 16,
            color: Color(0xFFF3F4F6),
          ),
      ],
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
                size: 56, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
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

class _WideSkeleton extends StatelessWidget {
  const _WideSkeleton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _WideSkeleton(height: 132)),
        SizedBox(width: 10),
        Expanded(child: _WideSkeleton(height: 132)),
        SizedBox(width: 10),
        Expanded(child: _WideSkeleton(height: 132)),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded,
              size: 64, color: AppTheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tính năng đang được phát triển',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

String _formatChartMonth(DateTime? date) {
  if (date == null) return '—';
  final year = (date.year % 100).toString().padLeft(2, '0');
  return 'T${date.month}/$year';
}

String _formatCompactAmount(int amount) {
  if (amount <= 0) return '0';
  if (amount >= 1000000000) return '${_trimDecimal(amount / 1000000000)}B';
  if (amount >= 1000000) return '${_trimDecimal(amount / 1000000)}M';
  if (amount >= 1000) return '${_trimDecimal(amount / 1000)}k';
  return '$amount';
}

String _trimDecimal(double value) {
  return value >= 10 || value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
