import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminNotificationQueue extends ConsumerStatefulWidget {
  const AdminNotificationQueue({super.key});
  @override
  ConsumerState<AdminNotificationQueue> createState() =>
      _NotificationQueueState();
}

class _NotificationQueueState extends WorkflowState<AdminNotificationQueue> {
  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    if (!active) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminOverviewTheme.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminOverviewTheme.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hàng đợi thông báo và dead letters',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...operationState,
        resource(const AdminRequest('/admin/operations/notification-delivery'),
            (response) {
          final data = workflowData(response);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final row
                      in (data['counts'] as List? ?? []).whereType<Map>())
                    Chip(
                        label: Text(
                            '${row['channel']} · ${workflowLabel(row['status'])}: ${row['_count']}'))
                ]),
                const SizedBox(height: 8),
                for (final job
                    in (data['dead'] as List? ?? []).whereType<Map>())
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AdminOverviewTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AdminOverviewTheme.red.withValues(alpha: 0.38)),
                    ),
                    child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        title: Text(
                          '${job['channel']} · ${job['lastError']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${job['attempts']} lần thử · ${workflowDate(job['createdAt'])}'),
                        trailing: can('admin.operations.manage')
                            ? IconButton(
                                tooltip: 'Thử lại thông báo',
                                icon: const Icon(Icons.replay),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final input = await form(
                                            'Gửi lại dead letter chưa hết hạn',
                                            const [workflowReason]);
                                        if (input != null) {
                                          await command(
                                              '/admin/operations/notification-delivery/${job['id']}/retry',
                                              input);
                                        }
                                      })
                            : null),
                  ),
                if ((data['dead'] as List? ?? []).isEmpty)
                  const Text('Không có dead letter cần xử lý.'),
              ]);
        }),
      ]),
    );
  }
}
