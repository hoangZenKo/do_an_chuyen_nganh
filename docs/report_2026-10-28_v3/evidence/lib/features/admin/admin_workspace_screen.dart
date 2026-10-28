import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_production_panels.dart';
import 'admin_step_up.dart';
import 'admin_access_review_panel.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_navigation.dart';
import 'admin_workspace_states.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_overview_page.dart';
import 'admin_accounts_panel.dart';
import 'admin_account_detail_panel.dart';

Map<String, dynamic> _data(Map<String, dynamic> response) =>
    Map<String, dynamic>.from(response['data'] as Map);
List<Map<String, dynamic>> _rows(Map<String, dynamic> response) =>
    (response['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
String _date(Object? raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  return date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _roleLabel(Object? role) =>
    const {
      'LANDLORD': 'Chủ trọ',
      'TENANT': 'Người thuê / người tìm phòng',
      'STAFF': 'Nhân viên',
      'ADMIN': 'Admin'
    }[role] ??
    '$role';

class AdminWorkspaceScreen extends ConsumerStatefulWidget {
  const AdminWorkspaceScreen(
      {super.key,
      this.section = 'dashboard',
      this.accountId,
      this.initialFilters = const {}});
  final String section;
  final String? accountId;
  final Map<String, String> initialFilters;
  @override
  ConsumerState<AdminWorkspaceScreen> createState() =>
      _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends ConsumerState<AdminWorkspaceScreen> {
  final _search = TextEditingController();
  final _contextId = TextEditingController();
  final _contextReason = TextEditingController();
  Timer? _debounce;
  String? _owner;
  String _searchValue = '',
      _role = 'all',
      _status = 'all',
      _kind = 'LISTING',
      _assignment = 'all',
      _priority = 'all',
      _contextKind = 'account';
  int _page = 1;
  bool _busy = false, _overdue = false;
  String? _failure;
  Map<String, dynamic>? _contextResult;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
    if (widget.section == 'moderation') {
      _searchValue = widget.initialFilters['search'] ?? '';
      _search.text = _searchValue;
    }
  }

  @override
  void didUpdateWidget(covariant AdminWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.accountId != widget.accountId ||
        (widget.section == 'moderation' &&
            oldWidget.initialFilters['search'] !=
                widget.initialFilters['search'])) {
      _debounce?.cancel();
      _page = 1;
      _searchValue = widget.section == 'moderation'
          ? widget.initialFilters['search'] ?? ''
          : '';
      _search.text = _searchValue;
      _contextResult = null;
      _failure = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _contextId.dispose();
    _contextReason.dispose();
    super.dispose();
  }

  bool get _active =>
      mounted && _owner != null && ref.read(sessionIdentityProvider) == _owner;
  bool _has(String permission) =>
      ref.read(adminCapabilitiesProvider).valueOrNull?.has(permission) ?? false;

  Future<Map<String, dynamic>?> _command(
      String path, Map<String, dynamic> payload,
      {bool patch = false}) async {
    if (!_active || _busy) return null;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final response = await ref.read(adminApiProvider).authorizedCommand(
          path, payload,
          patch: patch,
          prompt: () => promptAdminStepUp(context, () => _active));
      if (!mounted || !_active) return null;
      refreshAdminWorkspace(ref);
      if (path.startsWith('/admin/listings/')) {
        ref.invalidate(adminRoomsProvider);
        ref.invalidate(adminPropertyDetailProvider);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã ghi nhận thao tác.')));
      return response;
    } catch (error) {
      if (_active) setState(() => _failure = '$error');
      return null;
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Widget _resource(
      AdminRequest request, Widget Function(Map<String, dynamic>) builder) {
    final value = ref.watch(adminWorkspaceResourceProvider(request));
    return value.when(
        skipLoadingOnRefresh: false,
        loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator())),
        error: (error, _) => AdminFailureState(
            error: error,
            retry: () {
              ref.invalidate(adminResourceProvider(request));
              ref.invalidate(adminWorkspaceResourceProvider(request));
            }),
        data: builder);
  }

  Widget _pagination(Map<String, dynamic> response) {
    final meta = response['meta'] as Map? ?? const {};
    final total = (meta['total'] as num?)?.toInt() ?? 0;
    final limit = (meta['limit'] as num?)?.toInt() ?? 20;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AdminOverviewTheme.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminOverviewTheme.line),
        ),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$total kết quả · Trang $_page',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: 'Trang trước',
              visualDensity: VisualDensity.compact,
              onPressed:
                  _page > 1 && !_busy ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Trang sau',
              visualDensity: VisualDensity.compact,
              onPressed: _page * limit < total && !_busy
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _select(String label, String value, Map<String, String> options,
          ValueChanged<String> change) =>
      SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(labelText: label, isDense: true),
              isExpanded: true,
              items: options.entries
                  .map((item) => DropdownMenuItem(
                      value: item.key,
                      child: Text(item.value, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (next) {
                      if (next != null) {
                        setState(() {
                          change(next);
                          _page = 1;
                        });
                      }
                    }));

  Widget _searchBox() => SizedBox(
      width: 340,
      child: TextField(
          controller: _search,
          decoration: const InputDecoration(
              isDense: true,
              labelText: 'Tìm kiếm',
              hintText: 'Tên, email, số điện thoại hoặc mã',
              prefixIcon: Icon(Icons.search)),
          onChanged: (value) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              if (_active) {
                setState(() {
                  _searchValue = value.trim();
                  _page = 1;
                });
              }
            });
          }));

  @override
  Widget build(BuildContext context) {
    if (widget.section == 'dashboard' && widget.accountId == null) {
      return const AdminOverviewPage();
    }
    final identity = ref.watch(sessionIdentityProvider);
    if (_owner != identity || identity == null) {
      return const Scaffold(
          body: Center(
              child:
                  Text('Phiên đã thay đổi. Vui lòng mở lại trang quản trị.')));
    }
    final capabilities = ref.watch(adminCapabilitiesProvider);
    final current = widget.accountId != null
        ? adminAccountsRoute
        : GoRouterState.of(context).uri.path;
    final title = widget.accountId != null
        ? 'Chi tiết tài khoản'
        : adminDestinationFor(current)?.label ?? 'Quản trị nền tảng';
    return AdminWorkspaceScaffold(
        title: title,
        location: current,
        busy: _busy,
        body: capabilities.when(
            skipLoadingOnRefresh: false,
            loading: () => const AdminLoadingState(),
            error: (error, _) => AdminFailureState(
                error: error,
                retry: () => ref.invalidate(adminCapabilitiesProvider)),
            data: (rights) {
              final allowed =
                  adminDestinationFor(current)?.allowed(rights) ?? false;
              if (!allowed) return const SizedBox.shrink();
              return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1160),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(4)),
                                      child:
                                          LinearProgressIndicator(minHeight: 3),
                                    ),
                                  ),
                                if (_failure != null) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AdminOverviewTheme.red
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AdminOverviewTheme.red
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: AdminOverviewTheme.red,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              _failure!,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (widget.accountId != null)
                                  _accountDetail(widget.accountId!)
                                else if (widget.section == 'accounts' ||
                                    widget.section == 'admins')
                                  _accounts(admins: widget.section == 'admins')
                                else if (widget.section == 'audit')
                                  AdminAuditPanel(
                                      initialFilters: widget.initialFilters)
                                else if (widget.section == 'operations')
                                  AdminOperationsPanel(
                                      initialFilters: widget.initialFilters)
                                else if (widget.section == 'support')
                                  _support()
                                else if (widget.section == 'moderation')
                                  _moderation(rights.permissions)
                                else
                                  const Text(
                                      'Không tìm thấy chức năng quản trị.'),
                              ]))));
            }));
  }

  Widget _accounts({required bool admins}) => !admins
      ? AdminAccountsPanel(
          busy: _busy,
          trailing: _has('admin.accounts.manage')
              ? FilledButton.icon(
                  onPressed: _busy ? null : () => _invite(false),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Gửi lời mời'))
              : null)
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AdminSectionPanel(
            icon: admins
                ? Icons.admin_panel_settings_outlined
                : Icons.manage_accounts_outlined,
            title: admins ? 'Quản trị viên hệ thống' : 'Danh mục tài khoản',
            subtitle: admins
                ? 'Quyền admin chỉ thay đổi sau xác thực MFA.'
                : 'Thông tin liên hệ được che mặc định. Hồ sơ người thuê và tài khoản đăng nhập là hai đối tượng khác nhau.',
            trailing:
                _has(admins ? 'admin.admins.manage' : 'admin.accounts.manage')
                    ? FilledButton.icon(
                        onPressed: _busy ? null : () => _invite(admins),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Gửi lời mời'))
                    : null,
            children: [
              AdminToolbarPanel(
                children: [
                  _searchBox(),
                  if (!admins)
                    _select(
                        'Vai trò',
                        _role,
                        const {
                          'all': 'Tất cả',
                          'LANDLORD': 'Chủ trọ',
                          'TENANT': 'Người thuê',
                          'STAFF': 'Nhân viên'
                        },
                        (value) => _role = value),
                  _select(
                      'Trạng thái',
                      _status,
                      const {
                        'all': 'Tất cả',
                        'active': 'Hoạt động',
                        'inactive': 'Đã khóa'
                      },
                      (value) => _status = value),
                ],
              ),
              _resource(
                  AdminRequest(admins ? '/admin/admins' : '/admin/accounts', {
                    'page': _page,
                    'limit': 20,
                    'search': _searchValue,
                    'status': _status,
                    if (!admins && _role != 'all') 'role': _role
                  }),
                  (response) => Column(children: [
                        if (_rows(response).isEmpty)
                          const WorkflowEmpty(
                              'Không tìm thấy tài khoản phù hợp.'),
                        for (final row in _rows(response))
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AdminOverviewTheme.background
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AdminOverviewTheme.line),
                            ),
                            child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: (row['isActive'] == true
                                            ? AdminOverviewTheme.green
                                            : AdminOverviewTheme.red)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    row['isActive'] == true
                                        ? Icons.person_outline
                                        : Icons.person_off_outlined,
                                    color: row['isActive'] == true
                                        ? AdminOverviewTheme.green
                                        : AdminOverviewTheme.red,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '${row['fullName']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                    '${row['email']}\n${admins ? row['preset'] ?? 'Chưa cấp quyền' : _roleLabel(row['role'])} · ${row['isActive'] == true ? 'Hoạt động' : 'Đã khóa'}'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _busy
                                    ? null
                                    : () => admins
                                        ? _editAdmin(row)
                                        : context.push(
                                            '/admin/accounts/${row['id']}')),
                          ),
                        _pagination(response),
                      ])),
            ],
          ),
          if (admins) ...[
            const SizedBox(height: 20),
            const AdminAccessReviewPanel(),
          ],
        ]);

  Widget _accountDetail(String id) =>
      AdminAccountDetailPanel(key: ValueKey(id), accountId: id);

  Future<void> _invite(bool admin) async {
    final result = await _form(admin ? 'Mời nhân sự admin' : 'Mời chủ trọ', [
      const _AdminField('fullName', 'Họ và tên', minimum: 2),
      const _AdminField('email', 'Email', email: true),
      if (admin)
        const _AdminField('preset', 'Vai trò admin',
            initial: 'support',
            choices: {
              'support': 'Hỗ trợ',
              'moderator': 'Kiểm duyệt',
              'analyst': 'Phân tích'
            }),
      if (admin)
        const _AdminField('mfaCode', 'Mã MFA mới hoặc mã khôi phục',
            minimum: 6, secret: true),
      const _AdminField('reason', 'Lý do mời / hồ sơ liên quan',
          minimum: 10, multiline: true),
    ]);
    if (result != null) {
      await _command('/admin/account-invites',
          {...result, 'role': admin ? 'ADMIN' : 'LANDLORD'});
    }
  }

  Future<void> _editAdmin(Map<String, dynamic> row) async {
    if (row['id'] == _owner) {
      setState(
          () => _failure = 'Không tự thay đổi quyền hoặc khóa admin của mình.');
      return;
    }
    final values = await _form('Quyền của ${row['fullName']}', [
      _AdminField('preset', 'Vai trò',
          initial: row['preset']?.toString() ?? 'support',
          choices: const {
            'super_admin': 'Super admin',
            'support': 'Hỗ trợ',
            'moderator': 'Kiểm duyệt',
            'analyst': 'Phân tích'
          }),
      _AdminField('active', 'Trạng thái',
          initial: row['isActive'] == true ? 'true' : 'false',
          choices: const {'true': 'Hoạt động', 'false': 'Đã khóa'}),
      const _AdminField('mfaCode', 'Mã MFA mới hoặc mã khôi phục',
          minimum: 6, secret: true),
      const _AdminField('reason', 'Lý do thay đổi',
          minimum: 10, multiline: true),
    ]);
    if (values != null) {
      await _command(
          '/admin/admins/${row['id']}',
          {
            'preset': values['preset'],
            'isActive': values['active'] == 'true',
            'mfaCode': values['mfaCode'],
            'reason': values['reason'],
            'version': row['version']
          },
          patch: true);
    }
  }

  Widget _support() => AdminSectionPanel(
        icon: Icons.policy_outlined,
        title: 'Tra cứu nghiệp vụ chỉ đọc',
        subtitle:
            'Chỉ đọc thông tin nghiệp vụ để hỗ trợ. Không sửa hợp đồng, số tiền, chứng từ hoặc hoàn cọc.',
        children: [
          _select('Loại dữ liệu', _contextKind, const {
            'account': 'Tài khoản',
            'property': 'Khu trọ',
            'room': 'Phòng',
            'tenant': 'Hồ sơ người thuê',
            'lease': 'Hợp đồng',
            'invoice': 'Hóa đơn'
          }, (value) {
            _contextKind = value;
            _contextResult = null;
          }),
          const SizedBox(height: 16),
          TextField(
              controller: _contextId,
              decoration: const InputDecoration(
                  labelText: 'ID đối tượng',
                  helperText:
                      'Lấy mã từ tài khoản hoặc hồ sơ hỗ trợ liên quan.')),
          const SizedBox(height: 16),
          TextField(
              controller: _contextReason,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Mục đích tra cứu / mã hồ sơ')),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_contextReason.text.trim().length < 10 ||
                            _contextId.text.trim().isEmpty) {
                          setState(() => _failure =
                              'Nhập ID và mục đích tra cứu ít nhất 10 ký tự.');
                          return;
                        }
                        setState(() => _contextResult = null);
                        final result =
                            await _command('/admin/support-context', {
                          'kind': _contextKind,
                          'id': _contextId.text.trim(),
                          'reason': _contextReason.text.trim()
                        });
                        if (_active && result != null) {
                          setState(() => _contextResult = _data(result));
                        }
                      },
                icon: const Icon(Icons.search),
                label: const Text('Tra cứu có ghi nhật ký')),
          ),
          if (_contextResult != null) ...[
            const Divider(height: 36),
            _record(_contextResult!)
          ],
        ],
      );

  Widget _record(Map<String, dynamic> values) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminOverviewTheme.background.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminOverviewTheme.line),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final entry in values.entries.where(
                (entry) => entry.key != 'history' && entry.value != null))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminOverviewTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminOverviewTheme.line),
                ),
                child: SelectableText(
                  '${const {
                        'id': 'Mã',
                        'fullName': 'Họ tên',
                        'email': 'Email',
                        'phone': 'Điện thoại',
                        'name': 'Tên',
                        'landlordId': 'Chủ trọ',
                        'roomId': 'Phòng',
                        'tenantId': 'Người thuê',
                        'leaseId': 'Hợp đồng',
                        'status': 'Trạng thái',
                        'title': 'Tiêu đề',
                        'description': 'Nội dung',
                        'body': 'Đánh giá',
                        'replyBody': 'Phản hồi',
                        'detail': 'Chi tiết phản ánh',
                        'reason': 'Lý do',
                        'monthlyRent': 'Tiền thuê',
                        'totalAmount': 'Tổng tiền',
                        'paidAmount': 'Đã thanh toán',
                        'publicAddress': 'Địa chỉ công khai'
                      }[entry.key] ?? entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
      );

  Widget _moderation(List<String> permissions) {
    final kinds = <String, String>{
      if (permissions.contains('admin.listings.moderate')) ...{
        'LISTING': 'Tin đăng',
        'REPORT': 'Báo cáo tin'
      },
      if (permissions.contains('admin.reviews.moderate')) ...{
        'REVIEW': 'Đánh giá',
        'REPLY': 'Phản hồi'
      }
    };
    final routeKind = GoRouterState.of(context).uri.queryParameters['kind'];
    final kind = kinds.containsKey(routeKind)
        ? routeKind!
        : kinds.containsKey(_kind)
            ? _kind
            : kinds.keys.first;
    return AdminSectionPanel(
      icon: Icons.fact_check_outlined,
      title: 'Hàng đợi kiểm duyệt nội dung',
      subtitle:
          'Xét duyệt tin đăng, báo cáo vi phạm, đánh giá và phản hồi theo SLA.',
      actions: [
        if (permissions.contains('admin.listings.moderate'))
          OutlinedButton(
              onPressed: () => context.push(adminListingsRoute),
              child: const Text('Tin đã duyệt / xác minh / danh mục')),
        if (permissions.contains('admin.reviews.moderate'))
          OutlinedButton(
              onPressed: () => context.push(adminReviewsRoute),
              child: const Text('Lịch sử đánh giá / ẩn nội dung')),
      ],
      children: [
        AdminToolbarPanel(
          children: [
            _select('Nội dung', kind, kinds, (value) {
              _kind = value;
              if (routeKind != null) context.go(adminModerationRoute);
            }),
            _select(
                'Phân công',
                _assignment,
                const {
                  'all': 'Tất cả',
                  'mine': 'Của tôi',
                  'unassigned': 'Chưa phân công'
                },
                (value) => _assignment = value),
            _select(
                'Ưu tiên',
                _priority,
                const {
                  'all': 'Tất cả',
                  'NORMAL': 'Bình thường',
                  'HIGH': 'Cao',
                  'URGENT': 'Khẩn cấp'
                },
                (value) => _priority = value),
            _searchBox(),
            FilterChip(
                label: const Text('Quá hạn'),
                selected: _overdue,
                onSelected: (value) => setState(() {
                      _overdue = value;
                      _page = 1;
                    })),
          ],
        ),
        _resource(
            AdminRequest('/admin/moderation/queue', {
              'kind': kind,
              'page': _page,
              'limit': 20,
              'assignment': _assignment,
              'search': _searchValue,
              if (_priority != 'all') 'priority': _priority,
              if (_overdue) 'overdue': 'true'
            }),
            (response) => Column(children: [
                  if (_rows(response).isEmpty)
                    const WorkflowEmpty('Không có công việc phù hợp.'),
                  for (final row in _rows(response))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AdminOverviewTheme.background
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: workflowStatusColor(row['priority'])
                              .withValues(alpha: 0.38),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                            key: ValueKey(
                                '${row['kind']}:${row['id']}:${row['version']}:${row['workVersion']}'),
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            title: Text(
                              '${row['title']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                                '${row['priority']} · Hạn ${_date(row['dueAt'])}\n${row['assigneeId'] == null ? 'Chưa phân công' : row['assigneeId'] == _owner ? 'Bạn đang phụ trách' : 'Đã có người phụ trách'}'),
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _resource(
                                            AdminRequest(
                                                '/admin/moderation/items/$kind/${row['id']}'),
                                            (item) => _record(_data(item))),
                                        const SizedBox(height: 14),
                                        Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              OutlinedButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _assign(row),
                                                  child: const Text(
                                                      'Phân công / ghi chú / hạn')),
                                              if (kind == 'LISTING') ...[
                                                FilledButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'PUBLISH'),
                                                    child: const Text(
                                                        'Duyệt công khai')),
                                                OutlinedButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'REJECT'),
                                                    child:
                                                        const Text('Từ chối')),
                                              ] else if (kind == 'REPORT') ...[
                                                FilledButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'RESOLVED'),
                                                    child:
                                                        const Text('Đã xử lý')),
                                                OutlinedButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'DISMISSED'),
                                                    child: const Text(
                                                        'Bỏ qua có lý do')),
                                              ] else ...[
                                                FilledButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'APPROVED'),
                                                    child: const Text('Duyệt')),
                                                OutlinedButton(
                                                    onPressed: _busy
                                                        ? null
                                                        : () => _decide(
                                                            row, 'REJECTED'),
                                                    child:
                                                        const Text('Từ chối')),
                                              ],
                                            ]),
                                      ]))
                            ]),
                      ),
                    ),
                  _pagination(response),
                ])),
      ],
    );
  }

  Future<void> _assign(Map<String, dynamic> row) async {
    final values = await _form('Điều phối nội dung', [
      _AdminField('assignment', 'Người xử lý',
          initial: row['assigneeId'] == null
              ? 'mine'
              : row['assigneeId'] == _owner
                  ? 'mine'
                  : 'keep',
          choices: {
            if (row['assigneeId'] != null && row['assigneeId'] != _owner)
              'keep': 'Giữ người hiện tại',
            'mine': 'Giao cho tôi',
            'none': 'Bỏ phân công'
          }),
      _AdminField('priority', 'Mức ưu tiên',
          initial: '${row['priority']}',
          choices: const {
            'NORMAL': 'Bình thường',
            'HIGH': 'Cao',
            'URGENT': 'Khẩn cấp'
          }),
      _AdminField('dueAt', 'Hạn xử lý (ISO 8601, có múi giờ)',
          initial: '${row['dueAt']}', date: true),
      _AdminField('note', 'Ghi chú nội bộ',
          initial: '${row['note'] ?? ''}', minimum: 0, multiline: true),
      const _AdminField('reason', 'Lý do thay đổi',
          minimum: 10, multiline: true),
    ]);
    if (values != null) {
      await _command('/admin/moderation/work', {
        'kind': row['kind'],
        'targetId': row['id'],
        'version': row['workVersion'],
        'assigneeId': values['assignment'] == 'mine'
            ? _owner
            : values['assignment'] == 'none'
                ? null
                : row['assigneeId'],
        'priority': values['priority'],
        'dueAt': DateTime.parse(values['dueAt']!).toUtc().toIso8601String(),
        'note': values['note'],
        'reason': values['reason']
      });
    }
  }

  Future<void> _decide(Map<String, dynamic> row, String decision) async {
    final values = await _form('Ghi nhận quyết định kiểm duyệt', [
      const _AdminField('reasonCode', 'Mã lý do',
          initial: 'CONTENT_CHECK',
          choices: {
            'CONTENT_CHECK': 'Đã kiểm tra nội dung',
            'MISLEADING': 'Thông tin sai lệch',
            'POLICY': 'Vi phạm quy định',
            'DUPLICATE': 'Trùng lặp',
            'INSUFFICIENT': 'Chưa đủ căn cứ',
            'OTHER': 'Khác'
          }),
      const _AdminField('reason', 'Căn cứ quyết định',
          minimum: 10, multiline: true),
    ]);
    if (values == null) return;
    final kind = row['kind'],
        id = row['id'],
        note = '[${values['reasonCode']}] ${values['reason']}';
    if (kind == 'LISTING') {
      await _command('/admin/listings/$id/review',
          {'version': row['version'], 'decision': decision, 'note': note});
    } else if (kind == 'REPORT') {
      await _command('/admin/listings/reports/$id/review',
          {'status': decision, 'note': note});
    } else {
      await _command(
          '/admin/room-reviews/$id/${kind == 'REPLY' ? 'reply/moderate' : 'moderate'}',
          {'version': row['version'], 'status': decision, 'note': note});
    }
  }

  Future<Map<String, String>?> _form(
      String title, List<_AdminField> fields) async {
    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _AdminFormDialog(title: title, fields: fields));
    return _active ? result : null;
  }
}

