import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/admin_dashboard.dart';
import '../../models/admin_models.dart';
import 'admin_console_providers.dart';
import 'admin_overview_providers.dart';
import 'admin_overview_chart.dart';
import 'admin_overview_shell.dart';
import 'admin_overview_theme.dart';
import 'admin_providers.dart';
import 'admin_workspace_navigation.dart';
import 'admin_workspace_states.dart';
import '../auth/auth_providers.dart';

class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({super.key, this.reports = false});
  final bool reports;
  @override
  Widget build(BuildContext context) => Theme(
      data: AdminOverviewTheme.light,
      child: _AdminOverviewContent(reports: reports));
}

class _AdminOverviewContent extends ConsumerStatefulWidget {
  const _AdminOverviewContent({required this.reports});
  final bool reports;
  @override
  ConsumerState<_AdminOverviewContent> createState() =>
      _AdminOverviewPageState();
}

class _AdminOverviewPageState extends ConsumerState<_AdminOverviewContent> {
  int _days = 30;
  String _metric = 'accounts';
  String? _owner;
  bool _allActions = false;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  void _refresh() {
    if (_owner == null || ref.read(sessionIdentityProvider) != _owner) return;
    ref.invalidate(adminCapabilitiesProvider);
    ref.invalidate(adminResourceProvider(
        AdminRequest('/admin/analytics/overview', {'days': _days})));
    ref.invalidate(adminWorkspaceResourceProvider(
        AdminRequest('/admin/analytics/overview', {'days': _days})));
    ref.invalidate(adminDashboardDataProvider(_days));
    ref.invalidate(adminResourceProvider(adminWorkspaceSummaryRequest));
    ref.invalidate(
        adminWorkspaceResourceProvider(adminWorkspaceSummaryRequest));
    ref.invalidate(adminWorkspaceSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    if (_owner == null || identity != _owner) {
      return const Scaffold(
          body: SafeArea(
              child: Center(
                  child: Text(
                      'Phiên đã thay đổi. Vui lòng mở lại trang quản trị.'))));
    }
    final rights = ref.watch(adminCapabilitiesProvider);
    return rights.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const Scaffold(body: AdminLoadingState(light: true)),
      error: (error, _) => Scaffold(
          body: AdminFailureState(
              light: true,
              error: error,
              retry: () => ref.invalidate(adminCapabilitiesProvider))),
      data: (capabilities) => !capabilities.has('admin.dashboard.view')
          ? const Scaffold(
              body: SafeArea(
                  child:
                      Center(child: Text('Bạn không có quyền xem tổng quan.'))))
          : AdminOverviewShell(
              reports: widget.reports,
              rights: capabilities,
              refresh: _refresh,
              body: _body(capabilities),
            ),
    );
  }

