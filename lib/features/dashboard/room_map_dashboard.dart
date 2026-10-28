import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/format.dart';
import '../../models/dashboard.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../rooms/room_providers.dart';
import '../rooms/widgets/room_image.dart';
import 'dashboard_providers.dart';
import 'widgets/room_floor_scene.dart';

const _ink = Color(0xFF102039);
const _muted = Color(0xFF62728B);
const _red = Color(0xFFE8324A);

class RoomMapDashboard extends ConsumerStatefulWidget {
  const RoomMapDashboard(
      {super.key,
      required this.onNavigateTab,
      required this.onShowStatistics,
      this.statisticsSlivers,
      this.statisticsKey,
      this.enablePolling = true});
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onShowStatistics;
  final List<Widget>? statisticsSlivers;
  final Key? statisticsKey;
  final bool enablePolling;

  @override
  ConsumerState<RoomMapDashboard> createState() => _RoomMapDashboardState();
}

class _RoomMapDashboardState extends ConsumerState<RoomMapDashboard>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enablePolling) _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enablePolling) return;
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      if (ModalRoute.of(context)?.isCurrent != false) unawaited(_refresh());
    } else {
      _pollTimer?.cancel();
    }
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    final session = ref.read(sessionControllerProvider).session;
    if (!sessionHasAnyPermission(session, const [
      'property.view',
      'property.manage',
      'room.view',
      'room.manage'
    ])) {
      return;
    }
    final properties = ref.read(propertiesProvider);
    if (properties.isLoading) return;
    final selected = ref.read(selectedPropertyProvider);
    final items = properties.valueOrNull ?? const <Property>[];
    final property = items.isEmpty
        ? null
        : items.firstWhere((item) => item.id == selected,
            orElse: () => items.first);
    _refreshing = true;
    final pending = <Future<void>>[];
    void queue(Future<Object?> request) {
      pending.add(request.then<void>((_) {}, onError: (Object _) {}));
    }

    try {
      ref.invalidate(propertiesProvider);
      queue(ref.read(propertiesProvider.future));
      if (property != null && !ref.read(roomsProvider(property.id)).isLoading) {
        ref.invalidate(roomsProvider(property.id));
        queue(ref.read(roomsProvider(property.id).future));
      }
      if (sessionHasAnyPermission(
              session, const ['billing.view', 'billing.create']) &&
          !ref.read(dashboardMetricsProvider).isLoading) {
        ref.invalidate(dashboardMetricsProvider);
        queue(ref.read(dashboardMetricsProvider.future));
      }
      await Future.wait(pending);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    final canViewRooms = sessionHasAnyPermission(session,
        const ['property.view', 'property.manage', 'room.view', 'room.manage']);
    final propertiesAsync = canViewRooms ? ref.watch(propertiesProvider) : null;
    final properties = propertiesAsync?.valueOrNull ?? const <Property>[];
    final selectedId = ref.watch(selectedPropertyProvider);
    final property = properties.isEmpty
        ? null
        : properties.firstWhere((item) => item.id == selectedId,
            orElse: () => properties.first);
    final roomsAsync = property == null
        ? const AsyncData<List<Room>>([])
        : ref.watch(roomsProvider(property.id));
    final canViewBilling = sessionHasAnyPermission(
        session, const ['billing.view', 'billing.create']);
    final metrics = canViewBilling ? ref.watch(dashboardMetricsProvider) : null;
    final attention = <String, DashboardAttentionItem>{};
    for (final item in metrics?.valueOrNull?.attentionItems ??
        const <DashboardAttentionItem>[]) {
      if (item.kind != DashboardAttentionKind.overdueInvoice ||
          (item.propertyId != null && item.propertyId != property?.id)) {
        continue;
      }
      final previous = attention[item.roomId];
      if (previous == null ||
          (item.dueDate != null &&
              (previous.dueDate == null ||
                  item.dueDate!.isBefore(previous.dueDate!)))) {
        attention[item.roomId] = item;
      }
    }
    final fullName = session?.user.fullName.trim() ?? '';
    final name = fullName.isEmpty ? 'bạn' : fullName.split(RegExp(r'\s+')).last;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Theme(
      data: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: _ink)),
      child: Builder(
          builder: (context) => RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                        child: _PageWidth(
                            child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: PopupMenuButton<String>(
                                  tooltip: 'Chọn khu trọ',
                                  enabled: properties.length > 1,
                                  initialValue: property?.id,
                                  onSelected: (id) => ref
                                      .read(selectedPropertyProvider.notifier)
                                      .state = id,
                                  itemBuilder: (_) => [
                                    for (final item in properties)
                                      PopupMenuItem(
                                          value: item.id,
                                          child: Text(item.name))
                                  ],
                                  child: Row(children: [
                                    Flexible(
                                        child: Text(
                                            property?.name ?? 'Khu trọ của bạn',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: _ink,
                                                fontSize: (23 / textScale)
                                                    .clamp(16, 23),
                                                letterSpacing: -.7,
                                                fontWeight: FontWeight.w800))),
                                    if (properties.length > 1)
                                      const Icon(Icons.expand_more,
                                          color: _ink),
                                  ]),
                                )),
                                IconButton.filledTonal(
                                    tooltip: 'Thông báo',
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _ink),
                                    onPressed: () =>
                                        context.push(notificationsRoute),
                                    icon: const Icon(
                                        Icons.notifications_none_rounded)),
                                const SizedBox(width: 6),
                                IconButton(
                                    tooltip: 'Tài khoản',
                                    onPressed: () =>
                                        context.push(settingsRoute),
                                    icon: CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFFE6DDD1),
                                        foregroundColor: _ink,
                                        child: Text(name.characters.first
                                            .toUpperCase()))),
                              ]),
                              const SizedBox(height: 6),
                              Text('${_greeting()}, $name',
                                  style: const TextStyle(
                                      color: _muted, fontSize: 14)),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .75),
                                    borderRadius: BorderRadius.circular(18)),
                                child: Row(children: [
                                  _ViewTab(
                                      icon: Icons.view_in_ar_outlined,
                                      label: 'Sơ đồ phòng',
                                      selected: true,
                                      onTap: () {}),
                                  _ViewTab(
                                      icon: Icons.format_list_bulleted,
                                      label: 'Danh sách',
                                      onTap: canViewRooms
                                          ? () => widget.onNavigateTab(1)
                                          : null),
                                  _ViewTab(
                                      icon: Icons.bar_chart_rounded,
                                      label: 'Thống kê',
                                      onTap: widget.onShowStatistics),
                                ]),
                              ),
                              const SizedBox(height: 10),
                            ]),
                      ),
                    ))),
                    SliverToBoxAdapter(
                        child: _PageWidth(
                            child: !canViewRooms
                                ? const _LoadState(
                                    message: 'Bạn chưa có quyền xem phòng.')
                                : propertiesAsync!.isLoading &&
                                        !propertiesAsync.hasValue
                                    ? const _LoadState()
                                    : propertiesAsync.hasError &&
                                            !propertiesAsync.hasValue
                                        ? _LoadState(
                                            message: 'Không thể tải khu trọ.',
                                            retry: () => ref
                                                .invalidate(propertiesProvider))
                                        : property == null
                                            ? const _LoadState(
                                                message:
                                                    'Chưa có khu trọ. Thêm khu trọ để xem sơ đồ.')
                                            : roomsAsync.when(
                                                skipError: roomsAsync.hasValue,
                                                loading: () =>
                                                    const _LoadState(),
                                                error: (_, __) => _LoadState(
                                                    message:
                                                        'Không thể tải danh sách phòng.',
                                                    retry: () => ref.invalidate(
                                                        roomsProvider(
                                                            property.id))),
                                                data: (rooms) => _FloorContent(
                                                  key: ValueKey(property.id),
                                                  rooms: rooms
                                                      .where((room) =>
                                                          room.isActive)
                                                      .toList(),
                                                  attention: attention,
                                                  roomsUnavailable: roomsAsync
                                                          .hasError ||
                                                      propertiesAsync.hasError,
                                                  billingUnavailable:
                                                      metrics?.hasError == true,
                                                  billingLoading: metrics
                                                              ?.isLoading ==
                                                          true &&
                                                      metrics?.hasValue != true,
                                                  retryBilling: () =>
                                                      ref.invalidate(
                                                          dashboardMetricsProvider),
                                                ),
                                              ))),
                    if (widget.statisticsSlivers != null)
                      ...widget.statisticsSlivers!,
                    const SliverToBoxAdapter(
                        child: SizedBox(
                            key: ValueKey('dashboard-bottom-clearance'),
                            height: 180)),
                  ],
                ),
              )),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
            ? 'Chào buổi chiều'
            : 'Chào buổi tối';
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100), child: child));
}

