import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_overview_shell.dart';
import 'admin_overview_theme.dart';
import 'admin_workspace_navigation.dart';
import 'admin_workspace_states.dart';

class AdminWorkspaceScaffold extends ConsumerStatefulWidget {
  const AdminWorkspaceScaffold(
      {super.key,
      required this.title,
      required this.body,
      required this.location,
      this.enabled = true,
      this.actions = const [],
      this.floatingActionButton,
      this.busy = false,
      this.canOpen = true,
      this.onRefresh});
  final String title, location;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;
  final bool enabled, busy, canOpen;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<AdminWorkspaceScaffold> createState() =>
      _AdminWorkspaceScaffoldState();
}

class _AdminWorkspaceScaffoldState extends ConsumerState<AdminWorkspaceScaffold>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  late final String? _owner;
  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enabled && _active) {
      _refresh();
    }
  }

  void _refresh() {
    if (!_active || widget.busy) return;
    refreshAdminWorkspace(ref);
    ref.invalidate(adminOverviewProvider);
    ref.invalidate(adminLandlordsProvider);
    ref.invalidate(adminPropertiesProvider);
    widget.onRefresh?.call();
  }

  void _go(String route) {
    if (!_active) return;
    GoRouter.maybeOf(context)?.go(route);
  }

  void _submitSearch(String input) {
    final query = input.trim();
    if (query.length < 2 || query.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập từ 2 đến 100 ký tự để tra cứu.')));
      return;
    }
    if (ref
            .read(adminCapabilitiesProvider)
            .valueOrNull
            ?.has('admin.dashboard.view') !=
        true) {
      return;
    }
    _go(Uri(path: adminSearchRoute, queryParameters: {'q': query}).toString());
  }

  Future<void> _commands() async {
    if (!_active) return;
    final route = await showDialog<String>(
        context: context, builder: (_) => const _AdminCommandDialog());
    if (!_active || route == null) return;
    final destination = adminDestinationFor(route);
    final rights = ref.read(adminCapabilitiesProvider).valueOrNull;
    if (destination != null && rights != null && destination.allowed(rights)) {
      _go(route);
    }
  }

  Widget _searchField() => TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitSearch,
        decoration: InputDecoration(
            isDense: true,
            hintText: 'Tra cứu tên, mã ticket, hóa đơn…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: () => _submitSearch(_search.text),
                icon: const Icon(Icons.arrow_forward, size: 18))),
      );

  @override
  Widget build(BuildContext context) => Theme(
      data: AdminOverviewTheme.light,
      child: Builder(builder: (context) {
        if (!widget.enabled) {
          return Scaffold(
              appBar:
                  AppBar(title: Text(widget.title), actions: widget.actions),
              body: widget.body,
              floatingActionButton: widget.floatingActionButton);
        }
        ref.watch(sessionIdentityProvider);
        if (!_active) {
          return const Scaffold(
              body: SafeArea(
                  child: Center(
                      child: Text(
                          'Phiên đã thay đổi. Vui lòng mở lại trang quản trị.'))));
        }
        final capabilities = ref.watch(adminCapabilitiesProvider);
        return capabilities.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: const AdminLoadingState(light: true)),
            error: (error, _) => Scaffold(
                appBar: AppBar(title: Text(widget.title)),
                body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: AdminFailureState(
                        light: true,
                        error: error,
                        retry: () =>
                            ref.invalidate(adminCapabilitiesProvider)))),
            data: (rights) {
              final destination = adminDestinationFor(widget.location);
              final allowed =
                  widget.canOpen && (destination?.allowed(rights) ?? true);
              return AdminOverviewShell(
                  reports: false,
                  rights: rights,
                  location: widget.location,
                  title: widget.title,
                  busy: widget.busy,
                  loadSummary: allowed,
                  manageLifecycle: false,
                  refresh: _refresh,
                  onCommands: _commands,
                  searchField: rights.has('admin.dashboard.view')
                      ? _searchField()
                      : null,
                  actions: widget.actions,
                  floatingActionButton:
                      allowed ? widget.floatingActionButton : null,
                  body: allowed
                      ? widget.body
                      : const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: Text(
                                  'Bạn không có quyền mở chức năng này.'))));
            });
      }));
}

class _AdminCommandDialog extends ConsumerStatefulWidget {
  const _AdminCommandDialog();
  @override
  ConsumerState<_AdminCommandDialog> createState() =>
      _AdminCommandDialogState();
}

class _AdminCommandDialogState extends ConsumerState<_AdminCommandDialog> {
  String _query = '';
  late final _owner = ref.read(sessionIdentityProvider);
  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(sessionIdentityProvider);
    final capabilities = ref.watch(adminCapabilitiesProvider);
    final rights = capabilities.isLoading ? null : capabilities.valueOrNull;
    final items = identity == _owner && identity != null && rights != null
        ? adminDestinations
            .where((entry) =>
                entry.allowed(rights) &&
                '${entry.label} ${entry.group}'
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList()
        : <AdminDestination>[];
    return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminOverviewTheme.line),
        ),
        title: const Text('Chuyển nhanh chức năng'),
        content: SizedBox(
            width: 520,
            height: 380,
            child: Column(children: [
              TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Tìm chức năng',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() => _query = value),
                  onSubmitted: (value) {
                    final currentRights =
                        ref.read(adminCapabilitiesProvider).valueOrNull;
                    if (ref.read(sessionIdentityProvider) != _owner ||
                        currentRights == null) {
                      return;
                    }
                    final match = adminDestinations
                        .where((entry) =>
                            entry.allowed(currentRights) &&
                            '${entry.label} ${entry.group}'
                                .toLowerCase()
                                .contains(value.trim().toLowerCase()))
                        .firstOrNull;
                    if (match != null) {
                      Navigator.pop(context, match.path);
                    }
                  }),
              const SizedBox(height: 12),
              Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: Text(
                              'Không có chức năng phù hợp với quyền hiện tại.'))
                      : ListView(children: [
                          for (final item in items)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AdminOverviewTheme.line),
                              ),
                              child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  leading: Icon(
                                    item.icon,
                                    color: AdminOverviewTheme.blue,
                                    size: 20,
                                  ),
                                  title: Text(
                                    item.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    item.group,
                                    style: const TextStyle(
                                        color: AdminOverviewTheme.muted,
                                        fontSize: 12),
                                  ),
                                  trailing: const Icon(
                                    Icons.keyboard_return,
                                    size: 16,
                                    color: AdminOverviewTheme.muted,
                                  ),
                                  onTap: () =>
                                      Navigator.pop(context, item.path)),
                            )
                        ])),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'))
        ]);
  }
}
