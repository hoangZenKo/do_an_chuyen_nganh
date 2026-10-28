import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminDeliveryJobsPanel extends ConsumerStatefulWidget {
  const AdminDeliveryJobsPanel({super.key});
  @override
  ConsumerState<AdminDeliveryJobsPanel> createState() =>
      _AdminDeliveryJobsState();
}

class _AdminDeliveryJobsState extends WorkflowState<AdminDeliveryJobsPanel> {
  bool expanded = false;
  int page = 1;
  String status = 'DEAD';

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    if (!active || !can('admin.operations.view')) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const Icon(
            Icons.outgoing_mail,
            color: AdminOverviewTheme.amber,
            size: 20,
          ),
          title: const Text(
            'Email và cảnh báo: job cần điều tra',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
              'Chỉ đọc metadata; không replay payload hoặc hiển thị link kích hoạt.'),
          onExpansionChanged: (value) => setState(() => expanded = value),
          children: [
            if (expanded) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Trạng thái job', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'DEAD', child: Text('Dead letter')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Đang chờ')),
                  DropdownMenuItem(
                      value: 'PROCESSING', child: Text('Đang xử lý')),
                  DropdownMenuItem(value: 'SENT', child: Text('Đã gửi')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('Đã hủy')),
                ],
                onChanged: (value) => setState(() {
                  status = value ?? 'DEAD';
                  page = 1;
                }),
              ),
              const SizedBox(height: 12),
              resource(
                  AdminRequest('/admin/operations/delivery-jobs', {
                    'jobStatus': status,
                    'page': page,
                    'limit': 20
                  }), (response) {
                final rows = workflowRows(response);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (rows.isEmpty)
                        const WorkflowEmpty(
                            'Không có job trong trạng thái này.'),
                      for (final job in rows)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AdminOverviewTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: workflowStatusColor(job['status'])
                                  .withValues(alpha: 0.38),
                            ),
                          ),
                          child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              title: SelectableText(
                                '${job['id']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                  '${job['kind']} · ${workflowLabel(job['status'])} · ${job['attempts']} lần thử\n${job['lastError'] ?? 'Không có mã lỗi'} · Cập nhật ${workflowDate(job['updatedAt'])}')),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Không có nút retry cho email/cảnh báo: dead letter đã bỏ payload. Với lời mời admin chưa kích hoạt, dùng Gửi lại lời mời trong Rà soát quyền; không replay trực tiếp database.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AdminOverviewTheme.muted),
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
          ],
        ),
      ),
    );
  }
}
