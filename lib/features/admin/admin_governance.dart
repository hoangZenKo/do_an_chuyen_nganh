import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_finance_workflow.dart';
import 'admin_transactions_panel.dart';
import '../auth/auth_providers.dart';

const _governanceSections = {
  'flags': ('Feature flags', 'admin.flags.manage'),
  'teams': ('Nhóm admin', 'admin.teams.manage'),
  'simulator': ('Mô phỏng quyền', 'admin.permissions.simulate'),
  'finance': ('Đối soát chỉ đọc', 'admin.finance.read'),
  'reports': ('Lịch báo cáo', 'admin.reports.manage'),
};

class AdminGovernanceScreen extends ConsumerStatefulWidget {
  const AdminGovernanceScreen({super.key, this.section = 'flags'});
  final String section;
  @override
  ConsumerState<AdminGovernanceScreen> createState() => _GovernanceState();
}

class _GovernanceState extends WorkflowState<AdminGovernanceScreen> {
  late String section = widget.section;
  String? scheduleId;
  Map<String, dynamic>? simulation;
  DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now().add(const Duration(days: 1)));

  Future<void> editFlag(Map<String, dynamic> flag) async {
    final roles = (flag['roles'] as List? ?? []).join(',');
    final input = await form('Cập nhật ${flag['key']}', [
      WorkflowField('enabled', 'Trạng thái',
          initial: '${flag['enabled']}',
          choices: const {'true': 'Bật', 'false': 'Tắt'}),
      WorkflowField('rollout', 'Tỉ lệ rollout',
          initial: '${flag['rollout']}',
          choices: {
            for (final value in {0, 10, 25, 50, 75, 100, flag['rollout']})
              '$value': '$value%'
          }),
      WorkflowField('roles', 'Đối tượng áp dụng',
          initial: roles.isEmpty ? 'all' : roles,
          choices: {
            'all': 'Mọi vai trò',
            'admin': 'Admin',
            'landlord': 'Chủ trọ',
            'tenant': 'Người thuê',
            'staff': 'Nhân viên',
            if (roles.isNotEmpty) roles: roles
          }),
      workflowReason,
    ]);
    if (input == null) return;
    await command(
        '/admin/feature-flags/${flag['key']}',
        {
          'enabled': input['enabled'] == 'true',
          'rollout': int.parse(input['rollout']!),
          'roles':
              input['roles'] == 'all' ? <String>[] : input['roles']!.split(','),
          'version': flag['version'],
          'reason': input['reason']
        },
        patch: true);
  }

  Future<void> editTeam([Map<String, dynamic>? team]) async {
    final input =
        await form(team == null ? 'Tạo nhóm admin' : 'Cập nhật nhóm', [
      WorkflowField('name', 'Tên nhóm',
          initial: '${team?['name'] ?? ''}', minLength: 2, maxLength: 100),
      WorkflowField('description', 'Mô tả',
          initial: '${team?['description'] ?? ''}',
          minLength: 0,
          maxLength: 1000),
      if (team != null)
        WorkflowField('isActive', 'Trạng thái',
            initial: '${team['isActive']}',
            choices: const {'true': 'Hoạt động', 'false': 'Dừng nhận ticket'}),
      workflowReason,
    ]);
    if (input == null) return;
    await command(
        team == null ? '/admin/teams' : '/admin/teams/${team['id']}',
        {
          ...input,
          if (team != null) 'isActive': input['isActive'] == 'true',
          if (team != null) 'version': team['version']
        },
        patch: team != null);
  }

  Future<void> member(
      Map<String, dynamic> team, List<Map<String, dynamic>> admins) async {
    final choices = {
      for (final admin in admins.where((row) => row['isActive'] == true))
        '${admin['id']}': '${admin['fullName'] ?? admin['email']}'
    };
    if (choices.isEmpty) return;
    final input = await form('Thêm / đổi vai trò thành viên', [
      WorkflowField('userId', 'Admin', choices: choices),
      const WorkflowField('role', 'Vai trò trong nhóm',
          choices: {'MEMBER': 'Thành viên', 'LEAD': 'Trưởng nhóm'}),
      workflowReason
    ]);
    if (input != null) {
      await command('/admin/teams/${team['id']}/members', input);
    }
  }

  Map<String, String> get reportKinds => {
        if (can('admin.finance.read')) 'MONTHLY_FINANCE': 'Tài chính 30 ngày',
        if (can('admin.moderation.reports')) 'MODERATION': 'Kiểm duyệt 30 ngày',
        if (can('admin.support.read')) 'SUPPORT_SLA': 'SLA hỗ trợ',
      };

  Future<void> editSchedule([Map<String, dynamic>? schedule]) async {
    final kinds = reportKinds;
    if (kinds.isEmpty) return;
    final input = await form(
        schedule == null ? 'Tạo lịch báo cáo' : 'Cập nhật lịch báo cáo', [
      WorkflowField('name', 'Tên lịch',
          initial: '${schedule?['name'] ?? ''}', minLength: 2, maxLength: 100),
      WorkflowField('kind', 'Báo cáo',
          initial: kinds.containsKey(schedule?['kind'])
              ? '${schedule!['kind']}'
              : kinds.keys.first,
          choices: kinds),
      WorkflowField('cadence', 'Chu kỳ',
          initial: '${schedule?['cadence'] ?? 'DAILY'}',
          choices: const {
            'DAILY': 'Hằng ngày',
            'WEEKLY': 'Hằng tuần',
            'MONTHLY': 'Hằng tháng'
          }),
      WorkflowField('hourUtc', 'Giờ chạy theo múi giờ đã chọn',
          initial: '${schedule?['hourUtc'] ?? 8}',
          choices: {
            for (var hour = 0; hour < 24; hour++)
              '$hour': '${hour.toString().padLeft(2, '0')}:00'
          }),
      WorkflowField('timezone', 'Múi giờ lịch',
          initial: '${schedule?['timezone'] ?? 'Asia/Ho_Chi_Minh'}',
          choices: const {
            'Asia/Ho_Chi_Minh': 'Việt Nam (UTC+7)',
            'UTC': 'UTC',
            'Asia/Tokyo': 'Tokyo (UTC+9)',
            'America/New_York': 'New York',
            'America/Los_Angeles': 'Los Angeles'
          }),
      if (schedule != null)
        WorkflowField('enabled', 'Trạng thái',
            initial: '${schedule['isEnabled']}',
            choices: const {'true': 'Hoạt động', 'false': 'Tạm dừng'}),
      workflowReason,
    ]);
    if (input == null) return;
    await command(
        schedule == null
            ? '/admin/report-schedules'
            : '/admin/report-schedules/${schedule['id']}',
        {
          ...input,
          'hourUtc': int.parse(input['hourUtc']!),
          if (schedule != null) 'version': schedule['version'],
          if (schedule != null) 'enabled': input['enabled'] == 'true'
        },
        patch: schedule != null);
  }

  Future<void> download(String id) async {
    if (!active || busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final csv = await ref.read(adminApiProvider).downloadReport(id);
      if (!active) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted && active) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép CSV báo cáo.')));
      }
    } catch (error) {
      if (active) setState(() => failure = '$error');
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    final sections = _governanceSections.entries
        .where((entry) => rights?.has(entry.value.$2) == true)
        .toList();
    final current = sections.any((entry) => entry.key == section)
        ? section
        : sections.firstOrNull?.key;
    return AdminWorkspaceScaffold(
      title: _governanceSections[current]?.$1 ?? 'Governance',
      location: switch (current) {
        'finance' => '/admin/finance-reconciliation',
        'reports' => '/admin/report-schedules',
        'teams' => '/admin/teams',
        'simulator' => '/admin/permission-simulator',
        _ => '/admin/governance',
      },
      busy: busy,
      body: !active
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(24), children: [
              AdminSectionPanel(
                icon: Icons.account_balance_outlined,
                title: 'Quản trị nền tảng',
                subtitle:
                    'Mọi thay đổi yêu cầu lý do. Đối soát không cho phép sửa giao dịch.',
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final entry in sections)
                      ChoiceChip(
                          label: Text(entry.value.$1),
                          selected: current == entry.key,
                          onSelected: (_) =>
                              setState(() => section = entry.key))
                  ]),
                  ...operationState,
                ],
              ),
              const SizedBox(height: 18),
              if (current == null)
                const WorkflowEmpty(
                    'Bạn không có quyền truy cập chức năng governance.'),
              if (current == 'flags')
                AdminSectionPanel(
                  icon: Icons.flag_outlined,
                  title: 'Feature flags',
                  child: resource(
                      const AdminRequest('/admin/feature-flags'),
                      (response) => Column(children: [
                            for (final flag in workflowRows(response))
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AdminOverviewTheme.background
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AdminOverviewTheme.line),
                                ),
                                child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                      '${flag['key']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                        '${flag['enabled'] == true ? 'Bật' : 'Tắt'} · ${flag['rollout']}% · ${(flag['roles'] as List? ?? []).isEmpty ? 'Mọi vai trò' : (flag['roles'] as List).join(', ')} · v${flag['version']}'),
                                    trailing: IconButton(
                                        tooltip: 'Cấu hình rollout',
                                        onPressed:
                                            busy ? null : () => editFlag(flag),
                                        icon: const Icon(Icons.tune))),
                              )
                          ])),
                ),
              if (current == 'teams')
                AdminSectionPanel(
                  icon: Icons.groups_outlined,
                  title: 'Nhóm admin',
                  trailing: FilledButton.icon(
                      onPressed: busy ? null : () => editTeam(),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Tạo nhóm admin')),
                  child: resource(
                      const AdminRequest('/admin/team'),
                      (accounts) => resource(
                          const AdminRequest('/admin/teams'),
                          (response) => Column(children: [
                                if (workflowRows(response).isEmpty)
                                  const WorkflowEmpty(
                                      'Chưa có nhóm. Tạo nhóm để phân công hỗ trợ.'),
                                for (final team in workflowRows(response))
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: AdminOverviewTheme.background
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AdminOverviewTheme.line),
                                    ),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 2,
                                          ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                  14, 0, 14, 12),
                                          title: Text(
                                            '${team['name']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text(
                                              '${team['isActive'] == true ? 'Hoạt động' : 'Tạm dừng'} · ${(team['_count'] as Map?)?['tickets'] ?? 0} ticket'),
                                          children: [
                                            Wrap(spacing: 8, children: [
                                              TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => editTeam(team),
                                                  child:
                                                      const Text('Sửa nhóm')),
                                              TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => member(
                                                          team,
                                                          workflowRows(
                                                              accounts)),
                                                  child: const Text(
                                                      'Thêm thành viên'))
                                            ]),
                                            for (final entry
                                                in (team['members'] as List? ??
                                                        [])
                                                    .whereType<Map>())
                                              ListTile(
                                                  dense: true,
                                                  title: Text(
                                                      '${(entry['user'] as Map?)?['fullName']}'),
                                                  subtitle:
                                                      Text('${entry['role']}'),
                                                  trailing: IconButton(
                                                      tooltip: 'Xóa khỏi nhóm',
                                                      onPressed: busy
                                                          ? null
                                                          : () async {
                                                              final input =
                                                                  await form(
                                                                      'Xóa thành viên khỏi nhóm',
                                                                      const [
                                                                    workflowReason
                                                                  ]);
                                                              if (input !=
                                                                  null) {
                                                                await command(
                                                                    '/admin/teams/${team['id']}/members/${entry['userId']}/remove',
                                                                    input);
                                                              }
                                                            },
                                                      icon: const Icon(Icons
                                                          .person_remove_outlined))),
                                          ]),
                                    ),
                                  ),
                              ]))),
                ),
              if (current == 'simulator')
                AdminSectionPanel(
                  icon: Icons.security_outlined,
                  title: 'Mô phỏng quyền RBAC',
                  subtitle:
                      'Mô phỏng preset không cấp quyền thực tế. MFA, trạng thái tài khoản và phạm vi tài nguyên vẫn được kiểm tra khi gọi API.',
                  children: [
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final input =
                                        await form('Mô phỏng quyền RBAC', [
                                      const WorkflowField('preset', 'Preset',
                                          choices: {
                                            'support': 'Hỗ trợ',
                                            'moderator': 'Kiểm duyệt',
                                            'analyst': 'Phân tích',
                                            'super_admin': 'Super admin'
                                          }),
                                      WorkflowField(
                                          'action', 'Quyền cần kiểm tra',
                                          choices: {
                                            for (final entry
                                                in _governanceSections.values)
                                              entry.$2: entry.$1,
                                            'admin.support.manage':
                                                'Xử lý ticket',
                                            'admin.listings.moderate':
                                                'Kiểm duyệt tin',
                                            'admin.admins.manage':
                                                'Quản lý quyền admin'
                                          })
                                    ]);
                                    if (input == null) return;
                                    final result = await command(
                                        '/admin/permissions/simulate', input);
                                    if (result != null && active) {
                                      setState(() =>
                                          simulation = workflowData(result));
                                    }
                                  },
                            child: const Text('Kiểm tra quyền'))),
                    if (simulation != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (simulation!['allowed'] == true
                                    ? AdminOverviewTheme.green
                                    : AdminOverviewTheme.red)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: ListTile(
                            leading: Icon(
                              simulation!['allowed'] == true
                                  ? Icons.check_circle_outline
                                  : Icons.block,
                              color: simulation!['allowed'] == true
                                  ? AdminOverviewTheme.green
                                  : AdminOverviewTheme.red,
                            ),
                            title: Text(simulation!['allowed'] == true
                                ? 'Preset có quyền'
                                : 'Preset không có quyền'),
                            subtitle: Text(
                                '${simulation!['preset']} · ${simulation!['checked']}')),
                      ),
                    ],
                  ],
                ),
              if (current == 'finance')
                AdminSectionPanel(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Đối soát tài chính',
                  subtitle:
                      'Số liệu snapshot hóa đơn và sự kiện thanh toán có thể thuộc các kỳ khác nhau. Mismatch so sánh toàn bộ lịch sử thanh toán của từng hóa đơn.',
                  trailing: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                            context: context,
                            initialDateRange: range,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 1)));
                        if (picked != null && active) {
                          setState(() => range = picked);
                        }
                      },
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                          '${workflowDate(range.start)} — ${workflowDate(range.end)}')),
                  child: resource(
                      AdminRequest('/admin/finance/reconciliation', {
                        'from': range.start.toUtc().toIso8601String(),
                        'to': range.end.toUtc().toIso8601String()
                      }), (response) {
                    final data = workflowData(response),
                        totals = data['totals'] as Map? ?? {};
                    const labels = {
                      'billed': 'Tổng lập hóa đơn',
                      'invoicePaidSnapshot': 'Đã thu (snapshot)',
                      'paymentEvents': 'Thu/hoàn trong kỳ',
                      'outstandingSnapshot': 'Còn phải thu',
                      'depositsCollected': 'Cọc đã thu',
                      'depositsReturned': 'Cọc hoàn trả',
                      'depositsDeducted': 'Cọc khấu trừ',
                      'expenses': 'Chi phí'
                    };
                    final mismatches =
                        (data['mismatches'] as List? ?? []).whereType<Map>();
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final entry in labels.entries)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.background
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AdminOverviewTheme.line),
                              ),
                              child: ListTile(
                                  dense: true,
                                  title: Text(entry.value),
                                  trailing: Text(
                                    '${totals[entry.key] ?? 0} đ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  )),
                            ),
                          const Divider(height: 32),
                          Text('${mismatches.length} hóa đơn lệch sổ',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          if (mismatches.isEmpty)
                            const WorkflowEmpty(
                                'Không phát hiện chênh lệch trong phạm vi đã chọn.'),
                          for (final row in mismatches)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AdminOverviewTheme.red
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AdminOverviewTheme.red
                                        .withValues(alpha: 0.35)),
                              ),
                              child: ListTile(
                                  title: Text('${row['invoiceId']}'),
                                  subtitle: Text(
                                      'Snapshot: ${row['invoicePaid']} · Lịch sử thanh toán: ${row['paymentEvents']}')),
                            ),
                        ]);
                  }),
                ),
              if (current == 'finance') const SizedBox(height: 16),
              if (current == 'finance') const AdminTransactionsPanel(),
              if (current == 'finance' && can('admin.finance.reconcile')) ...[
                const SizedBox(height: 18),
                const AdminFinanceWorkflow(),
              ],
              if (current == 'reports')
                AdminSectionPanel(
                  icon: Icons.summarize_outlined,
                  title: 'Lịch báo cáo định kỳ',
                  subtitle:
                      'Bản xuất được mã hóa, chỉ chủ lịch có quyền tải trong 7 ngày. Lịch chạy theo múi giờ đã chọn; không tự gửi file ra ngoài.',
                  trailing: FilledButton.icon(
                      onPressed: busy || reportKinds.isEmpty
                          ? null
                          : () => editSchedule(),
                      icon: const Icon(Icons.schedule_send_outlined),
                      label: const Text('Tạo lịch báo cáo')),
                  children: [
                    resource(
                        const AdminRequest('/admin/report-schedules'),
                        (response) => Column(children: [
                              if (workflowRows(response).isEmpty)
                                const WorkflowEmpty('Chưa có lịch báo cáo.'),
                              for (final schedule in workflowRows(response))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: scheduleId == '${schedule['id']}'
                                        ? AdminOverviewTheme.background
                                        : AdminOverviewTheme.background
                                            .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: scheduleId == '${schedule['id']}'
                                          ? AdminOverviewTheme.blue
                                              .withValues(alpha: 0.55)
                                          : AdminOverviewTheme.line,
                                    ),
                                  ),
                                  child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      title: Text(
                                        '${schedule['name']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: Text(
                                          '${workflowLabel(schedule['kind'])} · ${workflowLabel(schedule['cadence'])} · ${schedule['isEnabled'] == true ? 'Hoạt động' : 'Tạm dừng'}\nLần kế: ${workflowDate(schedule['nextRunAt'])}'),
                                      onTap: () => setState(() =>
                                          scheduleId = '${schedule['id']}'),
                                      trailing: PopupMenuButton<String>(
                                          enabled: !busy,
                                          onSelected: (action) async {
                                            if (action == 'edit') {
                                              await editSchedule(schedule);
                                            } else {
                                              await command(
                                                  '/admin/report-schedules/${schedule['id']}/run',
                                                  {});
                                              if (active) {
                                                setState(() => scheduleId =
                                                    '${schedule['id']}');
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text(
                                                        'Sửa / tạm dừng lịch')),
                                                if (schedule['isEnabled'] ==
                                                    true)
                                                  const PopupMenuItem(
                                                      value: 'run',
                                                      child: Text(
                                                          'Tạo bản xuất ngay'))
                                              ])),
                                ),
                            ])),
                    if (scheduleId != null)
                      resource(
                          AdminRequest(
                              '/admin/report-schedules/$scheduleId/runs'),
                          (response) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 32),
                                    Text('Các lần xuất báo cáo',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 8),
                                    if (workflowRows(response).isEmpty)
                                      const WorkflowEmpty(
                                          'Chưa có bản xuất. Worker xử lý queue mỗi phút.'),
                                    for (final run in workflowRows(response))
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: AdminOverviewTheme.background
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: AdminOverviewTheme.line),
                                        ),
                                        child: ListTile(
                                            title: Text(
                                                workflowLabel(run['status'])),
                                            subtitle: Text(
                                                '${workflowDate(run['createdAt'])} · Hết hạn ${workflowDate(run['expiresAt'])}\n${run['lastError'] ?? ''}'),
                                            trailing: run['status'] ==
                                                    'COMPLETED'
                                                ? IconButton(
                                                    tooltip: 'Sao chép CSV',
                                                    onPressed: busy
                                                        ? null
                                                        : () => download(
                                                            '${run['id']}'),
                                                    icon: const Icon(Icons
                                                        .copy_all_outlined))
                                                : run['status'] == 'FAILED'
                                                    ? IconButton(
                                                        tooltip:
                                                            'Thử lại báo cáo',
                                                        onPressed: busy
                                                            ? null
                                                            : () async {
                                                                final input =
                                                                    await form(
                                                                        'Thử lại bản xuất thất bại',
                                                                        const [
                                                                      workflowReason
                                                                    ]);
                                                                if (input !=
                                                                    null) {
                                                                  await command(
                                                                      '/admin/report-runs/${run['id']}/retry',
                                                                      input);
                                                                }
                                                              },
                                                        icon: const Icon(
                                                            Icons.replay))
                                                    : null),
                                      ),
                                  ])),
                  ],
                ),
            ]),
    );
  }
}