class _AdminField {
  const _AdminField(this.key, this.label,
      {this.initial = '',
      this.minimum = 1,
      this.email = false,
      this.secret = false,
      this.multiline = false,
      this.date = false,
      this.choices});
  final String key, label, initial;
  final int minimum;
  final bool email, secret, multiline, date;
  final Map<String, String>? choices;
}

class _AdminFormDialog extends StatefulWidget {
  const _AdminFormDialog({required this.title, required this.fields});
  final String title;
  final List<_AdminField> fields;
  @override
  State<_AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<_AdminFormDialog> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _inputs = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initial)
  };
  @override
  void dispose() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Form(
                      key: _key,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final field in widget.fields)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: field.choices != null
                                  ? DropdownButtonFormField<String>(
                                      value: _inputs[field.key]!.text,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: field.label),
                                      items: field.choices!.entries
                                          .map((entry) => DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(entry.value)))
                                          .toList(),
                                      onChanged: (value) => _inputs[field.key]!
                                          .text = value ?? '')
                                  : TextFormField(
                                      controller: _inputs[field.key],
                                      obscureText: field.secret,
                                      maxLength: field.multiline
                                          ? 1000
                                          : field.secret
                                              ? 64
                                              : 254,
                                      maxLines: field.multiline ? 3 : 1,
                                      decoration: InputDecoration(
                                          labelText: field.label),
                                      validator: (value) {
                                        if ((value?.trim().length ?? 0) <
                                            field.minimum) {
                                          return 'Nhập ít nhất ${field.minimum} ký tự.';
                                        }
                                        if (field.email &&
                                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                .hasMatch(value!.trim())) {
                                          return 'Email không hợp lệ.';
                                        }
                                        if (field.date &&
                                            DateTime.tryParse(value!.trim()) ==
                                                null) {
                                          return 'Thời gian không hợp lệ.';
                                        }
                                        return null;
                                      })),
                      ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () {
                  if (_key.currentState!.validate()) {
                    Navigator.pop(
                        context,
                        _inputs.map(
                            (key, value) => MapEntry(key, value.text.trim())));
                  }
                },
                child: const Text('Xác nhận'))
          ]);
}
