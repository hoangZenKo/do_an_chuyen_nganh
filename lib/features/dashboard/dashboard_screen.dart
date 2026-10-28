import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/liquid_bubble_navigation.dart';
import '../../models/billing.dart';
import '../../models/dashboard.dart';
import '../../models/auth_models.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../billing/billing_screen.dart';
import '../chatbot/widgets/chatbot_launcher.dart';
import '../rooms/room_providers.dart';
import '../rooms/rooms_list_screen.dart';
import '../rooms/widgets/room_image.dart';
import 'dashboard_providers.dart';
import 'room_map_dashboard.dart';

// ─── Design Palette ──────────────────────────────────────────────────────────
const Color _kHeaderNavy = Color(0xFF0B1220);
const Color _kScreenBg = Color(0xFFF3F5F8);
const Color _kCardBg = Color(0xFFFFFFFF);
const Color _kOrange = Color(0xFFFF6B1A);
const Color _kOrangeDeep = Color(0xFFE85A0C);
const Color _kTeal = Color(0xFF0D9488);
const Color _kGreen = Color(0xFF16A34A);
const Color _kAmber = Color(0xFFD97706);
const Color _kDanger = Color(0xFFDC2626);
const Color _kTextDark = Color(0xFF0F172A);
const Color _kTextMuted = Color(0xFF64748B);
const Color _kTextSoft = Color(0xFF98A2B3);
const Color _kBorderSubtle = Color(0xFFE6EAF0);
const Color _kSoftShadow = Color(0x1A0F172A);

