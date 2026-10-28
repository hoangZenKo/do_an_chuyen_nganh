import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_workflow_widgets.dart';
import 'admin_workspace_scaffold.dart';

class AdminSessionsScreen extends ConsumerStatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  ConsumerState<AdminSessionsScreen> createState() =>
      _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends WorkflowState<AdminSessionsScreen> {
  Future<void> _revoke(String? id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminOverviewTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminOverviewTheme.line),
        ),
        title: Text(id == null
            ? 'Đăng xuất thiết bị khác?'
            : 'Thu hồi phiên đăng nhập?'),
        content: const Text(
            'Thiết bị bị thu hồi sẽ phải đăng nhập lại. Phiên hiện tại được giữ nguyên.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thu hồi')),
        ],
      ),
    );
    if (confirmed != true || !active) return;
    final result = await command(
        id == null ? '/auth/sessions/revoke-all' : '/auth/sessions/$id/revoke',
        const {});
    if (!mounted) return;
    if (result != null && active) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thu hồi phiên đăng nhập.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    if (!active) {
      return const Scaffold(
          body: Center(child: Text('Phiên đăng nhập đã thay đổi.')));
    }
    return AdminWorkspaceScaffold(
      title: 'Thiết bị đăng nhập',
      location: '/admin/sessions',
      busy: busy,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AdminSectionPanel(
            title: 'Quản lý phiên đăng nhập',
            subtitle:
                'Theo dõi các phiên còn hiệu lực. Địa chỉ mạng được che bớt; chuỗi thiết bị do trình duyệt cung cấp chỉ mang tính tham khảo.',
            icon: Icons.devices_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...operationState,
                resource(const AdminRequest('/auth/sessions'), (response) {
                  final rows =
                      (response['data'] as List).cast<Map<String, dynamic>>();
                  if (rows.isEmpty) {
                    return const Text('Không có phiên đăng nhập còn hiệu lực.');
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _revoke(null),
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất thiết bị khác'),
                        ),
                        const SizedBox(height: 16),
                        for (final row in rows)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AdminOverviewTheme.background,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AdminOverviewTheme.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(row['current'] == true
                                      ? Icons.verified_user_outlined
                                      : Icons.devices_outlined),
                                  title: Text(row['current'] == true
                                      ? 'Thiết bị hiện tại'
                                      : 'Thiết bị khác'),
                                  subtitle: Text(
                                      '${row['device']}\nMạng: ${row['ip'] ?? 'Không có'}\nHoạt động: ${workflowDate(row['lastSeenAt'])}'),
                                  isThreeLine: true,
                                ),
                                if (row['current'] != true)
                                  TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => _revoke(row['id'] as String),
                                    icon: const Icon(Icons.block_outlined),
                                    label: const Text('Thu hồi phiên này'),
                                  ),
                              ],
                            ),
                          ),
                      ]);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
