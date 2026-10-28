import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/auth_models.dart';
import '../../models/notification_delivery.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../notifications/notifications_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final user = session?.user;
    final role = user?.role ?? 'landlord';
    final permissions = user?.permissions.toSet() ?? const <String>{};
    final isAdmin = role == 'admin';
    final isLandlord = role == 'landlord';
    final isStaff = role == 'staff';
    final isTenant = role == 'tenant';
    final canViewProperties = isLandlord ||
        sessionHasAnyPermission(session, const [
          'property.view',
          'property.manage',
          'room.view',
          'room.manage',
        ]);
    final canViewStaff = isLandlord ||
        sessionHasAnyPermission(session, const ['staff.view', 'staff.manage']);
    final canManageStaff = isLandlord || permissions.contains('staff.manage');
    final canViewAudit = isLandlord || permissions.contains('audit.view');
    final canViewNotifications =
        isLandlord || permissions.contains('notification.view');
    final canViewBilling = isLandlord ||
        sessionHasAnyPermission(session, const [
          'billing.view',
          'billing.create',
        ]);
    final canCreateBilling = isLandlord || permissions.contains('billing.create');
    final canViewReports = isLandlord || permissions.contains('report.view');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _ProfileHeader(
            name: user?.fullName ?? 'Người dùng',
            email: user?.email ?? 'Chưa có email',
            phone: user?.phone,
            roleLabel: _roleLabel(role),
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'Tài khoản',
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Thông tin cá nhân',
                subtitle: user?.phone?.isNotEmpty == true
                    ? user!.phone!
                    : 'Họ tên, email và số điện thoại',
                trailingText: 'Xem',
                onTap: () => _showProfileSheet(context, user),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Đổi mật khẩu',
                subtitle: 'Cập nhật mật khẩu đăng nhập',
                onTap: () => context.push(settingsPasswordRoute),
              ),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Đăng xuất',
                subtitle: 'Thoát khỏi phiên đăng nhập hiện tại',
                destructive: true,
                onTap: () =>
                    ref.read(sessionControllerProvider.notifier).logout(),
              ),
            ],
          ),
          if (!isTenant) ...[
            const SizedBox(height: 20),
            if (isAdmin ||
                canViewProperties ||
                canViewStaff ||
                canViewAudit)
              _SettingsSection(
                title: isAdmin ? 'Quản trị nền tảng' : 'Quản lý',
                children: [
                  if (isAdmin) ...[
                    _SettingsTile(
                      icon: Icons.apartment_rounded,
                      title: 'Chủ trọ',
                      subtitle: 'Tạo và quản lý tài khoản landlord',
                      onTap: () => context.push(adminLandlordsRoute),
                    ),
                    _SettingsTile(
                      icon: Icons.maps_home_work_outlined,
                      title: 'Khu trọ',
                      subtitle: 'Theo dõi khu trọ trên toàn hệ thống',
                      onTap: () => context.push(adminPropertiesRoute),
                    ),
                  ] else ...[
                    if (canViewProperties)
                      _SettingsTile(
                        icon: Icons.maps_home_work_outlined,
                        title: 'Nhà trọ của tôi',
                        subtitle: 'Khu trọ, phòng và cấu hình vận hành',
                        onTap: () => context.push(propertiesRoute),
                      ),
                    if (canViewStaff)
                      _SettingsTile(
                        icon: Icons.badge_outlined,
                        title: 'Nhân viên & phân quyền',
                        subtitle: canManageStaff
                            ? 'Mời nhân viên, preset quyền và trạng thái'
                            : 'Xem nhân sự theo quyền được cấp',
                        onTap: () => context.push(staffRoute),
                      ),
                    if (canViewAudit)
                      _SettingsTile(
                        icon: Icons.history_rounded,
                        title: 'Audit log',
                        subtitle: 'Lịch sử thao tác nhạy cảm',
                        onTap: () => context.push(auditRoute),
                      ),
                    if (isStaff &&
                        !canManageStaff &&
                        !canViewAudit &&
                        !canViewProperties)
                      const _SettingsTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Quyền nhân viên',
                        subtitle:
                            'Tài khoản này chỉ thấy các mục được cấp quyền',
                        trailingText: 'Đang áp dụng',
                      ),
                  ],
                ],
              ),
          ],
          if (!isAdmin && !isTenant && canViewNotifications) ...[
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Thông báo',
              children: [
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Thông báo trong app',
                  subtitle: 'Hóa đơn, bảo trì và việc cần xử lý',
                  onTap: () => context.push(notificationsRoute),
                ),
                _SettingsTile(
                  imageAsset: 'assets/images/zalo_logo.png',
                  title: 'Zalo/ZNS',
                  subtitle: 'Trạng thái tích hợp nhắc tiền trọ cuối tháng',
                  trailingText: 'Mock',
                  onTap: () => context.push(fakeZaloRoute),
                ),
              ],
            ),
          ],
          if (!isAdmin && !isTenant && (canViewBilling || canCreateBilling || canViewReports))
            ...[
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Thanh toán & hóa đơn',
                children: [
                  if (canViewBilling)
                    _SettingsTile(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Mẫu hóa đơn PDF',
                      subtitle: 'Xem hóa đơn và xuất PDF',
                      onTap: () => context.push(billingRoute),
                    ),
                  if (canCreateBilling)
                    _SettingsTile(
                      icon: Icons.event_repeat_rounded,
                      title: 'Tự động lập hóa đơn',
                      subtitle: 'Cấu hình ngày tạo và hạn thanh toán',
                      onTap: () => context.push(bulkBillingRoute),
                    ),
                  if (canViewReports)
                    _SettingsTile(
                      icon: Icons.bar_chart_rounded,
                      title: 'Báo cáo & nhắc nợ',
                      subtitle: 'Doanh thu, công nợ và gửi nhắc Zalo',
                      onTap: () => context.push(reportsRoute),
                    ),
                ],
              ),
            ],
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'Ứng dụng',
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Ngôn ngữ',
                subtitle: 'Ngôn ngữ hiển thị trong ứng dụng',
                trailingText: 'Tiếng Việt',
                onTap: () => _showLanguageSheet(context),
              ),
              const _SettingsTile(
                icon: Icons.light_mode_outlined,
                title: 'Giao diện',
                subtitle: 'Chế độ hiển thị mặc định',
                trailingText: 'Sáng',
              ),
              const _SettingsTile(
                icon: Icons.text_fields_rounded,
                title: 'Font',
                subtitle: 'Kiểu chữ đang dùng toàn app',
                trailingText: 'Manrope',
              ),
              _SettingsTile(
                icon: Icons.cloud_queue_rounded,
                title: 'API',
                subtitle: ApiConfig.baseUrl,
                trailingText: _apiModeLabel(ApiConfig.baseUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ZALO-STYLE UI — màn hình danh sách tin nhắn + chat detail
// ═══════════════════════════════════════════════════════════════════════════

const _kZaloBlue = Color(0xFF0068FF);
const _kZaloBg = Color(0xFFFFFFFF);
const _kZaloChatBg = Color(0xFFE8F3FF);
const _kZaloGrey = Color(0xFFF0F0F0);
const _kZaloTextMain = Color(0xFF0F172A);
const _kZaloTextSub = Color(0xFF6B7280);

enum _ZaloDeliveryFilter { all, sent, issues, month }

// ── Main simulator screen ──────────────────────────────────────────────────

class FakeZaloSimulatorScreen extends ConsumerStatefulWidget {
  const FakeZaloSimulatorScreen({super.key});

  @override
  ConsumerState<FakeZaloSimulatorScreen> createState() =>
      _FakeZaloSimulatorScreenState();
}

class _FakeZaloSimulatorScreenState
    extends ConsumerState<FakeZaloSimulatorScreen>
    with SingleTickerProviderStateMixin {
  int _bottomTab =
      0; // 0: Tin nhắn, 1: Danh bạ, 2: Khám phá, 3: Nhật ký, 4: Cá nhân
  _ZaloDeliveryFilter _filter = _ZaloDeliveryFilter.all;
  late TabController _tabController;
  final _searchFocus = FocusNode();
  bool _creatingTest = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(notificationDeliveriesProvider);

    return Scaffold(
      backgroundColor: _kZaloBg,
      body: Column(
        children: [
          // ── Zalo Top Bar (Matching exact Zalo search header) ───────────
          _ZaloTopBar(
            searchCtrl: _searchCtrl,
            searchFocus: _searchFocus,
            creatingTest: _creatingTest,
            onCreateTest: _createTestMessage,
            onRefresh: () => ref.invalidate(notificationDeliveriesProvider),
            onFilterChanged: (v) => setState(() => _filter = v),
          ),
          // ── Tab view content ──────────────────────────────────────────
          Expanded(
            child: switch (_bottomTab) {
              0 => Column(
                  children: [
                    // Sub tab bar (Ưu tiên / Khác / Đã gửi)
                    _ZaloTabBar(controller: _tabController),
                    Expanded(
                      child: RefreshIndicator(
                        color: _kZaloBlue,
                        onRefresh: () =>
                            ref.refresh(notificationDeliveriesProvider.future),
                        child: deliveriesAsync.when(
                          loading: () => const _ZaloLoadingList(),
                          error: (e, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off_rounded,
                                      size: 48, color: Color(0xFFD1D5DB)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Không tải được: $e',
                                    textAlign: TextAlign.center,
                                    style:
                                        const TextStyle(color: _kZaloTextSub),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () => ref.invalidate(
                                        notificationDeliveriesProvider),
                                    child: const Text('Thử lại',
                                        style: TextStyle(color: _kZaloBlue)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (deliveries) {
                            final q = _searchCtrl.text.trim().toLowerCase();
                            final zaloItems =
                                deliveries.where((d) => d.isZalo).toList();
                            final filtered = _applyFilter(zaloItems);
                            final conversations = _buildConversations(filtered);
                            final visible = q.isEmpty
                                ? conversations
                                : conversations
                                    .where((c) =>
                                        c.latest.tenantName
                                            .toLowerCase()
                                            .contains(q) ||
                                        c.latest.roomName
                                            .toLowerCase()
                                            .contains(q))
                                    .toList();

                            if (visible.isEmpty) {
                              return _ZaloEmptyState(
                                creating: _creatingTest,
                                onCreateTest: _createTestMessage,
                              );
                            }

                            return ListView.builder(
                              itemCount: visible.length,
                              itemBuilder: (_, i) => _AnimatedZaloTile(
                                index: i,
                                child: _ZaloConversationTile(
                                  item: visible[i].latest,
                                  onTap: () => _openChat(context, visible[i]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              1 => const _ZaloContactsTab(),
              2 => const _ZaloExploreTab(),
              3 => const _ZaloTimelineTab(),
              4 => const _ZaloProfileTab(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
      // ── Zalo 5-Tab Bottom Navigation Bar ──────────────────────────────
      bottomNavigationBar: _ZaloBottomNav(
        selectedIndex: _bottomTab,
        onTabSelected: (index) => setState(() => _bottomTab = index),
      ),
    );
  }

  List<NotificationDeliveryLog> _applyFilter(
      List<NotificationDeliveryLog> items) {
    final now = DateTime.now();
    return switch (_filter) {
      _ZaloDeliveryFilter.sent => items.where((d) => d.isSent).toList(),
      _ZaloDeliveryFilter.issues =>
        items.where((d) => d.isFailed || d.isSkipped).toList(),
      _ZaloDeliveryFilter.month => items.where((d) {
          final t = d.createdAt;
          return t != null && t.month == now.month && t.year == now.year;
        }).toList(),
      _ZaloDeliveryFilter.all => items,
    };
  }

  List<_ZaloConversation> _buildConversations(
    List<NotificationDeliveryLog> items,
  ) {
    final groups = <String, List<NotificationDeliveryLog>>{};
    for (final item in items) {
      final key = item.tenantId?.isNotEmpty == true
          ? item.tenantId!
          : '${item.recipient}-${item.tenantName}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final conversations = groups.entries.map((entry) {
      final messages = [...entry.value]
        ..sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
      return _ZaloConversation(key: entry.key, messages: messages);
    }).toList()
      ..sort(
          (a, b) => _messageTime(b.latest).compareTo(_messageTime(a.latest)));
    return conversations;
  }

  void _openChat(BuildContext context, _ZaloConversation conversation) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            _ZaloChatScreen(conversation: conversation),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _createTestMessage() async {
    if (_creatingTest) return;
    setState(() => _creatingTest = true);
    try {
      await ref.read(notificationsApiProvider).createZaloTestMessage();
      ref.invalidate(notificationDeliveriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo tin Zalo test.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được tin test: $error')),
      );
    } finally {
      if (mounted) setState(() => _creatingTest = false);
    }
  }
}

// ── Zalo Top Header Bar (Matching exact Zalo design) ──────────────────────────

class _ZaloTopBar extends StatelessWidget {
  const _ZaloTopBar({
    required this.searchCtrl,
    required this.searchFocus,
    required this.creatingTest,
    required this.onCreateTest,
    required this.onRefresh,
    required this.onFilterChanged,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final bool creatingTest;
  final VoidCallback onCreateTest;
  final VoidCallback onRefresh;
  final ValueChanged<_ZaloDeliveryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kZaloBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 4,
        bottom: 8,
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Quay lại Cài đặt',
          ),
          // Search input field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      focusNode: searchFocus,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13.5),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: 'Tìm bạn bè, tin nhắn ...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // QR scanner icon
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 22),
            onPressed: onRefresh,
            tooltip: 'Quét QR / Tải lại',
          ),
          // Plus icon (+ / Add contact)
          IconButton(
            icon: creatingTest
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            onPressed: creatingTest ? null : onCreateTest,
            tooltip: 'Tạo tin Zalo test',
          ),
        ],
      ),
    );
  }
}

// ── Zalo 5-Tab Bottom Navigation Bar ─────────────────────────────────────────

class _ZaloBottomNav extends StatelessWidget {
  const _ZaloBottomNav({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _ZaloBottomNavItem(
                icon: Icons.chat_bubble_rounded,
                unselectedIcon: Icons.chat_bubble_outline_rounded,
                label: 'Tin nhắn',
                isSelected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _ZaloBottomNavItem(
                icon: Icons.contact_page_rounded,
                unselectedIcon: Icons.contact_page_outlined,
                label: 'Danh bạ',
                isSelected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              _ZaloBottomNavItem(
                icon: Icons.grid_view_rounded,
                unselectedIcon: Icons.grid_view_outlined,
                label: 'Khám phá',
                isSelected: selectedIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _ZaloBottomNavItem(
                icon: Icons.access_time_filled_rounded,
                unselectedIcon: Icons.access_time_rounded,
                label: 'Nhật ký',
                badge: 'N',
                isSelected: selectedIndex == 3,
                onTap: () => onTabSelected(3),
              ),
              _ZaloBottomNavItem(
                icon: Icons.person_rounded,
                unselectedIcon: Icons.person_outline_rounded,
                label: 'Cá nhân',
                isSelected: selectedIndex == 4,
                onTap: () => onTabSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZaloBottomNavItem extends StatelessWidget {
  const _ZaloBottomNavItem({
    required this.icon,
    required this.unselectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData unselectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    const activeColor = _kZaloBlue;
    const inactiveColor = Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? icon : unselectedIcon,
                  size: 24,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Zalo Contacts Tab View (Danh bạ) ───────────────────────────────────────

class _ZaloContactsTab extends StatelessWidget {
  const _ZaloContactsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        _ZaloContactActionTile(
          icon: Icons.person_add_alt_1_rounded,
          color: Color(0xFF2563EB),
          title: 'Lời mời kết bạn',
          subtitle: 'Xem lời mời từ khách thuê mới',
        ),
        _ZaloContactActionTile(
          icon: Icons.contacts_rounded,
          color: Color(0xFF10B981),
          title: 'Danh bạ máy',
          subtitle: 'Đồng bộ danh bạ từ điện thoại',
        ),
        _ZaloContactActionTile(
          icon: Icons.cake_rounded,
          color: Color(0xFFF59E0B),
          title: 'Lịch sinh nhật',
          subtitle: 'Theo dõi sinh nhật khách thuê',
        ),
        Divider(height: 16, color: Color(0xFFF1F5F9)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'DANH BẠ KHÁCH THUÊ & QUẢN LÝ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        _ZaloContactUserTile(
          name: 'Nguyễn Văn An',
          sub: 'Phòng 101 · 0912 345 678',
        ),
        _ZaloContactUserTile(
          name: 'Trần Thị Bình',
          sub: 'Phòng 102 · 0987 654 321',
        ),
        _ZaloContactUserTile(
          name: 'Lê Hoàng Cường',
          sub: 'Phòng 201 · 0909 112 233',
        ),
        _ZaloContactUserTile(
          name: 'Phạm Minh Đức',
          sub: 'Ban quản lý khu trọ',
        ),
      ],
    );
  }
}

class _ZaloContactActionTile extends StatelessWidget {
  const _ZaloContactActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      onTap: () {},
    );
  }
}

class _ZaloContactUserTile extends StatelessWidget {
  const _ZaloContactUserTile({required this.name, required this.sub});
  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _avatarColor(name),
        child: Text(
          _initials(name),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
      title: Text(name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(sub,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.phone_outlined, size: 20, color: _kZaloBlue),
      onTap: () {},
    );
  }
}

// ── Zalo Explore Tab View (Khám phá) ───────────────────────────────────────

class _ZaloExploreTab extends StatelessWidget {
  const _ZaloExploreTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'TIỆN ÍCH TIỀN TRỌ & ZNS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          children: const [
            _ZaloExploreItem(
              icon: Icons.chat_outlined,
              label: 'ZNS Nhắc nợ',
              color: Color(0xFF0068FF),
            ),
            _ZaloExploreItem(
              icon: Icons.receipt_long_outlined,
              label: 'Hóa đơn PDF',
              color: Color(0xFF10B981),
            ),
            _ZaloExploreItem(
              icon: Icons.electric_bolt_outlined,
              label: 'Điện nước',
              color: Color(0xFFF59E0B),
            ),
            _ZaloExploreItem(
              icon: Icons.analytics_outlined,
              label: 'Báo cáo',
              color: Color(0xFF8B5CF6),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/zalo_logo.png',
                    width: 44, height: 44),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zalo ZNS Official Account',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kZaloBlue),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dịch vụ gửi thông báo hóa đơn tự động qua Zalo ZNS.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
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

class _ZaloExploreItem extends StatelessWidget {
  const _ZaloExploreItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Zalo Timeline Tab View (Nhật ký) ───────────────────────────────────────

class _ZaloTimelineTab extends StatelessWidget {
  const _ZaloTimelineTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text(
          'NHẬT KÝ GỬI TIN & HOẠT ĐỘNG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 12),
        _ZaloTimelineTile(
          time: 'Hôm nay 09:30',
          title: 'Đã tự động gửi nhắc tiền trọ qua Zalo ZNS',
          desc: 'Gửi thành công cho 5 phòng khu trọ Atrium',
          icon: Icons.check_circle_rounded,
          iconColor: Color(0xFF10B981),
        ),
        _ZaloTimelineTile(
          time: 'Hôm qua 18:00',
          title: 'Khách thuê đã đọc tin nhắn Zalo ZNS',
          desc: 'Nguyễn Văn An - Phòng 101',
          icon: Icons.mark_email_read_rounded,
          iconColor: Color(0xFF0068FF),
        ),
        _ZaloTimelineTile(
          time: '08/08/2026',
          title: 'Khởi tạo cấu hình Zalo Official Account',
          desc: 'Tích hợp thành công mẫu ZNS nhắc tiền trọ',
          icon: Icons.verified_user_rounded,
          iconColor: Color(0xFF8B5CF6),
        ),
      ],
    );
  }
}

class _ZaloTimelineTile extends StatelessWidget {
  const _ZaloTimelineTile({
    required this.time,
    required this.title,
    required this.desc,
    required this.icon,
    required this.iconColor,
  });

  final String time;
  final String title;
  final String desc;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Zalo Profile Tab View (Cá nhân) ────────────────────────────────────────

class _ZaloProfileTab extends ConsumerWidget {
  const _ZaloProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).session?.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: _kZaloBlue,
              child: Text(
                _initials(user?.fullName ?? 'Chủ trọ'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Chủ trọ Zalo',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Trạng thái: Zalo ZNS Active',
                    style: TextStyle(
                        fontSize: 12,
                        color: _kZaloBlue,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.qr_code_2_rounded, size: 28, color: _kZaloBlue),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ListTile(
          leading: const Icon(Icons.security_rounded, color: _kZaloBlue),
          title: const Text('Tài khoản và bảo mật',
              style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline_rounded, color: _kZaloBlue),
          title: const Text('Quyền riêng tư Zalo ZNS',
              style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined, color: _kZaloBlue),
          title: const Text('Cài đặt thông báo tin nhắn',
              style: TextStyle(fontWeight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
      ],
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────

class _ZaloTabBar extends StatelessWidget {
  const _ZaloTabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kZaloBlue,
      child: TabBar(
        controller: controller,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Ưu tiên'),
          Tab(text: 'Khác'),
          Tab(text: 'Đã gửi'),
        ],
      ),
    );
  }
}

// ── Conversation tile (Zalo-style) ────────────────────────────────────────

class _ZaloConversation {
  const _ZaloConversation({required this.key, required this.messages});

  final String key;
  final List<NotificationDeliveryLog> messages;

  NotificationDeliveryLog get latest => messages.last;
}

class _ZaloConversationTile extends StatelessWidget {
  const _ZaloConversationTile({required this.item, required this.onTap});

  final NotificationDeliveryLog item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _ZaloStatusStyle.fromItem(item);
    final isUnread = item.isTenantMessage || !item.isSent;
    final timeStr = _timeAgo(item.sentAt ?? item.updatedAt ?? item.createdAt);
    final preview = item.isTenantMessage
        ? 'Khách: ${item.messageText()}'
        : item.messageText();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _avatarColor(item.tenantName),
                  child: Text(
                    _initials(item.tenantName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Zalo icon badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/zalo_logo.png',
                        width: 14,
                        height: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // ── Name + preview ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.tenantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _kZaloTextMain,
                            fontSize: 15,
                            fontWeight:
                                isUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isUnread ? _kZaloBlue : _kZaloTextSub,
                          fontSize: 11,
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // message preview
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnread ? _kZaloTextMain : _kZaloTextSub,
                            fontSize: 12.5,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isTenantMessage
                              ? const Color(0xFFDBEAFE)
                              : status.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.isTenantMessage ? 'Khách gửi' : status.label,
                          style: TextStyle(
                            color: item.isTenantMessage
                                ? _kZaloBlue
                                : status.foreground,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.roomName} · ${formatCurrencyVnd(item.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kZaloTextSub,
                      fontSize: 11,
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

// ── Chat screen (Zalo-style) ──────────────────────────────────────────────

class _ZaloChatScreen extends ConsumerStatefulWidget {
  const _ZaloChatScreen({required this.conversation});

  final _ZaloConversation conversation;

  @override
  ConsumerState<_ZaloChatScreen> createState() => _ZaloChatScreenState();
}

class _ZaloChatScreenState extends ConsumerState<_ZaloChatScreen> {
  final _replyCtrl = TextEditingController();
  final _manualMessages = <_LocalZaloMessage>[];
  bool _hasText = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _replyCtrl.addListener(() {
      final v = _replyCtrl.text.trim().isNotEmpty;
      if (v != _hasText) setState(() => _hasText = v);
    });
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.conversation.latest;
    final status = _ZaloStatusStyle.fromItem(item);
    final messages = widget.conversation.messages;

    return Scaffold(
      backgroundColor: _kZaloChatBg,
      // ── Zalo chat AppBar ───────────────────────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: _kZaloBlue,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
          ),
          child: Row(
            children: [
              // Back
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // Avatar
              CircleAvatar(
                radius: 19,
                backgroundColor: _avatarColor(item.tenantName),
                child: Text(
                  _initials(item.tenantName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + status
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.tenantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.isSent
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.recipient.isEmpty ? 'Zalo mock' : item.recipient,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              IconButton(
                icon: const Icon(Icons.phone_outlined,
                    color: Colors.white, size: 22),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined,
                    color: Colors.white, size: 22),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => _showMoreSheet(context, item, status),
              ),
            ],
          ),
        ),
      ),
      // ── Chat body ─────────────────────────────────────────────────────
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              children: [
                // Date separator
                _ZaloDateSeparator(date: _messageTime(messages.first)),
                const SizedBox(height: 12),
                // OA sender label (like Zalo Official Account)
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tin nhắc tiền trọ từ hệ thống',
                      style: TextStyle(
                        color: _kZaloTextSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final delivery in messages) ...[
                  if (delivery.isTenantMessage)
                    _ZaloIncomingBubble(
                      message: delivery.messageText(),
                      time: _formatHourMinute(_messageTime(delivery)),
                    )
                  else
                    _ZaloOutgoingBubble(
                      message: delivery.messageText(),
                      time: _formatHourMinute(_messageTime(delivery)),
                      statusStyle: _ZaloStatusStyle.fromItem(delivery),
                    ),
                  const SizedBox(height: 10),
                ],
                for (final local in _manualMessages) ...[
                  _ZaloOutgoingBubble(
                    message: local.message,
                    time: _formatHourMinute(local.sentAt),
                    statusStyle: const _ZaloStatusStyle(
                      label: 'Đã gửi',
                      foreground: Color(0xFF047857),
                      background: Color(0xFFD1FAE5),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
                // Invoice info card (like Zalo "đính kèm" card)
                _ZaloInvoiceCard(item: item),
              ],
            ),
          ),
          // ── Bottom input bar ───────────────────────────────────────────
          _ZaloChatInputBar(
            controller: _replyCtrl,
            hasText: _hasText,
            sending: _sending,
            onSend: _sendManualMessage,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: item.messageText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã copy nội dung.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendManualMessage() async {
    final item = widget.conversation.latest;
    final text = _replyCtrl.text.trim();
    final tenantId = item.tenantId;

    if (text.isEmpty || _sending) return;
    if (tenantId == null || tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tin này chưa gắn với tenant.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(notificationsApiProvider).sendZaloManualMessage(
            tenantId: tenantId,
            invoiceId: item.invoiceId,
            message: text,
          );
      ref.invalidate(notificationDeliveriesProvider);
      if (!mounted) return;
      setState(() {
        _manualMessages
            .add(_LocalZaloMessage(message: text, sentAt: DateTime.now()));
        _replyCtrl.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không gửi được tin nhắn: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMoreSheet(BuildContext context, NotificationDeliveryLog item,
      _ZaloStatusStyle status) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.tenantName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _kZaloTextMain,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ZaloInfoRow(label: 'Phòng', value: item.roomName),
              _ZaloInfoRow(label: 'Tháng', value: item.billingMonth),
              _ZaloInfoRow(
                  label: 'Số tiền', value: formatCurrencyVnd(item.amount)),
              _ZaloInfoRow(label: 'Hạn thanh toán', value: item.dueDateText),
              if (item.errorMessage?.isNotEmpty == true)
                _ZaloInfoRow(
                  label: 'Ghi chú lỗi',
                  value: item.errorMessage!,
                  danger: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Zalo chat bubbles & components ────────────────────────────────────────

class _LocalZaloMessage {
  const _LocalZaloMessage({required this.message, required this.sentAt});

  final String message;
  final DateTime sentAt;
}

class _ZaloDateSeparator extends StatelessWidget {
  const _ZaloDateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final s =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          s,
          style: const TextStyle(
            color: _kZaloTextSub,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ZaloOutgoingBubble extends StatelessWidget {
  const _ZaloOutgoingBubble({
    required this.message,
    required this.time,
    required this.statusStyle,
  });

  final String message;
  final String time;
  final _ZaloStatusStyle statusStyle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: _kZaloBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: _kZaloTextSub,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusStyle.label,
                  style: TextStyle(
                    color: statusStyle.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _ZaloIncomingBubble extends StatelessWidget {
  const _ZaloIncomingBubble({
    required this.message,
    required this.time,
  });

  final String message;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: _kZaloTextMain,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              color: _kZaloTextSub,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZaloInvoiceCard extends StatelessWidget {
  const _ZaloInvoiceCard({required this.item});
  final NotificationDeliveryLog item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F7FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: _kZaloBlue, size: 18),
                SizedBox(width: 8),
                Text(
                  'Chi tiết hóa đơn',
                  style: TextStyle(
                    color: _kZaloBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F0FF)),
          // Info rows
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _ZaloInfoRow(label: 'Khách thuê', value: item.tenantName),
                _ZaloInfoRow(label: 'Phòng', value: item.roomName),
                _ZaloInfoRow(label: 'Tháng', value: item.billingMonth),
                _ZaloInfoRow(
                  label: 'Số tiền',
                  value: formatCurrencyVnd(item.amount),
                  highlight: true,
                ),
                _ZaloInfoRow(label: 'Hạn thanh toán', value: item.dueDateText),
                if (item.invoiceId?.isNotEmpty == true)
                  _ZaloInfoRow(label: 'Hóa đơn #', value: item.invoiceId!),
                if (item.errorMessage?.isNotEmpty == true)
                  _ZaloInfoRow(
                    label: 'Lỗi',
                    value: item.errorMessage!,
                    danger: true,
                  ),
              ],
            ),
          ),
          // Copy button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: item.messageText()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã copy nội dung tin nhắn.')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy_rounded, color: _kZaloBlue, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Copy nội dung tin nhắn',
                      style: TextStyle(
                        color: _kZaloBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZaloChatInputBar extends StatelessWidget {
  const _ZaloChatInputBar({
    required this.controller,
    required this.hasText,
    required this.sending,
    required this.onSend,
    required this.onCopy,
  });

  final TextEditingController controller;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          // Sticker / emoji
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined,
                color: _kZaloTextSub, size: 26),
            onPressed: () {},
          ),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
              decoration: BoxDecoration(
                color: _kZaloGrey,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: controller,
                maxLines: null,
                style: const TextStyle(fontSize: 14, color: _kZaloTextMain),
                decoration: const InputDecoration(
                  hintText: 'Tin nhắn',
                  hintStyle: TextStyle(fontSize: 14, color: _kZaloTextSub),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
          ),
          // Right side buttons
          if (!hasText) ...[
            IconButton(
              icon: const Icon(Icons.mic_none_rounded,
                  color: _kZaloTextSub, size: 26),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined,
                  color: _kZaloTextSub, size: 26),
              onPressed: onCopy,
              tooltip: 'Copy nội dung',
            ),
          ] else
            IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _kZaloBlue,
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
              onPressed: sending ? null : onSend,
            ),
        ],
      ),
    );
  }
}

// ── Info rows & misc ──────────────────────────────────────────────────────

class _ZaloInfoRow extends StatelessWidget {
  const _ZaloInfoRow({
    required this.label,
    required this.value,
    this.danger = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool danger;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: _kZaloTextSub,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: danger
                    ? const Color(0xFFB91C1C)
                    : highlight
                        ? _kZaloBlue
                        : _kZaloTextMain,
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

class _ZaloEmptyState extends StatelessWidget {
  const _ZaloEmptyState({
    required this.creating,
    required this.onCreateTest,
  });

  final bool creating;
  final VoidCallback onCreateTest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/zalo_logo.png',
                    width: 48,
                    height: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có tin Zalo nào',
              style: TextStyle(
                  color: _kZaloTextMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bấm tạo tin test để sinh tin mock cho tenant đã kích hoạt tài khoản.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kZaloTextSub, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: creating ? null : onCreateTest,
              icon: creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_comment_rounded),
              label: const Text('Tạo tin test'),
              style: FilledButton.styleFrom(
                backgroundColor: _kZaloBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nếu chưa có tenant account, hãy mời/kích hoạt tenant trước.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _kZaloTextSub, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZaloLoadingList extends StatelessWidget {
  const _ZaloLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ZaloShimmerTile(wider: i % 3 == 0),
    );
  }
}

class _ZaloShimmerTile extends StatelessWidget {
  const _ZaloShimmerTile({required this.wider});
  final bool wider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFE5E7EB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 13,
                width: wider ? 140 : 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedZaloTile extends StatelessWidget {
  const _AnimatedZaloTile({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + index.clamp(0, 6) * 40),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ── Status style helper ───────────────────────────────────────────────────

class _ZaloStatusStyle {
  const _ZaloStatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  factory _ZaloStatusStyle.fromItem(NotificationDeliveryLog item) {
    if (item.isSent) {
      return const _ZaloStatusStyle(
        label: 'Đã gửi',
        foreground: Color(0xFF047857),
        background: Color(0xFFD1FAE5),
      );
    }
    if (item.isFailed) {
      return const _ZaloStatusStyle(
        label: 'Lỗi',
        foreground: Color(0xFFB91C1C),
        background: Color(0xFFFEE2E2),
      );
    }
    if (item.isSkipped) {
      return const _ZaloStatusStyle(
        label: 'Mock / bỏ qua',
        foreground: Color(0xFFB45309),
        background: Color(0xFFFEF3C7),
      );
    }
    return const _ZaloStatusStyle(
      label: 'Chờ gửi',
      foreground: Color(0xFF2563EB),
      background: Color(0xFFDBEAFE),
    );
  }
}

// ── Color helpers ─────────────────────────────────────────────────────────

Color _avatarColor(String name) {
  const colors = [
    Color(0xFF0068FF),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF16A34A),
  ];
  if (name.isEmpty) return colors[0];
  final code = name.codeUnits.fold(0, (a, b) => a + b);
  return colors[code % colors.length];
}

String _formatHourMinute(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime _messageTime(NotificationDeliveryLog item) {
  return item.sentAt ?? item.updatedAt ?? item.createdAt ?? DateTime.now();
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.roleLabel,
    this.phone,
  });

  final String name;
  final String email;
  final String? phone;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(
                color: Color(0xFF2563EB),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 68,
                    color: Color(0xFFE5E7EB),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    this.icon,
    this.imageAsset,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.onTap,
    this.destructive = false,
  }) : assert(icon != null || imageAsset != null,
            'Either icon or imageAsset must be provided');

  final IconData? icon;
  final String? imageAsset;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        destructive ? const Color(0xFFDC2626) : const Color(0xFF111827);
    final iconColor = destructive ? const Color(0xFFDC2626) : AppTheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: imageAsset != null
                    ? Colors.transparent
                    : iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageAsset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(imageAsset!, fit: BoxFit.cover),
                    )
                  : Icon(icon!, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (trailingText != null)
              Flexible(
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (onTap != null)
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

void _showProfileSheet(BuildContext context, LandlordUser? user) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin cá nhân',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _ProfileInfoLine(label: 'Họ tên', value: user?.fullName ?? '-'),
            _ProfileInfoLine(label: 'Email', value: user?.email ?? '-'),
            _ProfileInfoLine(
              label: 'Số điện thoại',
              value: user?.phone?.isNotEmpty == true ? user!.phone! : '-',
            ),
            _ProfileInfoLine(
              label: 'Vai trò',
              value: _roleLabel(user?.role ?? 'landlord'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Phần chỉnh sửa hồ sơ có thể nối API riêng ở bước sau.',
              style: TextStyle(
                color: Color(0xFF6B7280),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileInfoLine extends StatelessWidget {
  const _ProfileInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showLanguageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ngôn ngữ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.primary),
                title: const Text(
                  'Tiếng Việt',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Ngôn ngữ mặc định của ứng dụng'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _roleLabel(String role) {
  return switch (role) {
    'admin' => 'Admin',
    'tenant' => 'Tenant',
    'staff' => 'Nhân viên',
    _ => 'Chủ trọ',
  };
}

String _apiModeLabel(String baseUrl) {
  final lower = baseUrl.toLowerCase();
  if (lower.contains('localhost') || lower.contains('127.0.0.1')) {
    return 'Local';
  }
  return 'Production';
}

String _timeAgo(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes}p';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  return formatDate(local);
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  final first = String.fromCharCode(parts.first.runes.first);
  final last =
      parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
  return (first + last).toUpperCase();
}
