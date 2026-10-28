import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_moderation_quality_panel.dart';

class AdminPoliciesScreen extends ConsumerStatefulWidget {
  const AdminPoliciesScreen({super.key});

  @override
  ConsumerState<AdminPoliciesScreen> createState() =>
      _AdminPoliciesScreenState();
}

class _AdminPoliciesScreenState extends WorkflowState<AdminPoliciesScreen> {
  Future<void> create() async {
    final input = await form('Soạn policy mới', const [
      WorkflowField('kind', 'Loại nội dung', choices: {
        'LISTING': 'Tin đăng',
        'REPORT': 'Báo cáo vi phạm',
        'REVIEW': 'Đánh giá',
        'REPLY': 'Phản hồi đánh giá'
      }),
      WorkflowField('title', 'Tên policy', minLength: 3, maxLength: 160),
      WorkflowField('body', 'Nội dung policy',
          minLength: 20, maxLength: 20000, lines: 6),
      workflowReason,
    ]);
    if (input != null) await command('/admin/moderation-policies', input);
  }

  Future<void> activatePolicy(String id) async {
    final input = await form('Kích hoạt policy', const [workflowReason]);
    if (input != null) {
      await command('/admin/moderation-policies/$id/activate', input);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    return AdminWorkspaceScaffold(
      title: 'Policy kiểm duyệt',
      location: '/admin/moderation-policies',
      busy: busy,
      body: !active
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(20), children: [
              AdminSectionPanel(
                icon: Icons.policy_outlined,
                title: 'Phiên bản Policy kiểm duyệt',
                subtitle:
                    'Mỗi lần thay đổi tạo một phiên bản mới. Policy đang hoạt động được gắn vào các quyết định mới; lịch sử quyết định cũ không bị sửa.',
                trailing: rights?.has('admin.admins.manage') == true
                    ? FilledButton.icon(
                        onPressed: busy ? null : create,
                        icon: const Icon(Icons.add),
                        label: const Text('Soạn policy mới'))
                    : null,
                children: [
                  ...operationState,
                  resource(const AdminRequest('/admin/moderation-policies'),
                      (response) {
                    final rows = workflowRows(response);
                    if (rows.isEmpty) {
                      return const WorkflowEmpty(
                          'Chưa có policy. Quyết định hiện tại vẫn được ghi nhận, nhưng không có policy version.');
                    }
                    return Column(children: [
                      for (final row in rows)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: row['status'] == 'ACTIVE'
                                  ? AdminOverviewTheme.green.withValues(alpha: 0.45)
                                  : AdminOverviewTheme.line,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                                title: Text(
                                  '${row['title']} · v${row['version']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                    '${workflowLabel(row['kind'])} · ${workflowLabel(row['status'])}'),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AdminOverviewTheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AdminOverviewTheme.line),
                                    ),
                                    child: SelectableText('${row['body']}'),
                                  ),
                                  if (row['status'] == 'DRAFT' &&
                                      rights?.has('admin.admins.manage') ==
                                          true)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => activatePolicy(
                                                  '${row['id']}'),
                                          child: const Text(
                                              'Kích hoạt phiên bản này')),
                                    ),
                                ]),
                          ),
                        ),
                    ]);
                  }),
                ],
              ),
              const SizedBox(height: 20),
              const AdminModerationQualityPanel(),
            ]),
    );
  }
}