// ─── Dashboard Screen ─────────────────────────────────────────────────────────

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
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index,
      {required bool canViewRooms,
      required bool canViewBilling,
      required bool canViewTenants}) {
    if (index == 1 && !canViewRooms) {
      context.push(settingsRoute);
      return;
    }
    if (index == 2 && !canViewBilling) {
      context.push(settingsRoute);
      return;
    }
    if (index == 3) {
      _showMoreMenu(context);
      return;
    }
    setState(() {
      _selectedTab = index;
      _animController.forward(from: 0);
    });
  }

  void _openChatbot() {
    final properties =
        ref.read(propertiesProvider).valueOrNull ?? const <Property>[];
    final selectedId = ref.read(selectedPropertyProvider);
    final property = properties.isEmpty
        ? null
        : properties.firstWhere(
            (property) => property.id == selectedId,
            orElse: () => properties.first,
          );
    ref.read(selectedPropertyProvider.notifier).state = property?.id;
    context.push(chatbotRoute);
  }

  void _showQuickAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: _kBorderSubtle),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 20),
              _QuickAddOptionTile(
                icon: Icons.meeting_room_rounded,
                iconColor: _kOrange,
                title: 'Add New Room',
                subtitle: 'Create and configure a rental room',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(roomFormPath());
                },
              ),
              const SizedBox(height: 12),
              _QuickAddOptionTile(
                icon: Icons.person_add_alt_1_rounded,
                iconColor: _kHeaderNavy,
                title: 'Add New Tenant',
                subtitle: 'Register a tenant and assign to room',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(tenantFormRoute);
                },
              ),
              const SizedBox(height: 12),
              _QuickAddOptionTile(
                icon: Icons.receipt_long_rounded,
                iconColor: _kTeal,
                title: 'Create Invoice / Bill',
                subtitle: 'Issue rent, electricity & water bill',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(billingFormRoute);
                },
              ),
              const SizedBox(height: 12),
              _QuickAddOptionTile(
                icon: Icons.handyman_rounded,
                iconColor: _kAmber,
                title: 'Record Maintenance',
                subtitle: 'Log room repair or service ticket',
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(maintenanceFormRoute);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Management Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (sessionHasPermission(
                      ref.read(sessionControllerProvider).session,
                      'operation.view'))
                    _MenuGridItem(
                      icon: Icons.task_alt_rounded,
                      label: 'Việc cần xử lý',
                      color: _kTeal,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.push(actionItemsRoute);
                      },
                    ),
                  if (ref.read(sessionControllerProvider).session?.user.role ==
                      'landlord')
                    _MenuGridItem(
                      icon: Icons.campaign_outlined,
                      label: 'Tin đăng',
                      color: _kTeal,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.push(landlordListingsRoute);
                      },
                    ),
                  if (ref.read(sessionControllerProvider).session?.user.role ==
                      'landlord')
                    _MenuGridItem(
                      icon: Icons.menu_book_rounded,
                      label: 'Trợ lý tài liệu',
                      color: _kTeal,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _openChatbot();
                      },
                    ),
                  _MenuGridItem(
                    icon: Icons.people_alt_rounded,
                    label: 'Tenants',
                    color: _kHeaderNavy,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(tenantsRoute);
                    },
                  ),
                  _MenuGridItem(
                    icon: Icons.pie_chart_rounded,
                    label: 'Reports',
                    color: _kTeal,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(reportsRoute);
                    },
                  ),
                  _MenuGridItem(
                    icon: Icons.handyman_rounded,
                    label: 'Maintenance',
                    color: _kAmber,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(maintenanceRoute);
                    },
                  ),
                  _MenuGridItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Expenses',
                    color: _kOrange,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(expensesRoute);
                    },
                  ),
                  _MenuGridItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    color: _kOrangeDeep,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(notificationsRoute);
                    },
                  ),
                  _MenuGridItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    color: _kTextMuted,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push(settingsRoute);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    final canViewTenants = sessionHasAnyPermission(
        session, const ['tenant.view', 'tenant.manage']);
    final canViewBilling = sessionHasAnyPermission(
        session, const ['billing.view', 'billing.create']);

    return Scaffold(
      backgroundColor: _kScreenBg,
      extendBody: true,
      body: LiquidTaskbarScrollScope(
        additionalClearance: session?.user.role == 'landlord' ? 72 : 0,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: switch (_selectedTab) {
            0 => _OverviewTab(
                onNavigateTab: (tab) => setState(() => _selectedTab = tab),
              ),
            1 =>
              canViewRooms ? const RoomsListScreen() : const SizedBox.shrink(),
            2 =>
              canViewBilling ? const BillingScreen() : const SizedBox.shrink(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      floatingActionButton: session?.user.role == 'landlord'
          ? ChatbotLauncher(onPressed: _openChatbot)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: _BottomNavBar(
            selectedTab: _selectedTab,
            onTabSelected: (tab) => _onTabTapped(
              tab,
              canViewRooms: canViewRooms,
              canViewBilling: canViewBilling,
              canViewTenants: canViewTenants,
            ),
            onFabPressed: () => _showQuickAddSheet(context),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Navigation Bar with Floating Center Action ────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedTab,
    required this.onTabSelected,
    required this.onFabPressed,
  });

  final int selectedTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onFabPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidBubbleNavigation(
        height: 72,
        borderRadius: BorderRadius.circular(30),
        centerGap: 58,
        selectedIndex: selectedTab,
        bubbleColor: Colors.white,
        activeColor: _kOrange,
        inactiveColor: const Color(0xFF94A3B8),
        items: const [
          LiquidNavigationItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Tổng quan',
          ),
          LiquidNavigationItem(
            icon: Icons.bed_outlined,
            selectedIcon: Icons.bed_rounded,
            label: 'Phòng',
          ),
          LiquidNavigationItem(
            icon: Icons.description_outlined,
            selectedIcon: Icons.description_rounded,
            label: 'Hóa đơn',
          ),
          LiquidNavigationItem(
            icon: Icons.menu_rounded,
            selectedIcon: Icons.menu_rounded,
            label: 'Thêm',
            isAction: true,
          ),
        ],
        onSelected: onTabSelected,
        centerAction: Semantics(
          button: true,
          label: 'Thêm mới',
          child: GestureDetector(
            onTap: onFabPressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _kHeaderNavy,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kHeaderNavy.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Overview Tab (Redesigned Mockup) ─────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab({required this.onNavigateTab});
  final ValueChanged<int> onNavigateTab;

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  bool _showMap = false;
  final GlobalKey _statisticsKey = GlobalKey();
  final TextEditingController _roomSearchController = TextEditingController();

  @override
  void dispose() {
    _roomSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final propertiesAsync = ref.watch(propertiesProvider);
    final selectedId = ref.watch(selectedPropertyProvider);
    final properties = propertiesAsync.valueOrNull ?? const <Property>[];
    final property = _selectedProperty(properties, selectedId);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final roomsAsync = property == null
        ? const AsyncValue<List<Room>>.data(<Room>[])
        : ref.watch(roomsProvider(property.id));

    final statistics = _StatisticsPanel(
      session: session,
      property: property,
      metricsAsync: metricsAsync,
      roomsAsync: roomsAsync,
      onNavigateTab: widget.onNavigateTab,
    );

    if (_showMap) {
      return RoomMapDashboard(
        onNavigateTab: widget.onNavigateTab,
        onShowStatistics: () => setState(() => _showMap = false),
      );
    }

    return CustomScrollView(
      key: PageStorageKey(
          'dashboard-overview:${session?.user.id}:${property?.id}'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _kHeaderNavy,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            property?.name ?? 'Khu trọ của bạn',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => setState(() => _showMap = true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                      label: const Text('Sơ đồ 3D'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _roomSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm phòng hoặc người thuê',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _roomSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _roomSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _YourRoomsSection(
              roomsAsync: roomsAsync,
              searchQuery: _roomSearchController.text,
              onViewAll: () => widget.onNavigateTab(1),
            ),
          ),
        ),
        ...statistics.buildSlivers(context, _statisticsKey),
        SliverToBoxAdapter(
          child: SizedBox(
            key: const ValueKey('dashboard-bottom-clearance'),
            height: 180,
          ),
        ),
      ],
    );
  }

  Property? _selectedProperty(List<Property> properties, String? selectedId) {
    if (properties.isEmpty) return null;
    return properties.firstWhere(
      (property) => property.id == selectedId,
      orElse: () => properties.first,
    );
  }
}

class _StatisticsPanel {
  const _StatisticsPanel({
    required this.session,
    required this.property,
    required this.metricsAsync,
    required this.roomsAsync,
    required this.onNavigateTab,
  });

  final AuthSession? session;
  final Property? property;
  final AsyncValue<DashboardMetrics> metricsAsync;
  final AsyncValue<List<Room>> roomsAsync;
  final ValueChanged<int> onNavigateTab;

  List<Widget> buildSlivers(BuildContext context, Key statisticsKey) {
    final metrics = metricsAsync.valueOrNull;
    final roomCount =
        metrics?.roomStats.total ?? roomsAsync.valueOrNull?.length ?? 0;
    final occupiedCount = metrics?.roomStats.occupied ??
        roomsAsync.valueOrNull
            ?.where((room) => room.status == RoomStatus.occupied)
            .length ??
        0;
    final vacantCount = metrics?.roomStats.vacant ??
        roomsAsync.valueOrNull
            ?.where((room) => room.status == RoomStatus.vacant)
            .length ??
        0;
    final maintenanceCount = metrics?.roomStats.maintenance ??
        roomsAsync.valueOrNull
            ?.where((room) => room.status == RoomStatus.maintenance)
            .length ??
        0;
    final attention =
        metrics?.attentionItems ?? const <DashboardAttentionItem>[];
    final invoiceCount = metrics?.recentInvoices.length ?? 0;
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: KeyedSubtree(
          key: statisticsKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(
                child: Text('Thống kê khu trọ',
                    style: TextStyle(
                        color: _kTextDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
              if (attention.isNotEmpty)
                Text('${attention.length} cần chú ý',
                    style: const TextStyle(
                        color: _kOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _InlineStatisticsCard(
            total: roomCount,
            occupied: occupiedCount,
            vacant: vacantCount,
            maintenance: maintenanceCount,
            received: metrics?.currentMonth.receivedAmount ?? 0,
            outstanding: metrics?.currentMonth.outstandingAmount ?? 0,
            attentionCount: attention.length,
            invoiceCount: invoiceCount,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onNavigateTab(1),
                icon: const Icon(Icons.bed_outlined),
                label: const Text('Phòng'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onNavigateTab(2),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Hóa đơn'),
              ),
            ),
          ]),
        ),
      ),
    ];
    if (metrics != null && metrics.revenueTrend.isNotEmpty) {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _RevenueTrendCard(
            points: metrics.revenueTrend,
            onViewReports: () => context.push(reportsRoute),
          ),
        ),
      ));
    }
    if (metrics != null) {
      slivers.addAll([
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _AttentionItemsSection(items: metrics.attentionItems),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _RecentInvoicesCard(
              invoices: metrics.recentInvoices,
              onViewAll: () => onNavigateTab(2),
            ),
          ),
        ),
      ]);
    }
    return slivers;
  }
}

