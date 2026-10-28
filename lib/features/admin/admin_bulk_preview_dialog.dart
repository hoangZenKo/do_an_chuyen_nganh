import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../auth/auth_providers.dart';
import 'admin_providers.dart';

class AdminBulkPreviewDialog extends ConsumerWidget {
  const AdminBulkPreviewDialog(
      {super.key,
      required this.preview,
      required this.owner,
      required this.permission});
  final Map<String, dynamic> preview;
  final String? owner;
  final String permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rights = ref.watch(adminCapabilitiesProvider).valueOrNull;
    final visible = owner != null &&
        ref.watch(sessionIdentityProvider) == owner &&
        rights?.has('admin.moderation.bulk') == true &&
        rights?.has(permission) == true;
    final rows =
        (preview['data'] as List? ?? const []).whereType<Map>().toList();
    final summary = preview['summary'] as Map? ?? const {};
    final ready = visible &&
        rows.isNotEmpty &&
        rows.every((row) => row['ready'] == true) &&
        summary['ready'] == rows.length &&
        summary['blocked'] == 0;
    return AlertDialog(
      backgroundColor: AdminOverviewTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminOverviewTheme.line),
      ),
      title: const Text('Xem trước kiểm duyệt hàng loạt'),
      content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!visible)
                    const Text(
                        'Phiên đăng nhập hoặc quyền truy cập đã thay đổi.')
                  else ...[
                    Text(
                        'Sẵn sàng: ${summary['ready'] ?? 0}/${rows.length} · Bị chặn: ${summary['blocked'] ?? rows.length}'),
                    const SizedBox(height: 8),
                    const Text(
                        'Chưa ghi quyết định. Hệ thống kiểm tra lại quyền, trạng thái và phiên bản khi xác nhận.'),
                    const SizedBox(height: 8),
                    for (final row in rows)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: row['ready'] == true
                                ? AdminOverviewTheme.line
                                : AdminOverviewTheme.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            row['ready'] == true
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            color: row['ready'] == true
                                ? AdminOverviewTheme.green
                                : AdminOverviewTheme.amber,
                          ),
                          title: Text('${row['kind']} · ${row['id']}'),
                          subtitle: Text(row['ready'] == true
                              ? '${row['currentStatus']} → ${row['decision']} · v${row['version']}'
                              : '${row['reason'] ?? 'Không kiểm tra được mục này.'}'),
                        ),
                      ),
                    if (!ready)
                      const Text(
                          'Tải lại hàng đợi và bỏ chọn các mục bị chặn trước khi tiếp tục.'),
                  ],
                ]),
          )),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy')),
        FilledButton(
            onPressed: ready ? () => Navigator.pop(context, true) : null,
            child: const Text('Xác nhận xử lý')),
      ],
    );
  }
}