class _ViewTab extends StatelessWidget {
  const _ViewTab(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(
          child: Semantics(
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
              backgroundColor: selected ? _ink : Colors.transparent,
              foregroundColor: selected ? Colors.white : _muted,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15))),
          onPressed: onTap,
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 90 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final children = [
              Icon(icon, size: 18),
              SizedBox(width: narrow ? 0 : 5, height: narrow ? 4 : 0),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600))
            ];
            return FittedBox(
                fit: BoxFit.scaleDown,
                child: narrow
                    ? Column(mainAxisSize: MainAxisSize.min, children: children)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: children));
          }),
        ),
      ));
}

class _FloorContent extends StatefulWidget {
  const _FloorContent(
      {super.key,
      required this.rooms,
      required this.attention,
      required this.roomsUnavailable,
      required this.billingUnavailable,
      required this.billingLoading,
      required this.retryBilling});
  final List<Room> rooms;
  final Map<String, DashboardAttentionItem> attention;
  final bool roomsUnavailable;
  final bool billingUnavailable;
  final bool billingLoading;
  final VoidCallback retryBilling;
  @override
  State<_FloorContent> createState() => _FloorContentState();
}

class _FloorContentState extends State<_FloorContent> {
  String? _floor;
  String? _selectedId;
  int _page = 0;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rooms.isEmpty) {
      return const _LoadState(
          message: 'Chưa có phòng. Nhấn + để thêm phòng mới.');
    }
    final floors = widget.rooms.map(_floorKey).toSet().toList()
      ..sort((first, second) => (int.tryParse(first) ?? 99999)
          .compareTo(int.tryParse(second) ?? 99999));
    final currentFloor = floors.contains(_floor)
        ? _floor!
        : floors.contains('2')
            ? '2'
            : floors.first;
    final rooms = widget.rooms
        .where((room) => _floorKey(room) == currentFloor)
        .toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    final pageCount = (rooms.length / 7).ceil();
    final page = _page.clamp(0, pageCount - 1);
    final pageRooms = rooms.skip(page * 7).take(7).toList();
    final selected = pageRooms.firstWhere((room) => room.id == _selectedId,
        orElse: () => pageRooms.firstWhere(
            (room) => widget.attention.containsKey(room.id),
            orElse: () => pageRooms.first));
    final otherRooms = rooms.where((room) => room.id != selected.id).toList();
    final floorLabel =
        currentFloor == 'unknown' ? 'Chưa gán tầng' : 'Tầng $currentFloor';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Chọn tầng',
                initialValue: currentFloor,
                onSelected: (floor) => setState(() {
                  _floor = floor;
                  _selectedId = null;
                  _page = 0;
                }),
                itemBuilder: (_) => [
                  for (final floor in floors)
                    PopupMenuItem(
                        value: floor,
                        child: Text(floor == 'unknown'
                            ? 'Chưa gán tầng'
                            : 'Tầng $floor'))
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(floorLabel,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                    const SizedBox(width: 7),
                    const Icon(Icons.expand_more, size: 18, color: _ink),
                  ]),
                ),
              ),
              const Wrap(spacing: 9, runSpacing: 8, children: [
                _Legend(color: Color(0xFF00A77F), label: 'Đang ở'),
                _Legend(color: Color(0xFFA9B4C7), label: 'Trống'),
                _Legend(color: Color(0xFFF58B16), label: 'Bảo trì'),
                _Legend(color: _red, label: 'Quá hạn'),
              ]),
            ]),
      ),
      if (widget.roomsUnavailable)
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Text(
                'Mất kết nối. Đang hiển thị dữ liệu phòng gần nhất; kéo xuống để thử lại.',
                style: TextStyle(color: _muted, fontSize: 12))),
      if (widget.billingUnavailable)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TextButton.icon(
                onPressed: widget.retryBilling,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Thanh toán chưa cập nhật. Thử lại'))),
      if (widget.billingLoading)
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Đang kiểm tra tình trạng thanh toán…',
                style: TextStyle(color: _muted))),
      const SizedBox(height: 8),
      RoomFloorScene(
          key: ValueKey('$currentFloor:$page'),
          rooms: pageRooms,
          overdueIds: widget.attention.keys.toSet(),
          selectedId: selected.id,
          onSelected: (id) => setState(() => _selectedId = id)),
      if (pageCount > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: 'Nhóm phòng trước',
              onPressed: page > 0
                  ? () => setState(() {
                        _page = page - 1;
                        _selectedId = null;
                      })
                  : null,
              icon: const Icon(Icons.chevron_left)),
          Text('Nhóm ${page + 1}/$pageCount'),
          IconButton(
              tooltip: 'Nhóm phòng sau',
              onPressed: page < pageCount - 1
                  ? () => setState(() {
                        _page = page + 1;
                        _selectedId = null;
                      })
                  : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
      Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: _SelectedRoom(
              room: selected, attention: widget.attention[selected.id])),
      if (otherRooms.isNotEmpty) ...[
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text('Phòng khác trong ${floorLabel.toLowerCase()}',
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: () =>
                                    setState(() => _showAll = !_showAll),
                                child:
                                    Text(_showAll ? 'Thu gọn' : 'Xem tất cả'))),
                      ])
                : Row(children: [
                    Expanded(
                        child: Text(
                            'Phòng khác trong ${floorLabel.toLowerCase()}',
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800))),
                    TextButton(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        child: Text(_showAll ? 'Thu gọn' : 'Xem tất cả')),
                  ])),
        const SizedBox(height: 8),
        if (_showAll)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                for (final room in otherRooms)
                  ListTile(
                      title: Text(room.name),
                      subtitle: Text(formatCurrencyVnd(room.basePrice)),
                      leading: Icon(Icons.bed_outlined,
                          color: roomSceneColor(
                              room, widget.attention.containsKey(room.id))),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(roomDetailPath(room.id))),
              ]))
        else
          SizedBox(
              height: 190 +
                  (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 3) *
                      220,
              child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: otherRooms.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => _RoomCard(
                      width: MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? 180
                          : ((MediaQuery.sizeOf(context).width - 64) / 3)
                              .clamp(90, 200),
                      room: otherRooms[index],
                      overdue:
                          widget.attention.containsKey(otherRooms[index].id)))),
      ],
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
              'Cảnh 3D minh họa · ${rooms.length} phòng trong ${floorLabel.toLowerCase()}\nDữ liệu tự làm mới mỗi 15 giây · Kéo xuống để cập nhật',
              style:
                  const TextStyle(fontSize: 10, height: 1.6, color: _muted))),
    ]);
  }

  String _floorKey(Room room) => room.floor?.toString() ?? 'unknown';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _ink, fontSize: 10)),
      ]);
}