class _InlineStatisticsCard extends StatelessWidget {
  const _InlineStatisticsCard({
    required this.total,
    required this.occupied,
    required this.vacant,
    required this.maintenance,
    required this.received,
    required this.outstanding,
    required this.attentionCount,
    required this.invoiceCount,
  });

  final int total;
  final int occupied;
  final int vacant;
  final int maintenance;
  final int received;
  final int outstanding;
  final int attentionCount;
  final int invoiceCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Tổng phòng', '$total', _kOrange, Icons.meeting_room_outlined),
      ('Đang thuê', '$occupied', _kTeal, Icons.people_alt_outlined),
      ('Phòng trống', '$vacant', _kAmber, Icons.bed_outlined),
      ('Bảo trì', '$maintenance', _kDanger, Icons.handyman_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorderSubtle),
        boxShadow: const [
          BoxShadow(color: _kSoftShadow, blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: 128,
                child: _InlineMetric(
                  label: metric.$1,
                  value: metric.$2,
                  color: metric.$3,
                  icon: metric.$4,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: _kBorderSubtle),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _InlineMoney(
                label: 'Đã thu',
                value: formatCurrencyVnd(received),
                color: _kGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InlineMoney(
                label: 'Chưa thu',
                value: formatCurrencyVnd(outstanding),
                color: _kOrange),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          attentionCount == 0
              ? 'Không có phòng hoặc hóa đơn cần chú ý.'
              : '$attentionCount mục cần chú ý · $invoiceCount hóa đơn gần đây',
          style: const TextStyle(color: _kTextMuted, fontSize: 12),
        ),
        if (invoiceCount == 0)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Chưa có hóa đơn nào.',
                style: TextStyle(color: _kTextMuted, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _kTextDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _kTextMuted, fontSize: 11)),
          ]),
        ),
      ]);
}

