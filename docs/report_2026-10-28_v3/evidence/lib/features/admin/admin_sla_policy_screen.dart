import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';

class AdminSlaPolicyScreen extends ConsumerStatefulWidget {
  const AdminSlaPolicyScreen({super.key});
  @override
  ConsumerState<AdminSlaPolicyScreen> createState() => _SlaPolicyState();
}

class _SlaPolicyState extends WorkflowState<AdminSlaPolicyScreen> {
  Future<void> edit(Map<String, dynamic> policy) async {
    final input = await form('Lịch và chính sách SLA', [
      WorkflowField('enabled', 'Áp dụng cho ticket mới',
          initial: '${policy['enabled']}',
          choices: const {
            'false': 'Giữ SLA theo giờ lịch',
            'true': 'Dùng lịch làm việc'
          }),
      WorkflowField('timezone', 'Múi giờ IANA',
          initial: '${policy['timezone']}', maxLength: 80),
      WorkflowField('weekdays', 'Thứ trong tuần (1=thứ Hai, 7=Chủ nhật)',
          initial: (policy['weekdays'] as List? ?? []).join(','),
          maxLength: 20),
      WorkflowField('startMinute', 'Bắt đầu: số phút từ 00:00 (540 = 09:00)',
          initial: '${policy['startMinute']}', maxLength: 4),
      WorkflowField('endMinute', 'Kết thúc: số phút từ 00:00 (1020 = 17:00)',
          initial: '${policy['endMinute']}', maxLength: 4),
      WorkflowField('holidays', 'Ngày nghỉ YYYY-MM-DD, cách nhau bằng dấu phẩy',
          initial: (policy['holidays'] as List? ?? []).join(','),
          minLength: 0,
          maxLength: 5000,
          lines: 2),
      WorkflowField(
          'pauseWaiting', 'Tạm dừng SLA giải quyết khi chờ người dùng',
          initial: '${policy['pauseWaiting']}',
          choices: const {
            'false': 'Không tạm dừng',
            'true': 'Tạm dừng và giữ thời gian còn lại'
          }),
      WorkflowField('responseMinutes', 'Phút phản hồi theo độ ưu tiên (JSON)',
          initial: jsonEncode(policy['responseMinutes']),
          maxLength: 200,
          lines: 3),
      WorkflowField(
          'resolutionMinutes', 'Phút giải quyết theo độ ưu tiên (JSON)',
          initial: jsonEncode(policy['resolutionMinutes']),
          maxLength: 200,
          lines: 3),
      WorkflowField('escalationMinutes',
          'Mốc escalation sau hạn, phút làm việc (bắt đầu 0)',
          initial: (policy['escalationMinutes'] as List? ?? []).join(','),
          maxLength: 30),
      workflowReason,
    ]);
    if (input == null) return;
    try {
      List<int> numbers(String key) => input[key]!
          .split(',')
          .map((value) => int.parse(value.trim()))
          .toList();
      await command(
          '/admin/support-sla-policy',
          {
            'enabled': input['enabled'] == 'true',
            'timezone': input['timezone'],
            'weekdays': numbers('weekdays'),
            'startMinute': int.parse(input['startMinute']!),
            'endMinute': int.parse(input['endMinute']!),
            'holidays': input['holidays']!
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
            'pauseWaiting': input['pauseWaiting'] == 'true',
            'responseMinutes': jsonDecode(input['responseMinutes']!),
            'resolutionMinutes': jsonDecode(input['resolutionMinutes']!),
            'escalationMinutes': numbers('escalationMinutes'),
            'version': policy['version'],
            'reason': input['reason'],
          },
          patch: true);
    } on FormatException {
      if (active) {
        setState(() => failure =
            'Kiểm tra các trường số và JSON gồm LOW, NORMAL, HIGH, URGENT.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    final allowed = active &&
        can('admin.admins.manage') &&
        can('admin.support.read') &&
        can('admin.support.manage');
    return AdminWorkspaceScaffold(
        title: 'Lịch làm việc / SLA',
        location: '/admin/support-center',
        busy: busy,
        body: !allowed
            ? const Center(child: Text('Không còn quyền cấu hình SLA.'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: AdminSectionPanel(
                          icon: Icons.schedule_outlined,
                          title: 'Cấu hình SLA & Lịch làm việc',
                          subtitle:
                              'Thay đổi chỉ áp dụng cho ticket được tạo sau khi lưu. Ticket cũ giữ nguyên policy snapshot và thời gian đã trôi qua.',
                          children: [
                            ...operationState,
                            resource(
                                const AdminRequest('/admin/support-sla-policy'),
                                (response) {
                              final policy = workflowData(response);
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                              policy['enabled'] == true
                                                  ? 'SLA theo giờ làm việc'
                                                  : 'SLA theo giờ lịch',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge),
                                        ),
                                        AdminStatusBadge(
                                          label: policy['enabled'] == true
                                              ? 'Đang bật'
                                              : 'Giờ lịch',
                                          color: policy['enabled'] == true
                                              ? AdminOverviewTheme.green
                                              : AdminOverviewTheme.amber,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AdminOverviewTheme.background
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AdminOverviewTheme.line),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Múi giờ: ${policy['timezone']} · v${policy['version']}'),
                                          Text(
                                              'Ngày làm việc: ${(policy['weekdays'] as List? ?? []).join(', ')}'),
                                          Text(
                                              'Khung giờ (phút từ 00:00): ${policy['startMinute']}–${policy['endMinute']}'),
                                          Text(
                                              'Tạm dừng khi chờ người dùng: ${policy['pauseWaiting'] == true ? 'Có' : 'Không'}'),
                                          Text(
                                              'Ngày nghỉ: ${(policy['holidays'] as List? ?? []).isEmpty ? 'Chưa cấu hình' : (policy['holidays'] as List).join(', ')}'),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    for (final priority in [
                                      'URGENT',
                                      'HIGH',
                                      'NORMAL',
                                      'LOW'
                                    ])
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AdminOverviewTheme.background
                                              .withValues(alpha: 0.55),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: workflowStatusColor(priority)
                                                .withValues(alpha: 0.38),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            AdminStatusBadge.fromStatus(
                                                priority),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                  '${workflowLabel(priority)}: phản hồi ${(policy['responseMinutes'] as Map?)?[priority]} phút / giải quyết ${(policy['resolutionMinutes'] as Map?)?[priority]} phút'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                        onPressed:
                                            busy ? null : () => edit(policy),
                                        icon: const Icon(
                                            Icons.edit_calendar_outlined),
                                        label: const Text('Cấu hình SLA')),
                                  ]);
                            }),
                          ],
                        )))));
  }
}
