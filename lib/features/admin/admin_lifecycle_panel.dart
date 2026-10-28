import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminLifecyclePanel extends ConsumerStatefulWidget {
  const AdminLifecyclePanel({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<AdminLifecyclePanel> createState() => _AdminLifecycleState();
}

class _AdminLifecycleState extends WorkflowState<AdminLifecyclePanel> {
  bool expanded = false;

  Future<void> change(String action, Map<String, dynamic> data) async {
    final input = await form(
        action == 'resend-invite'
            ? 'Gửi lại lời mời admin'
            : 'Thu hồi mọi session admin',
        [workflowReason]);
    if (input == null || !can('admin.admins.manage')) return;
    if (action == 'revoke-sessions' && !can('admin.sessions.revoke')) return;
    await command('/admin/admins/${widget.userId}/$action',
        {...input, 'version': data['version']});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    if (!active || !can('admin.admins.manage')) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            'Lời mời, session và lịch sử',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onExpansionChanged: (value) => setState(() => expanded = value),
          children: [
            ...operationState,
            if (expanded)
              resource(AdminRequest('/admin/admins/${widget.userId}/lifecycle'),
                  (response) {
                final data = workflowData(response);
                final invitation = data['invitation'] as Map? ?? {};
                final status = '${invitation['status']}';
                final mayResend = data['isActive'] == true &&
                    const ['PENDING', 'EXPIRED', 'INVALIDATED']
                        .contains(status);
                final labels = {
                  'PENDING': 'Chờ kích hoạt',
                  'EXPIRED': 'Lời mời hết hạn',
                  'INVALIDATED': 'Lời mời đã vô hiệu',
                  'ACTIVATED': 'Đã kích hoạt',
                  'NOT_INVITED': 'Không có lời mời'
                };
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          AdminStatusBadge(
                            label: labels[status] ??
                                'Chưa xác định trạng thái lời mời',
                            statusKey: status,
                          ),
                          Text(
                              'Hạn lời mời: ${workflowDate(invitation['expiresAt'])}'),
                          Text(
                              'Kích hoạt: ${workflowDate(invitation['activatedAt'])}'),
                          Text(
                              'Session hợp lệ: ${data['activeSessions'] ?? 0}'),
                          Text(
                              'Hoạt động gần nhất: ${workflowDate(data['lastActiveAt'])}'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (widget.userId != workflowOwner)
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          if (mayResend)
                            OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => change('resend-invite', data),
                                icon:
                                    const Icon(Icons.forward_to_inbox_outlined),
                                label: const Text('Gửi lại lời mời')),
                          if (can('admin.sessions.revoke') &&
                              (data['activeSessions'] as num? ?? 0) > 0)
                            OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => change('revoke-sessions', data),
                                icon: const Icon(Icons.logout_outlined),
                                label: const Text('Thu hồi session')),
                        ]),
                      const SizedBox(height: 10),
                      Text(
                        'Gửi lại thay thế link cũ, chỉ áp dụng trước kích hoạt và cách lần gửi trước ít nhất 60 giây. Thu hồi session không vô hiệu MFA hay khóa khả năng đăng nhập lại.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AdminOverviewTheme.muted),
                      ),
                      const SizedBox(height: 8),
                      for (final event
                          in (data['history'] as List? ?? []).whereType<Map>())
                        ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${event['summary']}'),
                            subtitle: Text(
                                '${event['action']} · ${workflowDate(event['createdAt'])}')),
                    ]);
              }),
          ],
        ),
      ),
    );
  }
}