  Widget _body(AdminCapabilities rights) {
    final state = ref.watch(adminDashboardDataProvider(_days));
    return state.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      loading: () => const AdminLoadingState(light: true),
      error: (error, _) =>
          ListView(padding: const EdgeInsets.all(24), children: [
        AdminFailureState(error: error, retry: _refresh, light: true),
      ]),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          _refresh();
          try {
            await ref.read(adminDashboardDataProvider(_days).future);
          } catch (_) {}
        },
        color: AdminOverviewTheme.blue,
        child: LayoutBuilder(
            builder: (context, constraints) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                        math.max(20, (constraints.maxWidth - 1120) / 2),
                        4,
                        math.max(20, (constraints.maxWidth - 1120) / 2),
                        34),
                    children: [
                      _periodPicker(),
                      const SizedBox(height: 16),
                      if (!widget.reports) ...[
                        _hero(),
                        const SizedBox(height: 20),
                        _metrics(data, rights),
                        const SizedBox(height: 20),
                        if (rights.has('admin.properties.view')) ...[
                          _occupancy(data),
                          const SizedBox(height: 20)
                        ],
                        _trendCard(data, rights),
                        const SizedBox(height: 20),
                        _accountBreakdown(data),
                        const SizedBox(height: 20),
                        _actionQueue(rights),
                        const SizedBox(height: 20),
                        if (rights.has('admin.finance.read')) _finance(data),
                      ] else ...[
                        _reportLead(data),
                        const SizedBox(height: 20),
                        _metrics(data, rights),
                        const SizedBox(height: 20),
                        _accountBreakdown(data),
                        const SizedBox(height: 20),
                        _trendCard(data, rights, expanded: true),
                        const SizedBox(height: 20),
                        if (rights.has('admin.finance.read')) ...[
                          _finance(data, expanded: true),
                          const SizedBox(height: 20)
                        ],
                        _reportDefinitions(data, rights),
                        const SizedBox(height: 20),
                        _dailyReport(data, rights),
                      ],
                      const SizedBox(height: 18),
                      Text(
                          'Cập nhật ${_date(data.generatedAt, time: true)} · Giờ Việt Nam',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(
                          'Kỳ ${_date(data.from)} – ${_date(data.to)} còn đang diễn ra. '
                          'So sánh số phát sinh với $_days ngày đầy đủ liền trước; tỷ lệ lấp đầy và công nợ là ảnh chụp hiện tại.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
      ),
    );
  }

