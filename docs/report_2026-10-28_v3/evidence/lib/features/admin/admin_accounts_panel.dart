import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_overview_theme.dart';
import '../../models/admin_models.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_states.dart';

class AdminAccountsPanel extends ConsumerStatefulWidget {
  const AdminAccountsPanel({super.key, this.trailing, this.busy = false});
  final Widget? trailing;
  final bool busy;

  @override
  ConsumerState<AdminAccountsPanel> createState() => _AdminAccountsPanelState();
}

class _AdminAccountsPanelState extends ConsumerState<AdminAccountsPanel> {
  late final String? _owner;
  late final TextEditingController _search;
  Timer? _debounce;

  bool get _active =>
      mounted &&
      _owner != null &&
      ref.read(sessionIdentityProvider) == _owner &&
      ref
              .read(adminCapabilitiesProvider)
              .valueOrNull
              ?.has('admin.accounts.view') ==
          true;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    _search = TextEditingController(
        text: ref.read(adminAccountsQueryProvider).search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _update(AdminAccountsQuery query) {
    if (_active && !widget.busy) {
      ref.read(adminAccountsQueryProvider.notifier).state = query;
    }
  }

  Future<void> _dates(AdminAccountsQuery query) async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Ngày tạo tài khoản (giờ Việt Nam)',
      initialDateRange: query.from == null || query.to == null
          ? null
          : DateTimeRange(
              start: DateTime.parse(query.from!)
                  .toUtc()
                  .add(const Duration(hours: 7)),
              end: DateTime.parse(query.to!)
                  .toUtc()
                  .add(const Duration(hours: 7))),
    );
    if (!_active || range == null) return;
    final start =
        DateTime.utc(range.start.year, range.start.month, range.start.day)
            .subtract(const Duration(hours: 7));
    final end = DateTime.utc(range.end.year, range.end.month, range.end.day + 1)
        .subtract(const Duration(hours: 7, milliseconds: 1));
    _update(ref.read(adminAccountsQueryProvider).copyWith(
        page: 1, from: start.toIso8601String(), to: end.toIso8601String()));
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (owner == null || owner != _owner) return const SizedBox.shrink();
    if (rights.isLoading) return const AdminLoadingState();
    if (rights.hasError) {
      return AdminFailureState(
          error: rights.error!,
          retry: () => ref.invalidate(adminCapabilitiesProvider));
    }
    if (!rights.requireValue.has('admin.accounts.view')) {
      return const WorkflowEmpty('Bạn không có quyền xem tài khoản.');
    }
    final query = ref.watch(adminAccountsQueryProvider);
    final result = ref.watch(adminAccountsProvider(query));
    return AdminSectionPanel(
        icon: Icons.manage_accounts_outlined,
        title: 'Danh mục tài khoản',
        subtitle:
            'Thông tin liên hệ được che mặc định. Hồ sơ người thuê và tài khoản đăng nhập là hai đối tượng khác nhau.',
        trailing: widget.trailing,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = math.min(240.0, constraints.maxWidth);
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: width,
                  child: TextField(
                      key: const ValueKey('account-search'),
                      controller: _search,
                      maxLength: 120,
                      enabled: !widget.busy,
                      decoration: const InputDecoration(
                          labelText: 'Tìm tên, email, số điện thoại',
                          prefixIcon: Icon(Icons.search),
                          counterText: ''),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 350), () {
                          if (_active) {
                            _update(ref
                                .read(adminAccountsQueryProvider)
                                .copyWith(page: 1, search: value.trim()));
                          }
                        });
                      })),
              SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                      key: const ValueKey('account-role'),
                      value: query.role ?? 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Vai trò'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('Tất cả vai trò')),
                        DropdownMenuItem(
                            value: 'LANDLORD', child: Text('Chủ trọ')),
                        DropdownMenuItem(
                            value: 'TENANT', child: Text('Người thuê')),
                        DropdownMenuItem(
                            value: 'STAFF', child: Text('Nhân viên'))
                      ],
                      onChanged: widget.busy
                          ? null
                          : (role) => _update(query.copyWith(
                              page: 1, role: role, clearRole: role == 'all')))),
              SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                      key: const ValueKey('account-status'),
                      value: query.status,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Trạng thái'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('Tất cả trạng thái')),
                        DropdownMenuItem(
                            value: 'active', child: Text('Hoạt động')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Đã khóa'))
                      ],
                      onChanged: widget.busy
                          ? null
                          : (status) => _update(
                              query.copyWith(page: 1, status: status)))),
              SizedBox(
                  width: width,
                  child: OutlinedButton.icon(
                      onPressed: widget.busy ? null : () => _dates(query),
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(query.from == null
                          ? 'Lọc ngày tạo'
                          : '${_date(query.from!)} - ${_date(query.to!)}'))),
              if (query.from != null)
                TextButton(
                    onPressed: widget.busy
                        ? null
                        : () =>
                            _update(query.copyWith(page: 1, clearDates: true)),
                    child: const Text('Bỏ lọc ngày')),
            ]);
          }),
          const SizedBox(height: 16),
          result.when(
              skipLoadingOnRefresh: false,
              loading: () => const AdminLoadingState(),
              error: (error, stack) => AdminFailureState(
                  error: error,
                  retry: () => ref.invalidate(adminAccountsProvider(query))),
              data: (page) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (page.data.isEmpty)
                          const WorkflowEmpty(
                              'Không tìm thấy tài khoản phù hợp.'),
                        for (final account in page.data) _row(account),
                        Wrap(
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                  '${page.total} kết quả · Trang ${page.page}/${math.max(1, page.pages)}'),
                              IconButton(
                                  tooltip: 'Trang trước',
                                  onPressed: !widget.busy && page.page > 1
                                      ? () => _update(
                                          query.copyWith(page: page.page - 1))
                                      : null,
                                  icon: const Icon(Icons.chevron_left)),
                              IconButton(
                                  tooltip: 'Trang sau',
                                  onPressed: !widget.busy &&
                                          page.page < page.pages
                                      ? () => _update(
                                          query.copyWith(page: page.page + 1))
                                      : null,
                                  icon: const Icon(Icons.chevron_right)),
                            ]),
                      ])),
        ]);
  }

  String _date(String value) {
    final date = DateTime.parse(value).toUtc().add(const Duration(hours: 7));
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _row(AdminAccount account) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          color: AdminOverviewTheme.background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.busy
                  ? null
                  : () {
                      _debounce?.cancel();
                      final query = ref.read(adminAccountsQueryProvider);
                      final search = _search.text.trim();
                      if (search != (query.search ?? '')) {
                        _update(query.copyWith(page: 1, search: search));
                      }
                      GoRouter.maybeOf(context)
                          ?.push('/admin/accounts/${account.id}');
                    },
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(
                        account.isActive
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                        color:
                            account.isActive ? AdminOverviewTheme.green : AdminOverviewTheme.red),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(account.fullName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(account.email),
                          Text('${const {
                                'LANDLORD': 'Chủ trọ',
                                'TENANT': 'Người thuê',
                                'STAFF': 'Nhân viên'
                              }[account.role] ?? account.role} · ${account.isActive ? 'Hoạt động' : 'Đã khóa'}'),
                          if (account.createdAt != null)
                            Text(
                                'Ngày tạo: ${_date(account.createdAt!.toIso8601String())}'),
                        ])),
                    const Icon(Icons.chevron_right),
                  ])))));
}
