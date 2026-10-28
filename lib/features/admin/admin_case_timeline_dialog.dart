import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminCaseTimelineDialog extends ConsumerWidget {
  const AdminCaseTimelineDialog(
      {super.key, required this.data, required this.owner});
  final Map<String, dynamic> data;
  final String? owner;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(adminCapabilitiesProvider).valueOrNull;
    final visible = owner != null &&
        ref.watch(sessionIdentityProvider) == owner &&
        permissions?.has('admin.support.read') == true;
    final links = (data['links'] as List? ?? []).whereType<Map>().where((link) {
      final required = switch (link['kind']) {
        'INVOICE' => 'admin.finance.read',
        'INCIDENT' => 'admin.operations.view',
        'PROPERTY' || 'ROOM' => 'admin.properties.view',
        _ => 'admin.support.read',
      };
      return permissions?.has(required) == true;
    }).toList();
    return AlertDialog(
      backgroundColor: AdminOverviewTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminOverviewTheme.line),
      ),
      title: Text(
          visible ? 'Hồ sơ hỗ trợ / timeline' : 'Quyền truy cập đã thay đổi'),
      content: visible
          ? SizedBox(
              width: 720,
              child: SingleChildScrollView(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      '${(data['requester'] as Map?)?['fullName']} · ${(data['requester'] as Map?)?['role']}'),
                  const SizedBox(height: 12),
                  const Text(
                      'Dữ liệu chỉ đọc, được lọc theo quyền hiện tại. Không hiển thị email, số điện thoại hoặc secret.'),
                  const SizedBox(height: 20),
                  Text('Tài nguyên liên quan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (links.isEmpty)
                    const Text('Chưa có liên kết được phép xem.'),
                  for (final link in links)
                    Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminOverviewTheme.line),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${link['kind']} · ${(link['resource'] as Map?)?['name'] ?? (link['resource'] as Map?)?['title'] ?? link['targetId']}'),
                              if ((link['resource'] as Map?)?['status'] != null)
                                Text(
                                    'Trạng thái: ${(link['resource'] as Map)['status']}'),
                              if ((link['resource'] as Map?)?['totalAmount'] !=
                                  null)
                                Text(
                                    'Tổng: ${(link['resource'] as Map)['totalAmount']} đ · đã thu ${(link['resource'] as Map)['paidAmount']} đ'),
                            ])),
                  const Divider(height: 28),
                  Text('Lịch sử xử lý gần nhất',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final event
                      in (data['activity'] as List? ?? []).whereType<Map>())
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                            '${workflowDate(event['createdAt'])} · ${event['action']}\n${event['summary']}')),
                  const Divider(height: 28),
                  Text('Escalation SLA',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final escalation
                      in (data['escalations'] as List? ?? []).whereType<Map>())
                    Text(
                        '${escalation['kind']} · cấp ${escalation['level']} · ${workflowDate(escalation['createdAt'])}'),
                  const Divider(height: 28),
                  Text('Yêu cầu khác cùng người gửi',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final ticket in (data['relatedTickets'] as List? ?? [])
                      .whereType<Map>())
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(
                            '${ticket['subject']} · ${workflowLabel(ticket['status'])}\n${ticket['id']}')),
                ],
              )))
          : const Text('Đóng hộp thoại và tải lại hồ sơ.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Đóng'))
      ],
    );
  }
}