  Widget _periodPicker() => SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
          showSelectedIcon: false,
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size(44, 44)),
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8)),
            textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            side: WidgetStateProperty.all(BorderSide.none),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AdminOverviewTheme.blue
                    : Colors.white),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AdminOverviewTheme.muted),
          ),
          segments: const [
            ButtonSegment(value: 7, label: Text('7 ngày')),
            ButtonSegment(value: 30, label: Text('30 ngày')),
            ButtonSegment(value: 90, label: Text('90 ngày')),
            ButtonSegment(value: 180, label: Text('6 tháng'))
          ],
          selected: {_days},
          onSelectionChanged: (value) => setState(() => _days = value.first)));

  Widget _hero() => Semantics(
      button: true,
      label: 'Tổng quan hệ thống. Xem báo cáo',
      child: Material(
        color: const Color(0xFFDDEAFF),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/admin/reports/overview'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 108),
            child: Stack(children: [
              Positioned.fill(
                left: 190,
                child: Opacity(
                    opacity: .34,
                    child: Image.asset(
                        'assets/images/a_high_quality_architectural_photograph_of_a_modern_luxury_apartment_building (1).png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tổng quan hệ thống',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Quản lý và vận hành hiệu quả.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: const Color(0xFF304C82))),
                    ],
                  )),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AdminOverviewTheme.blue),
                ]),
              ),
            ]),
          ),
        ),
      ));

  Widget _reportLead(AdminDashboardData data) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AdminOverviewTheme.ink, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Báo cáo vận hành',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text('So sánh ${data.days} ngày gần nhất với kỳ trước.',
                    style: const TextStyle(color: Color(0xFFB8C5E0))),
              ])),
          const Icon(Icons.insights_rounded,
              color: Color(0xFFAEC3FF), size: 42),
        ]),
      );

  Widget _metrics(AdminDashboardData data, AdminCapabilities rights) {
    final cards = [
      _MetricData(
          'Người dùng',
          _format(data.accountTotal),
          Icons.people_alt_outlined,
          AdminOverviewTheme.blue,
          data.growth['accounts']),
      _MetricData(
          'Khu trọ',
          _format(data.propertyTotal),
          Icons.apartment_outlined,
          AdminOverviewTheme.blue,
          data.growth['properties']),
      _MetricData(
          'Tổng phòng',
          _format(data.roomTotal),
          Icons.meeting_room_outlined,
          AdminOverviewTheme.blue,
          data.growth['rooms']),
      if (rights.has('admin.finance.read'))
        _MetricData(
            'Doanh thu nền tảng',
            data.finance?.platformRevenue == null
                ? '—'
                : _money(data.finance!.platformRevenue!),
            Icons.account_balance_wallet_outlined,
            AdminOverviewTheme.blue,
            null)
      else
        _MetricData(
            'Tài khoản hoạt động',
            _format((data.accounts['active'] as num?)?.toInt() ?? 0),
            Icons.verified_user_outlined,
            AdminOverviewTheme.blue,
            null),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth < 330 &&
                  MediaQuery.textScalerOf(context).scale(1) > 1.4
              ? 1
              : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final card in cards)
          SizedBox(width: width, child: _metricCard(card)),
      ]);
    });
  }

  Widget _metricCard(_MetricData card) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D23335C),
                  blurRadius: 18,
                  offset: Offset(0, 6))
            ]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: card.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(card.icon, color: card.color, size: 19)),
                const Spacer(),
              ]),
              const SizedBox(height: 8),
              Text(card.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(card.value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 23)),
              const SizedBox(height: 8),
              if (card.growth != null)
                _growthPill(card.growth!)
              else
                Text(
                    card.label == 'Doanh thu nền tảng'
                        ? 'Chưa có dữ liệu'
                        : 'Số liệu hiện tại',
                    style: Theme.of(context).textTheme.bodySmall),
            ]),
      );

  Widget _accountBreakdown(AdminDashboardData data) => _Panel(
      title: 'Cơ cấu tài khoản',
      subtitle: 'Tổng hợp theo trạng thái và vai trò hiện tại.',
      child: LayoutBuilder(builder: (context, constraints) {
        final entries = <({String label, int value, Color color})>[
          (
            label: 'Đang hoạt động',
            value: _int(data.accounts['active']),
            color: AdminOverviewTheme.green
          ),
          (
            label: 'Tạm khóa',
            value: _int(data.accounts['inactive']),
            color: AdminOverviewTheme.red
          ),
          (
            label: 'Chủ trọ',
            value: _int(data.accounts['landlords']),
            color: AdminOverviewTheme.blue
          ),
          (
            label: 'Người thuê',
            value: _int(data.accounts['tenants']),
            color: const Color(0xFF6B7BD8)
          ),
          (
            label: 'Nhân viên',
            value: _int(data.accounts['staff']),
            color: const Color(0xFF8A5CF6)
          ),
          (
            label: 'Admin',
            value: _int(data.accounts['admins']),
            color: AdminOverviewTheme.ink
          ),
        ];
        final columns = constraints.maxWidth >= 640 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final entry in entries)
            SizedBox(
                width: width,
                child: _BreakdownValue(entry.label, entry.value, entry.color)),
        ]);
      }));

  Widget _growthPill(AdminMetricGrowth growth) {
    final value = growth.changePercent;
    final positive = (value ?? 0) >= 0;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
            color: (positive ? AdminOverviewTheme.green : AdminOverviewTheme.red)
                .withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99)),
        child: Text(
            value == null
                ? (growth.current == 0
                    ? 'Không phát sinh'
                    : '${growth.current} mới · kỳ trước 0')
                : '${positive ? '+' : ''}${value.toStringAsFixed(0)}% phát sinh mới',
            style: TextStyle(
                fontSize: 11,
                color: positive ? AdminOverviewTheme.green : AdminOverviewTheme.red,
                fontWeight: FontWeight.w700)));
  }

  Widget _occupancy(AdminDashboardData data) {
    final rate = data.occupancyRate;
    return _Panel(
        title: 'Tình trạng phòng',
        subtitle: 'Theo các khu trọ đang hoạt động.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (rate == null)
            const _InfoBanner('Chưa có phòng hoạt động để tính tỷ lệ lấp đầy.',
                Icons.info_outline),
          if (rate == null) const SizedBox(height: 14),
          Row(children: [
            SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(
                    painter: _DonutPainter(
                        _roomValue(data, 'occupied'),
                        _roomValue(data, 'vacant'),
                        _roomValue(data, 'maintenance')),
                    child: Center(
                        child: Text(
                            rate == null
                                ? '—'
                                : '${(rate * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleLarge)))),
            const SizedBox(width: 20),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Legend(
                          color: AdminOverviewTheme.blue,
                          label: 'Đang thuê',
                          valueKey: 'occupied'),
                      const _Legend(
                          color: Color(0xFFCBD5E7),
                          label: 'Còn trống',
                          valueKey: 'vacant'),
                      const _Legend(
                          color: Color(0xFFF4B35E),
                          label: 'Bảo trì',
                          valueKey: 'maintenance'),
                    ]
                        .map((item) => item.copyWith(
                            value:
                                '${_format(_roomValue(data, item.valueKey))} phòng'))
                        .toList())),
          ]),
        ]));
  }

  int _roomValue(AdminDashboardData data, String key) =>
      (data.rooms[key] as num?)?.toInt() ?? 0;

  Widget _trendCard(AdminDashboardData data, AdminCapabilities rights,
      {bool expanded = false}) {
    final tabs = {
      'accounts': 'Người dùng',
      'properties': 'Khu trọ',
      'rooms': 'Phòng',
      if (rights.has('admin.finance.read') && data.finance != null)
        'rentalNet': 'Tiền thuê ròng'
    };
    final metric = tabs.containsKey(_metric) ? _metric : 'accounts';
    return _Panel(
        title: expanded ? 'Tăng trưởng theo ngày' : 'Xu hướng tăng trưởng',
        subtitle: expanded
            ? 'Theo dõi dữ liệu mới phát sinh trong kỳ đã chọn.'
            : 'Dữ liệu mới phát sinh trong kỳ đã chọn.',
        trailing: null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  key: const ValueKey('overview-chart-metric'),
                  value: metric,
                  isExpanded: true,
                  items: [
                    for (final entry in tabs.entries)
                      DropdownMenuItem(
                          value: entry.key, child: Text(entry.value))
                  ],
                  onChanged: (value) =>
                      setState(() => _metric = value ?? metric))),
          AdminOverviewChart(data: data.trends, metric: metric),
          const SizedBox(height: 8),
          Row(children: [
            Text('Kỳ hiện tại', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
                _format(data.trends.fold<int>(
                        0, (sum, row) => sum + row.valueFor(metric))) +
                    (metric == 'rentalNet' ? ' đ' : ''),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AdminOverviewTheme.blue)),
          ]),
        ]));
  }

  Widget _finance(AdminDashboardData data, {bool expanded = false}) {
    final finance = data.finance;
    return _Panel(
        title: 'Tài chính hệ thống',
        subtitle: 'Tiền thuê và chi phí được tách khỏi doanh thu nền tảng.',
        child: Column(children: [
          if (finance == null)
            const _InfoBanner(
                'Bạn chưa có quyền xem số liệu tài chính.', Icons.lock_outline),
          if (finance != null)
            Wrap(spacing: 12, runSpacing: 12, children: [
              _FinanceValue(
                  label: 'Tiền thuê thu được',
                  value: _money(finance.collected),
                  color: AdminOverviewTheme.green),
              _FinanceValue(
                  label: 'Tiền thuê ròng',
                  value: _money(finance.net),
                  color: AdminOverviewTheme.blue),
              _FinanceValue(
                  label: 'Chi phí',
                  value: _money(finance.expenses),
                  color: AdminOverviewTheme.red),
              _FinanceValue(
                  label: 'Thanh toán lỗi',
                  value: _format(finance.failedPayments),
                  color: const Color(0xFFEA8A1F)),
            ]),
          const SizedBox(height: 14),
          _InfoBanner(
              finance?.platformRevenue == null
                  ? 'Doanh thu nền tảng chưa có dữ liệu vì gói dịch vụ chưa được bật.'
                  : 'Doanh thu nền tảng: ${_money(finance!.platformRevenue!)}',
              Icons.account_balance_wallet_outlined),
          if (expanded && finance != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 17, color: Color(0xFFEA8A1F)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Công nợ hiện tại: ${_money(finance.outstanding)}',
                      style: Theme.of(context).textTheme.bodyMedium))
            ]),
          ],
        ]));
  }

  Widget _actionQueue(AdminCapabilities rights) =>
      Consumer(builder: (context, ref, _) {
        final summary = ref.watch(adminWorkspaceSummaryProvider);
        return summary.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () =>
                const _InfoBanner('Đang tải hàng đợi điều hành…', Icons.sync),
            error: (_, __) => _Panel(
                title: 'Hàng đợi điều hành',
                subtitle: 'Không tải được nguồn công việc.',
                child: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'))),
            data: (data) {
              final items = data.items
                  .where((item) =>
                      item.key != 'notifications' &&
                      rights.has(item.permission) &&
                      (adminDestinationFor(item.route)?.allowed(rights) ??
                          false) &&
                      (_allActions || !item.available || (item.count ?? 0) > 0))
                  .toList()
                ..sort(
                    (left, right) => left.priority.compareTo(right.priority));
              return _Panel(
                  title: 'Hàng đợi điều hành',
                  subtitle: 'Ưu tiên các việc cần tiếp nhận hôm nay.',
                  child: Column(children: [
                    if (data.partial)
                      const _InfoBanner(
                          'Một số nguồn chưa sẵn sàng. Số chưa tải được không được tính là 0.',
                          Icons.info_outline),
                    if (items.isEmpty)
                      _InfoBanner(
                          data.partial
                              ? 'Chưa có việc từ các nguồn đã tải; vẫn còn nguồn cần kiểm tra.'
                              : 'Không có việc tồn đọng trong phạm vi quyền hiện tại.',
                          Icons.check_circle_outline),
                    for (final item in items)
                      ListTile(
                          key: ValueKey('admin-action-${item.key}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                              item.priority == 0
                                  ? Icons.error_outline
                                  : Icons.pending_actions_outlined,
                              color: item.priority == 0
                                  ? AdminOverviewTheme.red
                                  : AdminOverviewTheme.blue),
                          title: Text(item.label),
                          subtitle: Text(item.available
                              ? '${item.count} mục đang chờ'
                              : 'Chưa tải được số liệu; mở để kiểm tra.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(item.destination)),
                    TextButton(
                        onPressed: () =>
                            setState(() => _allActions = !_allActions),
                        child: Text(_allActions
                            ? 'Chỉ hiện việc tồn đọng'
                            : 'Hiện cả nhóm không tồn đọng')),
                  ]));
            });
      });

  Widget _reportDefinitions(
          AdminDashboardData data, AdminCapabilities rights) =>
      _Panel(
          title: 'Danh mục báo cáo',
          subtitle: 'Các nhóm số liệu hiện có trong kỳ đã chọn.',
          child: Column(children: [
            _ReportRow(
                icon: Icons.people_alt_outlined,
                title: 'Tăng trưởng người dùng',
                value:
                    '${_format(data.growth['accounts']?.current ?? 0)} người mới'),
            _ReportRow(
                icon: Icons.apartment_outlined,
                title: 'Tăng trưởng khu trọ',
                value:
                    '${_format(data.growth['properties']?.current ?? 0)} khu mới'),
            _ReportRow(
                icon: Icons.meeting_room_outlined,
                title: 'Tăng trưởng phòng',
                value:
                    '${_format(data.growth['rooms']?.current ?? 0)} phòng mới'),
            if (rights.has('admin.reports.manage'))
              _ReportRow(
                  icon: Icons.schedule_outlined,
                  title: 'Báo cáo định kỳ',
                  value: 'Mở lịch báo cáo',
                  onTap: () => context.go('/admin/report-schedules')),
          ]));

  Widget _dailyReport(AdminDashboardData data, AdminCapabilities rights) =>
      _Panel(
          title: 'Dữ liệu theo ngày',
          subtitle:
              'Số tài khoản, khu trọ và phòng được tạo mới; ngày không phát sinh vẫn được hiển thị.',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton.icon(
                onPressed: () async {
                  final finance =
                      rights.has('admin.finance.read') && data.finance != null;
                  final lines = <String>[
                    'Ngay,Tai khoan moi,Khu tro moi,Phong moi${finance ? ',Tien thue thu,Tien thue dao,Tien thue rong' : ''}',
                    for (final row in data.trends)
                      '${_iso(row.day)},${row.accounts},${row.properties},${row.rooms}${finance ? ',${row.rentalCollected ?? 0},${row.rentalReversed ?? 0},${row.rentalNet ?? 0}' : ''}',
                  ];
                  await Clipboard.setData(
                      ClipboardData(text: lines.join('\r\n')));
                  if (!mounted || ref.read(sessionIdentityProvider) != _owner) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Đã sao chép dữ liệu CSV của kỳ đang xem.')));
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Sao chép CSV')),
            const SizedBox(height: 10),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Ngày')),
                    DataColumn(label: Text('Tài khoản mới'), numeric: true),
                    DataColumn(label: Text('Khu trọ mới'), numeric: true),
                    DataColumn(label: Text('Phòng mới'), numeric: true)
                  ],
                  rows: [
                    for (final row in data.trends)
                      DataRow(cells: [
                        DataCell(Text('${row.day.day}/${row.day.month}')),
                        DataCell(Text('${row.accounts}')),
                        DataCell(Text('${row.properties}')),
                        DataCell(Text('${row.rooms}'))
                      ])
                  ],
                )),
          ]));
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title,
      required this.subtitle,
      required this.child,
      this.trailing});
  final String title, subtitle;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D23335C), blurRadius: 18, offset: Offset(0, 6))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ])),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 18),
          child,
        ]),
      );
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color, this.growth);
  final String label, value;
  final IconData icon;
  final Color color;
  final AdminMetricGrowth? growth;
}