class _InlineMoney extends StatelessWidget {
  const _InlineMoney(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      color: _kTextDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800))),
        ]),
      );
}

// ─── 1. Top Dark Navy Header ──────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({
    required this.onRoomsTap,
    required this.onTenantsTap,
    required this.onBillsTap,
  });

  final VoidCallback onRoomsTap;
  final VoidCallback onTenantsTap;
  final VoidCallback onBillsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                label: 'Rooms',
                icon: Icons.bed_rounded,
                iconColor: _kOrange,
                onTap: onRoomsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                label: 'Tenants',
                icon: Icons.people_alt_rounded,
                iconColor: _kHeaderNavy,
                onTap: onTenantsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                label: 'Bills',
                icon: Icons.description_rounded,
                iconColor: _kTeal,
                onTap: onBillsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorderSubtle),
          boxShadow: const [
            BoxShadow(
              color: _kSoftShadow,
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. Your Rooms Section ────────────────────────────────────────────────────

class _YourRoomsSection extends StatefulWidget {
  const _YourRoomsSection({
    required this.roomsAsync,
    required this.searchQuery,
    required this.onViewAll,
  });

  final AsyncValue<List<Room>> roomsAsync;
  final String searchQuery;
  final VoidCallback onViewAll;

  @override
  State<_YourRoomsSection> createState() => _YourRoomsSectionState();
}

class _YourRoomsSectionState extends State<_YourRoomsSection> {
  late final PageController _pageController;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.62);
    _pageController.addListener(_syncPage);
  }

  @override
  void dispose() {
    _pageController.removeListener(_syncPage);
    _pageController.dispose();
    super.dispose();
  }

  void _syncPage() {
    if (!_pageController.hasClients) return;
    final nextPage =
        _pageController.page ?? _pageController.initialPage.toDouble();
    if ((_page - nextPage).abs() < 0.001) return;
    setState(() => _page = nextPage);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your rooms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
              ),
            ),
            GestureDetector(
              onTap: widget.onViewAll,
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Horizontal List
        widget.roomsAsync.when(
          loading: () => const SizedBox(
            height: 236,
            child: Center(
              child: CircularProgressIndicator(color: _kOrange),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: Text('Unable to load rooms: $err',
                style: const TextStyle(color: _kDanger)),
          ),
          data: (rooms) {
            final query = widget.searchQuery.toLowerCase();
            final filtered = query.isEmpty
                ? rooms
                : rooms
                    .where(
                      (r) =>
                          r.name.toLowerCase().contains(query) ||
                          (r.tenantName?.toLowerCase().contains(query) ??
                              false),
                    )
                    .toList();

            if (filtered.isEmpty) {
              return Container(
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _kBorderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.meeting_room_outlined,
                          color: _kTextMuted, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        widget.searchQuery.isEmpty
                            ? 'No rooms yet in this property.'
                            : 'No rooms match "${widget.searchQuery}"',
                        style:
                            const TextStyle(color: _kTextMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 254,
              child: PageView.builder(
                controller: _pageController,
                clipBehavior: Clip.none,
                padEnds: false,
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final room = filtered[index];
                  final distance = (_page - index).abs().clamp(0.0, 1.0);
                  final scale = 1 - distance * 0.08;
                  final opacity = 1 - distance * 0.18;
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18, bottom: 12),
                      child: _RoomCard(
                        room: room,
                        onTap: () => context.push(roomDetailPath(room.id)),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = RoomImageCatalog.imageFor(room);
    final isOccupied = room.status == RoomStatus.occupied;
    final isMaintenance = room.status == RoomStatus.maintenance;

    final badgeText =
        isOccupied ? 'Occupied' : (isMaintenance ? 'Maintenance' : 'Vacant');

    final badgeBg = isOccupied
        ? _kGreen.withValues(alpha: 0.10)
        : (isMaintenance
            ? _kAmber.withValues(alpha: 0.10)
            : const Color(0xFFF1F5F9));

    final badgeFg =
        isOccupied ? _kGreen : (isMaintenance ? _kAmber : _kTextMuted);

    final tenantLabel = isOccupied
        ? (room.tenantName != null && room.tenantName!.isNotEmpty
            ? room.tenantName!
            : '${room.capacity ?? 2} tenants')
        : '0 tenants';

    final formattedPrice = formatCurrencyVnd(room.basePrice);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 216,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorderSubtle),
          boxShadow: const [
            BoxShadow(
              color: _kSoftShadow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Image with Status Badge ──────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SizedBox(
                    height: 124,
                    width: double.infinity,
                    child: RoomImageView(
                      source: imagePath,
                      placeholder: Container(
                        color: const Color(0xFFCBD5E1),
                        child: const Center(
                          child: Icon(Icons.meeting_room_rounded,
                              color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                  ),
                ),

                // Status Badge floating on bottom-left of photo
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeFg,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Card Info ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room ${room.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tenantLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: formattedPrice,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kTextDark,
                          ),
                        ),
                        const TextSpan(
                          text: ' / month',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
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

// ─── 3b. Compact Pill Matrix + Inline Dock (Kiểu C) ──────────────────────────

enum _MatrixRoomState {
  paid,
  dueSoon,
  overdue,
  maintenance,
  vacant;

  String get label => switch (this) {
        _MatrixRoomState.paid => 'Đã thu',
        _MatrixRoomState.dueSoon => 'Chờ thu',
        _MatrixRoomState.overdue => 'Quá hạn',
        _MatrixRoomState.maintenance => 'Sửa chữa',
        _MatrixRoomState.vacant => 'Trống',
      };

  String get detail => switch (this) {
        _MatrixRoomState.paid => 'Đang thuê ổn định',
        _MatrixRoomState.dueSoon => 'Hóa đơn sắp đến hạn thanh toán',
        _MatrixRoomState.overdue => 'Hóa đơn quá hạn thanh toán',
        _MatrixRoomState.maintenance => 'Đang có yêu cầu bảo trì / sửa chữa',
        _MatrixRoomState.vacant => 'Phòng đang trống · sẵn sàng đón khách',
      };

  Color get bg => switch (this) {
        _MatrixRoomState.paid => const Color(0xFFDCFCE7),
        _MatrixRoomState.dueSoon => const Color(0xFFFEF3C7),
        _MatrixRoomState.overdue => const Color(0xFFDC2626),
        _MatrixRoomState.maintenance => const Color(0xFFFFEDD5),
        _MatrixRoomState.vacant => const Color(0xFFF8FAFC),
      };

  Color get fg => switch (this) {
        _MatrixRoomState.paid => const Color(0xFF15803D),
        _MatrixRoomState.dueSoon => const Color(0xFFB45309),
        _MatrixRoomState.overdue => Colors.white,
        _MatrixRoomState.maintenance => const Color(0xFFC2410C),
        _MatrixRoomState.vacant => const Color(0xFF64748B),
      };

  Color get border => switch (this) {
        _MatrixRoomState.paid => Colors.transparent,
        _MatrixRoomState.dueSoon => const Color(0xFFFCD34D),
        _MatrixRoomState.overdue => const Color(0xFFDC2626),
        _MatrixRoomState.maintenance => const Color(0xFFFDBA74),
        _MatrixRoomState.vacant => const Color(0xFFCBD5E1),
      };

  Color get dockBadgeBg => switch (this) {
        _MatrixRoomState.overdue => const Color(0xFFFEE2E2),
        _ => bg,
      };

  Color get dockBadgeFg => switch (this) {
        _MatrixRoomState.overdue => const Color(0xFFB91C1C),
        _ => fg,
      };
}

class _RoomPillMatrixSection extends StatefulWidget {
  const _RoomPillMatrixSection({
    required this.roomsAsync,
    required this.metricsAsync,
    required this.onViewAllRooms,
  });

  final AsyncValue<List<Room>> roomsAsync;
  final AsyncValue<DashboardMetrics> metricsAsync;
  final VoidCallback onViewAllRooms;

  @override
  State<_RoomPillMatrixSection> createState() => _RoomPillMatrixSectionState();
}

class _RoomPillMatrixSectionState extends State<_RoomPillMatrixSection> {
  String? _selectedRoomId;

  int _inferFloor(Room room, int index) {
    if (room.floor != null && room.floor! > 0) return room.floor!;
    final raw = room.name.trim();
    // 1. Check 3-4 digit room numbers like 101, 204, 308 -> floor 1, 2, 3
    final threeDigit = RegExp(r'(\d{3,4})').firstMatch(raw);
    if (threeDigit != null) {
      final numVal = int.tryParse(threeDigit.group(1)!);
      if (numVal != null && numVal >= 100) {
        return numVal ~/ 100;
      }
    }
    // 2. Check prefix letter like A01, B12, C03 -> A=1, B=2, C=3
    final letterMatch = RegExp(r'^([A-Za-z])\s*\d+').firstMatch(raw);
    if (letterMatch != null) {
      final code = letterMatch.group(1)!.toUpperCase().codeUnitAt(0);
      final mapped = code - 'A'.codeUnitAt(0) + 1;
      if (mapped >= 1 && mapped <= 9) return mapped;
    }
    // 3. Fallback: group rooms evenly (up to 8 rooms per floor row)
    return (index ~/ 8) + 1;
  }

  String _compactRoomLabel(String name) {
    final cleaned = name
        .replaceFirst(
          RegExp(r'^(?:Phòng|Phong|Room|P\.?)\s*', caseSensitive: false),
          '',
        )
        .trim();
    return cleaned.isEmpty ? name.trim() : cleaned;
  }

  _MatrixRoomState _stateFor(
    Room room,
    Map<String, DashboardAttentionItem> attentionByRoom,
  ) {
    final att = attentionByRoom[room.id] ?? attentionByRoom[room.name];
    if (room.status == RoomStatus.maintenance ||
        att?.kind == DashboardAttentionKind.maintenanceRoom) {
      return _MatrixRoomState.maintenance;
    }
    if (att?.kind == DashboardAttentionKind.overdueInvoice) {
      return _MatrixRoomState.overdue;
    }
    if (att?.kind == DashboardAttentionKind.dueSoonInvoice) {
      return _MatrixRoomState.dueSoon;
    }
    if (room.status == RoomStatus.vacant) {
      return _MatrixRoomState.vacant;
    }
    return _MatrixRoomState.paid;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.roomsAsync.valueOrNull ?? const <Room>[];
    if (rooms.isEmpty) return const SizedBox.shrink();

    final attentionList =
        widget.metricsAsync.valueOrNull?.attentionItems ?? const [];
    final attentionByRoom = <String, DashboardAttentionItem>{
      for (final item in attentionList) ...{
        if (item.roomId.isNotEmpty) item.roomId: item,
        if (item.roomName.isNotEmpty) item.roomName: item,
      },
    };

    final grouped = <int, List<Room>>{};
    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      grouped.putIfAbsent(_inferFloor(room, i), () => <Room>[]).add(room);
    }
    // If every floor ended up with only 1 room while there are multiple rooms,
    // pack them horizontally into floor rows of up to 8 rooms so the matrix
    // always stretches across horizontally instead of stacking 1 pill per row.
    if (rooms.length > 1 &&
        grouped.values.every((floorRooms) => floorRooms.length <= 1)) {
      grouped.clear();
      for (var i = 0; i < rooms.length; i++) {
        final floorRow = (i ~/ 8) + 1;
        grouped.putIfAbsent(floorRow, () => <Room>[]).add(rooms[i]);
      }
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    final floors = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final selectedRoom = rooms.firstWhere(
      (r) => r.id == _selectedRoomId,
      orElse: () => rooms.first,
    );
    final selectedState = _stateFor(selectedRoom, attentionByRoom);
    final selectedAttention =
        attentionByRoom[selectedRoom.id] ?? attentionByRoom[selectedRoom.name];
    final occupiedCount =
        rooms.where((r) => r.status == RoomStatus.occupied).length;
    final vacantCount =
        rooms.where((r) => r.status == RoomStatus.vacant).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sơ đồ phòng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
              ),
            ),
            GestureDetector(
              onTap: widget.onViewAllRooms,
              child: const Text(
                'Danh sách',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorderSubtle),
            boxShadow: const [
              BoxShadow(
                color: _kSoftShadow,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chạm nhanh vào số phòng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '$occupiedCount đang ở · $vacantCount trống',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final floor in floors) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tầng $floor',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kTextMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final floorRooms = grouped[floor]!;
                            const maxCols = 8;
                            const gap = 5.0;
                            final rows = <List<Room>>[];
                            for (var i = 0;
                                i < floorRooms.length;
                                i += maxCols) {
                              final end = (i + maxCols < floorRooms.length)
                                  ? i + maxCols
                                  : floorRooms.length;
                              rows.add(floorRooms.sublist(i, end));
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var r = 0; r < rows.length; r++) ...[
                                  if (r > 0) const SizedBox(height: gap),
                                  Row(
                                    children: [
                                      for (var c = 0;
                                          c < rows[r].length;
                                          c++) ...[
                                        if (c > 0) const SizedBox(width: gap),
                                        Expanded(
                                          child: _MatrixPillButton(
                                            room: rows[r][c],
                                            displayLabel: _compactRoomLabel(
                                                rows[r][c].name),
                                            state: _stateFor(
                                                rows[r][c], attentionByRoom),
                                            isSelected: rows[r][c].id ==
                                                selectedRoom.id,
                                            onTap: () => setState(() =>
                                                _selectedRoomId =
                                                    rows[r][c].id),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // ── Inline Quick-Inspect Dock ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selectedState.dockBadgeBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selectedRoom.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: selectedState.dockBadgeFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  selectedRoom.tenantName?.isNotEmpty == true
                                      ? selectedRoom.tenantName!
                                      : 'Phòng đang trống',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _kTextDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: selectedState.dockBadgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  selectedState.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedState.dockBadgeFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatCurrencyVnd(selectedRoom.basePrice)}/tháng · ${selectedState.detail}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (selectedState == _MatrixRoomState.overdue &&
                            selectedAttention?.invoiceId != null) {
                          context.push(
                              billingDetailPath(selectedAttention!.invoiceId!));
                          return;
                        }
                        if (selectedState == _MatrixRoomState.maintenance) {
                          context.push(maintenanceRoute);
                          return;
                        }
                        context.push(roomDetailPath(selectedRoom.id));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: _kHeaderNavy,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Text(
                          'Xử lý',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
      ],
    );
  }
}

class _MatrixPillButton extends StatelessWidget {
  const _MatrixPillButton({
    required this.room,
    required this.displayLabel,
    required this.state,
    required this.isSelected,
    required this.onTap,
  });

  final Room room;
  final String displayLabel;
  final _MatrixRoomState state;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _kTextDark : state.border,
            width: isSelected ? 2.2 : 1.4,
          ),
          boxShadow: state == _MatrixRoomState.overdue
              ? [
                  BoxShadow(
                    color: _kDanger.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayLabel,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: state.fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 4. This Month Overview Section ───────────────────────────────────────────

class _MonthOverviewSection extends StatelessWidget {
  const _MonthOverviewSection({required this.metricsAsync});
  final AsyncValue<DashboardMetrics> metricsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This month overview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorderSubtle),
            boxShadow: const [
              BoxShadow(
                color: _kSoftShadow,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: metricsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: _kOrange),
              ),
            ),
            error: (err, _) => Text(
              'Overview data: $err',
              style: const TextStyle(color: _kDanger, fontSize: 13),
            ),
            data: (metrics) {
              final occupiedCount = metrics.roomStats.occupied;
              final totalRooms = metrics.roomStats.total;
              final vacantRooms = metrics.roomStats.vacant;
              final collected =
                  formatCurrencyVnd(metrics.currentMonth.receivedAmount);
              final outstanding =
                  formatCurrencyVnd(metrics.currentMonth.outstandingAmount);

              return Column(
                children: [
                  Row(
                    children: [
                      // 1. Total Rooms (32)
                      Expanded(
                        child: _StatMetricColumn(
                          icon: Icons.meeting_room_rounded,
                          iconColor: _kOrange,
                          value: '$totalRooms',
                          label: 'Tổng phòng',
                          subLabel: 'Total',
                        ),
                      ),
                      Container(width: 1, height: 48, color: _kBorderSubtle),

                      // 2. Occupied (26)
                      Expanded(
                        child: _StatMetricColumn(
                          icon: Icons.people_alt_rounded,
                          iconColor: _kTeal,
                          value: '$occupiedCount',
                          label: 'Đang thuê',
                          subLabel: 'Occupied',
                        ),
                      ),
                      Container(width: 1, height: 48, color: _kBorderSubtle),

                      // 3. Vacant (6)
                      Expanded(
                        child: _StatMetricColumn(
                          icon: Icons.bed_rounded,
                          iconColor: _kAmber,
                          value: '$vacantRooms',
                          label: 'Phòng trống',
                          subLabel: 'Vacant',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: _kBorderSubtle, height: 1),
                  const SizedBox(height: 16),

                  // Financial summary row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.paid_rounded,
                                      size: 16, color: _kGreen),
                                  SizedBox(width: 5),
                                  Text('Đã thu',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _kGreen)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  collected,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _kTextDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kOrange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.receipt_long_rounded,
                                      size: 16, color: _kOrange),
                                  SizedBox(width: 5),
                                  Text('Chưa thu',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _kOrange)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  outstanding,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _kTextDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatMetricColumn extends StatelessWidget {
  const _StatMetricColumn({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.subLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String subLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kTextDark,
          ),
        ),
        Text(
          subLabel,
          style: const TextStyle(
            fontSize: 11,
            color: _kTextMuted,
          ),
        ),
      ],
    );
  }
}

// ─── 4b. Revenue Trend Card ───────────────────────────────────────────────────

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({
    required this.points,
    required this.onViewReports,
  });

  final List<RevenuePoint> points;
  final VoidCallback onViewReports;

  String _shortAmount(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m.toStringAsFixed(1).replaceAll('.', ',')}tr';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).round()}k';
    }
    return '$amount';
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        points.length > 6 ? points.sublist(points.length - 6) : points;
    final totalSixMonths = visible.fold<int>(0, (sum, p) => sum + p.amount);
    final maxAmount = visible.fold<int>(
      1,
      (curr, p) => p.amount > curr ? p.amount : curr,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Doanh thu 6 tháng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onViewReports,
              child: const Text(
                'Báo cáo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kBorderSubtle),
            boxShadow: const [
              BoxShadow(
                color: _kSoftShadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _shortAmount(totalSixMonths),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'tổng thu theo kỳ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Builder(
                            builder: (context) {
                              final pt = visible[i];
                              final isLast = i == visible.length - 1;
                              final ratio =
                                  (pt.amount / maxAmount).clamp(0.08, 1.0);
                              final barHeight = 68 * ratio;
                              final monthLabel = pt.month != null
                                  ? 'T${pt.month!.month}'
                                  : 'K${i + 1}';
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isLast && pt.amount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _shortAmount(pt.amount),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _kTextDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: isLast
                                          ? _kOrange
                                          : const Color(0xFFDCE3EE),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    monthLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isLast
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isLast ? _kTextDark : _kTextSoft,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 5. Attention Items Section ───────────────────────────────────────────────

class _AttentionItemsSection extends ConsumerWidget {
  const _AttentionItemsSection({required this.items});
  final List<DashboardAttentionItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final canViewBilling = sessionHasPermission(session, 'billing.view');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canViewBilling &&
            items.any(
                (item) => item.kind == DashboardAttentionKind.overdueInvoice))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => context.push('$billingRoute?filter=overdue'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Xem hóa đơn trễ hạn'),
            ),
          ),
        const Text(
          'Phòng cần chú ý',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: const Center(
              child: Text(
                'Không có phòng hoặc hóa đơn cần chú ý.',
                style: TextStyle(color: _kTextMuted, fontSize: 13),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorderSubtle),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: items.take(3).map((item) {
                final isMaintenance =
                    item.kind == DashboardAttentionKind.maintenanceRoom;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  onTap: () {
                    if (isMaintenance) {
                      context.push(maintenanceRoute);
                      return;
                    }
                    if (item.invoiceId != null && item.invoiceId!.isNotEmpty) {
                      context.push(billingDetailPath(item.invoiceId!));
                      return;
                    }
                    if (item.roomId.isNotEmpty) {
                      context.push(roomDetailPath(item.roomId));
                    }
                  },
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isMaintenance ? _kAmber : _kOrange)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMaintenance
                          ? Icons.handyman_rounded
                          : Icons.priority_high_rounded,
                      color: isMaintenance ? _kAmber : _kOrange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.tenantName ?? 'Phòng ${item.roomName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _kTextDark,
                    ),
                  ),
                  subtitle: Text(
                    isMaintenance
                        ? 'Cần bảo trì phòng'
                        : 'Hóa đơn quá hạn / chưa thanh toán',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  trailing: item.remainingAmount > 0
                      ? Text(
                          formatCurrencyVnd(item.remainingAmount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _kOrange),
                        )
                      : const Icon(Icons.chevron_right_rounded,
                          color: _kTextMuted),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── 6. Recent Invoices Card ──────────────────────────────────────────────────

class _RecentInvoicesCard extends StatelessWidget {
  const _RecentInvoicesCard({required this.invoices, required this.onViewAll});
  final List<DashboardRecentInvoice> invoices;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Hóa đơn gần đây',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kTextDark,
                ),
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: const Text(
                'Tất cả',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (invoices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorderSubtle),
            ),
            child: const Center(
              child: Text(
                'Chưa có hóa đơn nào.',
                style: TextStyle(color: _kTextMuted, fontSize: 13),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kBorderSubtle),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: invoices.take(4).map((inv) {
                final isPaid = inv.status == InvoiceStatus.paid;
                final tenantDisplayName = inv.tenantName ?? 'Khách thuê';
                final periodStr = formatMonth(inv.billingMonth);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (isPaid ? _kGreen : _kOrange).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_rounded,
                      color: isPaid ? _kGreen : _kOrange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    tenantDisplayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _kTextDark,
                    ),
                  ),
                  subtitle: Text(
                    'Phòng ${inv.roomName} · $periodStr',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrencyVnd(inv.totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _kTextDark),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isPaid ? 'Đã thu' : 'Chưa thu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPaid
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => context.push(billingDetailPath(inv.id)),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _QuickAddOptionTile extends StatelessWidget {
  const _QuickAddOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _kBorderSubtle),
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _kTextDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: _kTextMuted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _kTextMuted),
    );
  }
}

class _MenuGridItem extends StatelessWidget {
  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 72) / 3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