class _SelectedRoom extends StatelessWidget {
  const _SelectedRoom({required this.room, this.attention});
  final Room room;
  final DashboardAttentionItem? attention;
  @override
  Widget build(BuildContext context) {
    final tenant = attention?.tenantName ?? room.tenantName;
    final dueDate = attention?.dueDate?.toLocal();
    final now = DateTime.now();
    final days = dueDate == null
        ? 0
        : DateTime.utc(now.year, now.month, now.day)
            .difference(DateTime.utc(dueDate.year, dueDate.month, dueDate.day))
            .inDays;
    final overdue = attention != null;
    final action = FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: overdue ? _red : _ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            minimumSize: const Size(56, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        onPressed: () => context.push(overdue && attention!.invoiceId != null
            ? billingDetailPath(attention!.invoiceId!)
            : roomDetailPath(room.id)),
        child: Text(
            overdue && attention!.invoiceId != null ? 'Xử lý' : 'Chi tiết'));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white,
            overdue ? const Color(0xFFFFEDEF) : const Color(0xFFF8FAFC)
          ]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x09102039), blurRadius: 24, offset: Offset(0, 8))
          ]),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 72, height: 76, child: _RoomPhoto(room: room))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${room.name}${tenant?.isNotEmpty == true ? ' · $tenant' : ''}',
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text('${formatCurrencyVnd(room.basePrice)}/tháng',
                      style: const TextStyle(color: _ink, fontSize: 12)),
                  const SizedBox(height: 7),
                  Text(
                      overdue
                          ? days > 0
                              ? 'Quá hạn thanh toán $days ngày'
                              : 'Hóa đơn quá hạn'
                          : room.status.label,
                      style: TextStyle(
                          color: overdue ? _red : _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ])),
            if (!compact) ...[const SizedBox(width: 6), action],
          ]),
          if (compact)
            Align(
                alignment: Alignment.centerRight,
                child: Padding(
                    padding: const EdgeInsets.only(top: 8), child: action)),
        ]);
      }),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard(
      {required this.room, required this.overdue, required this.width});
  final Room room;
  final bool overdue;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: () => context.push(roomDetailPath(room.id)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  height: 66,
                  width: double.infinity,
                  child: _RoomPhoto(room: room)),
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                        Text(formatCurrencyVnd(room.basePrice),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _ink, fontSize: 10)),
                        const SizedBox(height: 7),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                                color: roomSceneColor(room, overdue)
                                    .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(overdue ? 'Quá hạn' : room.status.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _ink, fontSize: 10))),
                      ])),
            ])),
      ));
}

class _RoomPhoto extends StatelessWidget {
  const _RoomPhoto({required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) => RoomImageView(
      source: RoomImageCatalog.imageFor(room),
      placeholder: const ColoredBox(
          color: Color(0xFFE0E5EC),
          child: Icon(Icons.bed_outlined, color: _muted)));
}

class _LoadState extends StatelessWidget {
  const _LoadState({this.message, this.retry});
  final String? message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (message == null)
          const CircularProgressIndicator()
        else ...[
          const Icon(Icons.domain_outlined, size: 44, color: _muted),
          const SizedBox(height: 16),
          Text(message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 16)),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ])));
}