class _BreakdownValue extends StatelessWidget {
  const _BreakdownValue(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9FD),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(_format(value), style: Theme.of(context).textTheme.titleMedium),
        ]),
      );
}

class _FinanceValue extends StatelessWidget {
  const _FinanceValue(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 180,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(value,
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(color: color))
      ]));
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F7FC),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 18, color: AdminOverviewTheme.muted),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall))
      ]));
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color,
      required this.label,
      required this.valueKey,
      this.value});
  final Color color;
  final String label, valueKey;
  final String? value;
  _Legend copyWith({String? value}) =>
      _Legend(color: color, label: label, valueKey: valueKey, value: value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: AdminOverviewTheme.ink)),
        ])),
      ]));
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(
      {required this.icon,
      required this.title,
      required this.value,
      this.onTap});
  final IconData icon;
  final String title, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AdminOverviewTheme.blue),
      title: Text(title),
      subtitle: Text(value),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap);
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.occupied, this.vacant, this.maintenance);
  final int occupied, vacant, maintenance;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE9EEF7);
    canvas.drawCircle(center, radius, base);
    final total = occupied + vacant + maintenance;
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final slice in [
      (occupied, AdminOverviewTheme.blue),
      (vacant, const Color(0xFFCBD5E7)),
      (maintenance, const Color(0xFFF4B35E)),
    ]) {
      if (slice.$1 == 0) continue;
      final value = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.butt
        ..color = slice.$2;
      final sweep = math.pi * 2 * slice.$1 / total;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          sweep, false, value);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.occupied != occupied ||
      oldDelegate.vacant != vacant ||
      oldDelegate.maintenance != maintenance;
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

String _format(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String _money(int value) => '${_format(value)} đ';
String _iso(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String _date(DateTime date, {bool time = false}) {
  final vietnam = date.toUtc().add(const Duration(hours: 7));
  return '${vietnam.day}/${vietnam.month}/${vietnam.year}'
      '${time ? ' ${vietnam.hour.toString().padLeft(2, '0')}:${vietnam.minute.toString().padLeft(2, '0')}' : ''}';
}
