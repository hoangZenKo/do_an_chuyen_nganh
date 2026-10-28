import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/admin_models.dart';
import '../../models/admin_workspace_models.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_overview_theme.dart';
import 'admin_workspace_navigation.dart';

class AdminOverviewShell extends ConsumerStatefulWidget {
  const AdminOverviewShell(
      {super.key,
      required this.reports,
      required this.rights,
      required this.body,
      required this.refresh,
      this.location,
      this.title,
      this.actions = const [],
      this.floatingActionButton,
      this.searchField,
      this.onCommands,
      this.busy = false,
      this.loadSummary = true,
      this.manageLifecycle = true});
  final bool reports;
  final AdminCapabilities rights;
  final Widget body;
  final VoidCallback refresh;
  final String? location, title;
  final List<Widget> actions;
  final Widget? floatingActionButton, searchField;
  final VoidCallback? onCommands;
  final bool busy, manageLifecycle, loadSummary;
  @override
  ConsumerState<AdminOverviewShell> createState() => _AdminOverviewShellState();
}

class _AdminOverviewShellState extends ConsumerState<AdminOverviewShell>
    with WidgetsBindingObserver {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.manageLifecycle &&
        !widget.busy) {
      widget.refresh();
    }
  }

  String get _location =>
      adminDestinationFor(widget.location ??
              (widget.reports ? '/admin/reports/overview' : '/admin'))
          ?.path ??
      '';
  void _go(String route) => GoRouter.maybeOf(context)?.go(route);

  void _commands() {
    if (widget.busy) return;
    if (widget.onCommands != null) {
      widget.onCommands!();
    } else if (widget.rights.has('admin.dashboard.view')) {
      _go('/admin/search');
    }
  }

  Widget _menu({required bool drawer, AdminWorkspaceSummary? summary}) {
    final menu =
        adminDestinations.where((entry) => entry.allowed(widget.rights));
    return ColoredBox(
        color: Colors.white,
        child: SafeArea(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Padding(
                  padding: EdgeInsets.fromLTRB(24, 28, 20, 26),
                  child: Row(children: [
                    Icon(Icons.apartment_rounded,
                        color: AdminOverviewTheme.blue, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Rental Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800)))
                  ])),
              Expanded(
                  child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                    for (final group
                        in menu.map((entry) => entry.group).toSet()) ...[
                      Padding(
                          padding: const EdgeInsets.fromLTRB(14, 18, 12, 6),
                          child: Text(group,
                              style: Theme.of(context).textTheme.bodySmall)),
                      for (final entry
                          in menu.where((entry) => entry.group == group))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                                key: ValueKey('admin-nav-${entry.path}'),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                selected: entry.path == _location,
                                selectedTileColor: const Color(0xFFEDF1FF),
                                selectedColor: AdminOverviewTheme.blue,
                                leading: Icon(entry.icon, size: 21),
                                title: Text(entry.label,
                                    style: const TextStyle(fontSize: 13)),
                                trailing: (summary?.countFor(entry.path) ?? 0) >
                                        0
                                    ? Badge(
                                        label: Text(
                                            '${summary!.countFor(entry.path)}'))
                                    : null,
                                onTap: () {
                                  if (drawer) Navigator.of(context).pop();
                                  _go(entry.path);
                                })),
                    ],
                  ])),
              const Divider(),
              ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Đăng xuất'),
                  enabled: !widget.busy,
                  onTap: () =>
                      ref.read(sessionControllerProvider.notifier).logout()),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final summaryState =
        widget.loadSummary && widget.rights.has('admin.dashboard.view')
            ? ref.watch(adminWorkspaceSummaryProvider)
            : null;
    final unread = summaryState?.isLoading == false
        ? summaryState?.valueOrNull?.unreadCount
        : null;
    final summary =
        summaryState?.isLoading == false ? summaryState?.valueOrNull : null;
    final user = ref.watch(sessionControllerProvider).session?.user;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      final tabs = <({String path, String label, IconData icon})>[
        if (widget.rights.has('admin.dashboard.view'))
          (path: '/admin', label: 'Tổng quan', icon: Icons.home_outlined),
        if (widget.rights.has('admin.accounts.view'))
          (
            path: '/admin/accounts',
            label: 'Người dùng',
            icon: Icons.people_outline
          ),
        if (widget.rights.has('admin.properties.view'))
          (
            path: '/admin/properties',
            label: 'Khu trọ',
            icon: Icons.apartment_outlined
          ),
        if (widget.rights.has('admin.dashboard.view'))
          (
            path: '/admin/reports/overview',
            label: 'Báo cáo',
            icon: Icons.bar_chart_rounded
          ),
        (path: 'more', label: 'Khác', icon: Icons.more_horiz),
      ];
      if (tabs.length == 1) {
        tabs.insert(0, (
          path: '/admin/security',
          label: 'Bảo mật',
          icon: Icons.security_outlined
        ));
      }
      return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _commands,
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _commands,
          },
          child: Focus(
              autofocus: true,
              child: Scaffold(
                key: _scaffold,
                floatingActionButton: widget.floatingActionButton,
                drawer: wide
                    ? null
                    : Drawer(
                        backgroundColor: Colors.white,
                        child: _menu(drawer: true, summary: summary)),
                bottomNavigationBar: wide
                    ? null
                    : NavigationBar(
                        selectedIndex: tabs.any((tab) => tab.path == _location)
                            ? tabs.indexWhere((tab) => tab.path == _location)
                            : tabs.length - 1,
                        onDestinationSelected: (index) =>
                            tabs[index].path == 'more'
                                ? _scaffold.currentState?.openDrawer()
                                : _go(tabs[index].path),
                        destinations: [
                            for (final tab in tabs)
                              NavigationDestination(
                                  icon: Icon(tab.icon), label: tab.label)
                          ]),
                body: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        SizedBox(
                            width: 252,
                            child: _menu(drawer: false, summary: summary)),
                      if (wide) const VerticalDivider(width: 1),
                      Expanded(
                          child: Column(children: [
                        SafeArea(
                            bottom: false,
                            child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    wide ? 32 : 20, 16, wide ? 32 : 16, 12),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        if (!widget.reports &&
                                            widget.title == null)
                                          Text('Xin chào,',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      color: AdminOverviewTheme
                                                          .muted)),
                                        Text(
                                            widget.title ??
                                                (widget.reports
                                                    ? 'Báo cáo'
                                                    : user?.fullName ??
                                                        'Admin'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall),
                                        if (widget.reports)
                                          Text('Thống kê và phân tích hệ thống',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                      ])),
                                  if (wide &&
                                      widget.rights.has('admin.dashboard.view'))
                                    IconButton(
                                        tooltip: 'Tra cứu toàn hệ thống',
                                        onPressed: () => _go('/admin/search'),
                                        icon: const Icon(Icons.search)),
                                  if (widget.onCommands != null)
                                    IconButton(
                                        tooltip:
                                            'Chuyển nhanh chức năng (Ctrl/Cmd K)',
                                        onPressed: widget.busy
                                            ? null
                                            : widget.onCommands,
                                        icon: const Icon(
                                            Icons.keyboard_command_key)),
                                  IconButton(
                                      tooltip: widget.title == null
                                          ? 'Làm mới tổng quan'
                                          : 'Làm mới workspace',
                                      onPressed:
                                          widget.busy ? null : widget.refresh,
                                      icon: const Icon(Icons.refresh_rounded)),
                                  if (wide) ...widget.actions,
                                  if (widget.rights
                                      .has('admin.notifications.view'))
                                    IconButton(
                                        tooltip: unread == null
                                            ? 'Thông báo'
                                            : 'Thông báo: $unread chưa đọc',
                                        onPressed: () =>
                                            _go('/admin/notifications'),
                                        icon: Badge(
                                            isLabelVisible: (unread ?? 0) > 0,
                                            label: Text('${unread ?? 0}'),
                                            child: const Icon(Icons
                                                .notifications_none_rounded))),
                                  const SizedBox(width: 4),
                                  IconButton(
                                      tooltip: 'Bảo mật tài khoản',
                                      onPressed: () => _go('/admin/security'),
                                      icon: CircleAvatar(
                                          radius: 17,
                                          backgroundColor:
                                              const Color(0xFFE5EBFF),
                                          child: Text(
                                              (user?.fullName
                                                              .trim()
                                                              .isNotEmpty ==
                                                          true
                                                      ? user!.fullName.trim()[0]
                                                      : 'A')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  color:
                                                      AdminOverviewTheme.blue,
                                                  fontWeight:
                                                      FontWeight.w700)))),
                                ]))),
                        if (!wide && widget.actions.isNotEmpty)
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widget.actions)),
                        if (widget.searchField != null)
                          Padding(
                              padding: EdgeInsets.fromLTRB(
                                  wide ? 32 : 16, 0, wide ? 32 : 16, 12),
                              child: widget.searchField!),
                        Expanded(child: widget.body),
                      ])),
                    ]),
              )));
    });
  }
}
