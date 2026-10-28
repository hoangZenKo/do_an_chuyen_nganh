import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import '../auth/auth_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';
import 'admin_bulk_preview_dialog.dart';

class AdminModerationV2Screen extends ConsumerStatefulWidget {
  const AdminModerationV2Screen({super.key});
  @override
  ConsumerState<AdminModerationV2Screen> createState() => _ModerationState();
}

class _ModerationState extends WorkflowState<AdminModerationV2Screen> {
  int appealPage = 1, decisionPage = 1;
  String kind = 'LISTING';
  final selected = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? bulkResult;

  Future<bool> confirmBulk(Map<String, dynamic> payload) async {
    if (!active || busy || !can('admin.moderation.bulk')) return false;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final response = await ref
          .read(adminApiProvider)
          .command('/admin/moderation-v2/bulk/preview', payload);
      if (!mounted || !active) return false;
      return await showDialog<bool>(
              context: context,
              builder: (_) => AdminBulkPreviewDialog(
                  preview: response,
                  owner: workflowOwner,
                  permission: ['LISTING', 'REPORT'].contains(kind)
                      ? 'admin.listings.moderate'
                      : 'admin.reviews.moderate')) ??
          false;
    } catch (error) {
      if (active) setState(() => failure = '$error');
      return false;
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> history(Map<String, dynamic> decision) async {
    if (!active || busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final response = await ref.read(adminApiProvider).resource(
          '/admin/moderation-v2/history/${decision['kind']}/${decision['targetId']}');
      if (!mounted || !active) return;
      await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('Lịch sử quyết định và bằng chứng'),
                content: SizedBox(
                    width: 600,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          for (final row in workflowRows(response)) ...[
                            Text(
                                'v${row['version']} · ${row['fromStatus']} → ${row['toStatus']}',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${workflowDate(row['createdAt'])} · ${row['source']}'),
                            Text('${row['reason']}'),
                            if (row['policy'] is Map)
                              Text(
                                  'Chính sách: ${(row['policy'] as Map)['title']} · v${(row['policy'] as Map)['version']}'),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text(
                                    'Bằng chứng tại thời điểm quyết định'),
                                children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: SelectableText(
                                          const JsonEncoder.withIndent('  ')
                                              .convert(row['evidence'] ??
                                                  {
                                                    'status':
                                                        'Không có snapshot cho quyết định cũ'
                                                  }))),
                                ]),
                            const Divider(height: 24),
                          ],
                        ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'))
                ],
              ));
    } catch (error) {
      if (active) setState(() => failure = '$error');
    } finally {
      if (active) setState(() => busy = false);
    }
  }

  Future<void> resolve(Map<String, dynamic> appeal) async {
    final input = await form('Xét khiếu nại độc lập', const [
      WorkflowField('outcome', 'Kết quả', choices: {
        'UPHELD': 'Giữ quyết định',
        'REOPENED': 'Mở kiểm duyệt lại',
        'SUPERSEDED': 'Đã được thay thế'
      }),
      workflowReason,
    ]);
    if (input == null) return;
    await command('/admin/moderation-v2/appeals/${appeal['id']}/resolve',
        {...input, 'version': appeal['version']});
  }

  Future<void> assign(Map<String, dynamic> appeal) async {
    final input = await form('Nhận khiếu nại cho tôi', const [workflowReason]);
    if (input != null) {
      await command('/admin/moderation-v2/appeals/${appeal['id']}/assign', {
        ...input,
        'version': appeal['version'],
        'assigneeId': workflowOwner
      });
    }
  }

  Future<void> bulk() async {
    final options = kind == 'LISTING'
        ? const {'PUBLISH': 'Xuất bản', 'REJECT': 'Từ chối'}
        : kind == 'REPORT'
            ? const {'RESOLVED': 'Đã xử lý', 'DISMISSED': 'Bác báo cáo'}
            : const {
                'APPROVED': 'Chấp thuận',
                'REJECTED': 'Từ chối',
                'HIDDEN': 'Ẩn'
              };
    final input = await form('Xử lý ${selected.length} mục đã chọn', [
      WorkflowField('decision', 'Quyết định', choices: options),
      workflowReason
    ]);
    if (input == null) return;
    final items = selected.values
        .map((row) => {
              'id': row['id'],
              'kind': kind,
              'version': row['version'],
              'decision': input['decision']
            })
        .toList();
    final proceed = await confirmBulk({
      'reason': input['reason'],
      'items': items,
    });
    if (proceed != true || !active) return;
    final result = await command('/admin/moderation-v2/bulk', {
      'reason': input['reason'],
      'items': items,
    });
    if (result != null && active) {
      setState(() {
        bulkResult = result;
        selected.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    final kinds = <String, String>{
      if (rights?.has('admin.listings.moderate') == true) 'LISTING': 'Tin đăng',
      if (rights?.has('admin.listings.moderate') == true)
        'REPORT': 'Báo cáo tin',
      if (rights?.has('admin.reviews.moderate') == true) 'REVIEW': 'Đánh giá',
      if (rights?.has('admin.reviews.moderate') == true) 'REPLY': 'Phản hồi'
    };
    final currentKind = kinds.containsKey(kind)
        ? kind
        : (kinds.isEmpty ? 'LISTING' : kinds.keys.first);
    return AdminWorkspaceScaffold(
      title: 'Moderation v2',
      location: '/admin/moderation-v2',
      busy: busy,
      body: !active
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.all(20), children: [
              AdminSectionPanel(
                icon: Icons.verified_outlined,
                title: 'Xử lý minh bạch, có truy vết',
                subtitle:
                    'Người ra quyết định gốc không tự xét khiếu nại. Mọi thay đổi đều kiểm tra phiên bản.',
                children: [
                  ...operationState,
                  if (rights?.has('admin.moderation.reports') == true)
                    resource(
                        const AdminRequest(
                            '/admin/moderation-v2/reports', {'days': 30}),
                        (response) {
                      final data = workflowData(response);
                      final decisions =
                          (data['decisions'] as List? ?? []).whereType<Map>();
                      final appeals =
                          (data['appeals'] as List? ?? []).whereType<Map>();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background
                              .withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminOverviewTheme.line),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Báo cáo 30 ngày',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                  '${decisions.fold<int>(0, (total, row) => total + ((row['total'] as num?)?.toInt() ?? 0))} quyết định · ${appeals.fold<int>(0, (total, row) => total + ((row['total'] as num?)?.toInt() ?? 0))} khiếu nại · ${data['escalations'] ?? 0} escalation'),
                              const SizedBox(height: 8),
                              for (final row in (data['queue'] as List? ?? [])
                                  .whereType<Map>())
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: AdminOverviewTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AdminOverviewTheme.line),
                                  ),
                                  child: ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      title: Text(
                                          '${row['kind']}: ${row['total']} đang chờ'),
                                      subtitle: Text(
                                          '${row['overdue']} quá hạn SLA')),
                                ),
                            ]),
                      );
                    }),
                ],
              ),
              if (rights?.has('admin.moderation.appeals') == true) ...[
                const SizedBox(height: 20),
                AdminSectionPanel(
                  icon: Icons.gavel_outlined,
                  title: 'Khiếu nại / tranh chấp',
                  child: resource(
                      AdminRequest('/admin/moderation-v2/appeals',
                          {'page': appealPage, 'limit': 20}),
                      (response) => Column(children: [
                            if (workflowRows(response).isEmpty)
                              const WorkflowEmpty('Chưa có khiếu nại.'),
                            for (final appeal in workflowRows(response))
                              Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AdminOverviewTheme.background
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AdminOverviewTheme.line),
                                  ),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                  '${workflowLabel(appeal['status'])} · ${(appeal['decision'] as Map?)?['kind'] ?? ''}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                            ),
                                            AdminStatusBadge.fromStatus(
                                                appeal['status']),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('${appeal['reason']}'),
                                        Text(
                                            'Hạn xử lý: ${workflowDate(appeal['dueAt'])}'),
                                        if (appeal['status'] == 'OPEN')
                                          Wrap(spacing: 8, children: [
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => assign(appeal),
                                                child:
                                                    const Text('Nhận xử lý')),
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => resolve(appeal),
                                                child:
                                                    const Text('Xét khiếu nại'))
                                          ]),
                                        if (appeal['resolution'] != null)
                                          Text(
                                              'Kết luận: ${appeal['resolution']}'),
                                      ])),
                            WorkflowPager(
                                page: appealPage,
                                total: ((response['meta'] as Map?)?['total']
                                            as num?)
                                        ?.toInt() ??
                                    0,
                                limit: 20,
                                onPage: (value) =>
                                    setState(() => appealPage = value)),
                          ])),
                ),
              ],
              if (rights?.has('admin.moderation.bulk') == true &&
                  kinds.isNotEmpty) ...[
                const SizedBox(height: 20),
                AdminSectionPanel(
                  icon: Icons.checklist_rtl_outlined,
                  title: 'Kiểm duyệt hàng loạt',
                  trailing: DropdownButton<String>(
                      value: currentKind,
                      items: kinds.entries
                          .map((entry) => DropdownMenuItem(
                              value: entry.key, child: Text(entry.value)))
                          .toList(),
                      onChanged: (value) => setState(() {
                            kind = value!;
                            selected.clear();
                            bulkResult = null;
                          })),
                  children: [
                    resource(
                        AdminRequest('/admin/moderation/queue',
                            {'kind': currentKind, 'limit': 25, 'page': 1}),
                        (response) => Column(children: [
                              if (workflowRows(response).isEmpty)
                                const WorkflowEmpty(
                                    'Không có nội dung đang chờ.'),
                              for (final row in workflowRows(response))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: selected.containsKey(row['id'])
                                        ? AdminOverviewTheme.background
                                        : AdminOverviewTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected.containsKey(row['id'])
                                          ? AdminOverviewTheme.blue
                                              .withValues(alpha: 0.5)
                                          : AdminOverviewTheme.line,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      value: selected.containsKey(row['id']),
                                      title: Text('${row['title']}'),
                                      subtitle: Text(
                                          'v${row['version']} · hạn ${workflowDate(row['dueAt'])}'),
                                      onChanged: busy
                                          ? null
                                          : (value) => setState(() {
                                                if (value == true) {
                                                  selected['${row['id']}'] =
                                                      row;
                                                  kind = currentKind;
                                                } else {
                                                  selected.remove(row['id']);
                                                }
                                              })),
                                ),
                            ])),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                            onPressed: busy || selected.isEmpty ? null : bulk,
                            child: Text('Xử lý ${selected.length}/25 mục'))),
                    if (bulkResult != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          'Thành công: ${(bulkResult!['summary'] as Map?)?['succeeded']} · Lỗi: ${(bulkResult!['summary'] as Map?)?['failed']}'),
                      for (final row in workflowRows(bulkResult!))
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              row['success'] == true
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: row['success'] == true
                                  ? AdminOverviewTheme.green
                                  : AdminOverviewTheme.red,
                            ),
                            title: Text('${row['kind']} · ${row['id']}'),
                            subtitle: Text(row['success'] == true
                                ? 'Đã xử lý'
                                : '${row['status']}: ${row['message']}')),
                    ],
                  ],
                ),
              ],
              if (rights?.has('admin.moderation.reports') == true) ...[
                const SizedBox(height: 20),
                AdminSectionPanel(
                  icon: Icons.history_outlined,
                  title: 'Lịch sử quyết định',
                  child: resource(
                      AdminRequest('/admin/moderation-v2/decisions',
                          {'page': decisionPage, 'limit': 20}),
                      (response) => Column(children: [
                            if (workflowRows(response).isEmpty)
                              const WorkflowEmpty(
                                  'Chưa có quyết định trong phạm vi quyền.'),
                            for (final row in workflowRows(response))
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AdminOverviewTheme.background
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AdminOverviewTheme.line),
                                ),
                                child: ListTile(
                                    onTap: busy ? null : () => history(row),
                                    trailing: const Icon(Icons.history),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    title: Text(
                                        '${row['kind']} · ${row['fromStatus']} → ${row['toStatus']}'),
                                    subtitle: Text(
                                        '${row['reason']}\n${workflowDate(row['createdAt'])} · v${row['version']} · ${row['source']}')),
                              ),
                            WorkflowPager(
                                page: decisionPage,
                                total: ((response['meta'] as Map?)?['total']
                                            as num?)
                                        ?.toInt() ??
                                    0,
                                limit: 20,
                                onPage: (value) =>
                                    setState(() => decisionPage = value)),
                          ])),
                ),
              ],
            ]),
    );
  }
}
