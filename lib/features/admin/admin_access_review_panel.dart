import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_lifecycle_panel.dart';

class AdminAccessReviewPanel extends ConsumerStatefulWidget {
  const AdminAccessReviewPanel({super.key});
  @override
  ConsumerState<AdminAccessReviewPanel> createState() => _AccessReviewState();
}

class _AccessReviewState extends WorkflowState<AdminAccessReviewPanel> {
  bool expanded = false;
  int page = 1;

  Future<void> review(Map<String, dynamic> user) async {
    final profile = user['adminProfile'] as Map?;
    if (profile == null) return;
    final input = await form('Rà soát quyền · ${user['fullName']}', [
      WorkflowField('nextReviewAt', 'Ngày rà soát tiếp theo (ISO 8601)',
          initial: DateTime.now()
              .add(const Duration(days: 90))
              .toUtc()
              .toIso8601String(),
          maxLength: 40),
      workflowReason,
    ]);
    if (input == null) return;
    if (DateTime.tryParse(input['nextReviewAt']!) == null) {
      setState(() => failure = 'Nhập ngày rà soát hợp lệ.');
      return;
    }
    await command('/admin/access-reviews/${user['id']}', {
      ...input,
      'version': profile['reviewVersion'],
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    if (!active || !can('admin.admins.manage')) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AdminOverviewTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: const Icon(
            Icons.verified_user_outlined,
            color: AdminOverviewTheme.blue,
          ),
          title: const Text(
            'Rà soát quyền admin',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
              'Kiểm tra MFA, quyền nhạy cảm và hạn rà soát. Không tự duyệt chính mình.'),
          onExpansionChanged: (value) => setState(() => expanded = value),
          children: [
            ...operationState,
            if (expanded)
              resource(
                  AdminRequest(
                      '/admin/access-reviews', {'page': page, 'limit': 20}),
                  (response) {
                final rows = workflowRows(response);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (rows.isEmpty)
                        const WorkflowEmpty('Chưa có hồ sơ admin.'),
                      for (final user in rows)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.background
                                .withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: user['reviewOverdue'] == true
                                  ? AdminOverviewTheme.red
                                      .withValues(alpha: 0.45)
                                  : AdminOverviewTheme.line,
                            ),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${user['fullName']} · ${user['email']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    '${user['isActive'] == true ? 'Hoạt động' : 'Đã khóa'} · MFA ${(user['adminProfile'] as Map?)?['mfaEnabled'] == true ? 'đã bật' : 'chưa bật'}'),
                                Text(
                                    'Lần hoạt động gần nhất: ${workflowDate(user['lastActiveAt'])}'),
                                Text(
                                    'Preset: ${(user['adminProfile'] as Map?)?['preset'] ?? 'Chưa cấp quyền'}'),
                                for (final membership
                                    in (user['adminTeamMemberships'] as List? ??
                                            [])
                                        .whereType<Map>())
                                  Text(
                                      'Team: ${(membership['team'] as Map?)?['name']} · ${membership['role']}${(membership['team'] as Map?)?['isActive'] == false ? ' · Tạm dừng' : ''}'),
                                if (user['reviewOverdue'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Rà soát quyền đã quá hạn',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                if (user['reviewRequired'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                        'Chưa có rà soát hợp lệ cho quyền hiện tại.'),
                                  ),
                                if (user['inactiveWarning'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                        'Cảnh báo: không hoạt động ít nhất 90 ngày; không tự khóa tài khoản.'),
                                  ),
                                Text(
                                    'Rà soát tiếp theo: ${workflowDate((user['adminProfile'] as Map?)?['nextAccessReviewAt'])}'),
                                ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text('Xem quyền hiện tại'),
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final permission in (user[
                                                          'adminProfile']
                                                      as Map?)?['permissions']
                                                  as List? ??
                                              [])
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    AdminOverviewTheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: AdminOverviewTheme
                                                        .line),
                                              ),
                                              child: Text('$permission'),
                                            ),
                                        ],
                                      ),
                                    ]),
                                if (user['id'] != workflowOwner &&
                                    user['adminProfile'] != null)
                                  TextButton.icon(
                                      onPressed:
                                          busy ? null : () => review(user),
                                      icon: const Icon(
                                          Icons.verified_user_outlined),
                                      label: const Text('Ghi nhận rà soát')),
                                AdminLifecyclePanel(
                                    key: ValueKey(user['id']),
                                    userId: '${user['id']}'),
                              ]),
                        ),
                      WorkflowPager(
                          page: page,
                          total:
                              ((response['meta'] as Map?)?['total'] as num? ??
                                      0)
                                  .toInt(),
                          limit: 20,
                          onPage: (value) => setState(() => page = value)),
                    ]);
              }),
          ],
        ),
      ),
    );
  }
}
