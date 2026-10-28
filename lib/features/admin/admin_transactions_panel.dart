import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminTransactionsPanel extends ConsumerStatefulWidget {
  const AdminTransactionsPanel({super.key});
  @override
  ConsumerState<AdminTransactionsPanel> createState() => _TransactionsState();
}

class _TransactionsState extends WorkflowState<AdminTransactionsPanel> {
  final search = TextEditingController();
  String kind = 'LINK', status = 'ALL', appliedSearch = '';
  int page = 1;
  late DateTimeRange range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now());
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    final rights = ref.watch(adminCapabilitiesProvider);
    if (!active ||
        rights.isLoading ||
        rights.hasError ||
        !can('admin.finance.read')) {
      return const WorkflowEmpty('Bạn không có quyền xem giao dịch.');
    }
    final statuses = kind == 'LINK'
        ? const {
            'PENDING': 'Chờ thanh toán',
            'PAID': 'Đã trả',
            'FAILED': 'Lỗi',
            'EXPIRED': 'Hết hạn',
            'CANCELLED': 'Đã hủy'
          }
        : kind == 'PAYMENT'
            ? const {'PAYMENT': 'Thu tiền', 'REFUND': 'Hoàn tiền'}
            : const {'RECONCILED': 'Đã đối soát'};
    return AdminSectionPanel(
        title: 'Điều tra giao dịch',
        icon: Icons.receipt_long_outlined,
        subtitle:
            'Chỉ đọc dữ liệu tiền thuê, không phải doanh thu nền tảng. Không retry webhook, không sửa trạng thái hay sổ tiền. Giao dịch lỗi cần đối chiếu nguồn và xử lý bằng quy trình đối soát hai người.',
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final entry in const {
              'LINK': 'Lệnh thanh toán',
              'PAYMENT': 'Thu / hoàn',
              'EVENT': 'Sự kiện đối soát'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: kind == entry.key,
                  onSelected: (_) => setState(() {
                        kind = entry.key;
                        status = 'ALL';
                        page = 1;
                      })),
            OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                    '${workflowDate(range.start)} — ${workflowDate(range.end)}'),
                onPressed: () async {
                  final result = await showDateRangePicker(
                      context: context,
                      initialDateRange: range,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now());
                  if (result != null && active) {
                    setState(() {
                      range = result;
                      page = 1;
                    });
                  }
                }),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: search,
              maxLength: 100,
              decoration: InputDecoration(
                  labelText:
                      'Mã giao dịch / hóa đơn / order code / reference sự kiện',
                  suffixIcon: IconButton(
                      tooltip: 'Áp dụng tìm kiếm',
                      onPressed: () => setState(() {
                            appliedSearch = search.text.trim();
                            page = 1;
                          }),
                      icon: const Icon(Icons.search))),
              onSubmitted: (value) => setState(() {
                    appliedSearch = value.trim();
                    page = 1;
                  })),
          DropdownButtonFormField<String>(
              isExpanded: true,
              value: status,
              decoration: const InputDecoration(labelText: 'Trạng thái / loại'),
              items: {'ALL': 'Tất cả', ...statuses}
                  .entries
                  .map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) => setState(() {
                    status = value!;
                    page = 1;
                  })),
          const SizedBox(height: 16),
          resource(
              AdminRequest('/admin/finance/transactions', {
                'kind': kind,
                'page': page,
                'limit': 20,
                'from': range.start.toUtc().toIso8601String(),
                'to': DateTime(range.end.year, range.end.month, range.end.day,
                        23, 59, 59, 999)
                    .toUtc()
                    .toIso8601String(),
                if (status != 'ALL') 'status': status,
                if (appliedSearch.isNotEmpty) 'search': appliedSearch
              }), (response) {
            final rows = workflowRows(response);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rows.isEmpty)
                    const WorkflowEmpty(
                        'Không có giao dịch trong bộ lọc đã chọn.'),
                  for (final row in rows)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                      '${row['id']}\n${row['amount']} VND · ${row['status'] ?? row['type']}\nHóa đơn: ${row['invoiceId'] ?? 'Xem lệnh gốc'}\n${row['paidAt'] ?? row['createdAt']}'),
                                  if (row['provider'] != null)
                                    Text(
                                        'Nguồn: ${row['provider']} · order ${row['orderCode']}'),
                                  if (row['expiresAt'] != null)
                                    Text('Hạn lệnh: ${row['expiresAt']}'),
                                  for (final event
                                      in (row['events'] as List? ?? [])
                                          .whereType<Map>())
                                    Text(
                                        'Sự kiện: ${event['id']} · ${event['status']} · ${event['createdAt']}'),
                                  Wrap(spacing: 8, children: [
                                    TextButton(
                                        onPressed: () => context.go(
                                            adminFinanceReconciliationRoute),
                                        child: const Text('Mở đối soát')),
                                    if (can('admin.support.read'))
                                      TextButton(
                                          onPressed: () => context
                                              .go(adminSupportCenterRoute),
                                          child: const Text('Hồ sơ hỗ trợ')),
                                    if (can('admin.audit.view'))
                                      TextButton(
                                          onPressed: () => context.go(Uri(
                                                  path: adminAuditLogsRoute,
                                                  queryParameters: {
                                                    'resourceId': '${row['id']}'
                                                  }).toString()),
                                          child: const Text('Nhật ký')),
                                  ]),
                                ]))),
                  WorkflowPager(
                      page: page,
                      total: (response['meta'] as Map?)?['total'] as int? ??
                          rows.length,
                      limit: 20,
                      onPage: (value) => setState(() => page = value)),
                ]);
          }),
        ]);
  }
}
