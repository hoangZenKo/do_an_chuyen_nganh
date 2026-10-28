import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_overview_theme.dart';
import '../../data/admin/finance_statement_csv.dart';
import '../auth/auth_providers.dart';
import 'admin_console_providers.dart';
import 'admin_providers.dart';
import 'admin_workflow_widgets.dart';

class AdminFinanceWorkflow extends ConsumerStatefulWidget {
  const AdminFinanceWorkflow({super.key});
  @override
  ConsumerState<AdminFinanceWorkflow> createState() => _FinanceWorkflowState();
}

class _FinanceWorkflowState extends WorkflowState<AdminFinanceWorkflow> {
  String filter = 'UNMATCHED';
  String? importSummary;
  Future<void> importStatement() async {
    if (!active || busy) return;
    List<Map<String, dynamic>> lines;
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (!active || result == null) return;
      final file = result.files.single;
      if (file.bytes == null || file.size > 1024 * 1024) {
        throw const FormatException('Chọn file CSV tối đa 1 MB.');
      }
      lines = parseFinanceStatementCsv(utf8.decode(file.bytes!));
    } catch (error) {
      if (active) setState(() => failure = '$error');
      return;
    }
    final input = await form('Nhập ${lines.length} giao dịch sao kê', [
      const WorkflowField('propertyId', 'Mã khu trọ (UUID)', maxLength: 36),
      const WorkflowField(
          'accountKey', 'Bí danh tài khoản (không nhập số tài khoản)',
          maxLength: 160),
      const WorkflowField('importKey', 'Mã lô nhập duy nhất', maxLength: 160),
      workflowReason,
    ]);
    if (input == null) {
      return;
    }
    final result =
        await command('/admin/finance/statements', {...input, 'lines': lines});
    if (result != null && active) {
      final data = workflowData(result);
      setState(() => importSummary = data['duplicate'] == true
          ? 'Lô này đã được nhập, không tạo giao dịch trùng.'
          : 'Đã nhập ${data['lines']} dòng: ${data['matched']} khớp, ${data['unmatched']} cần kiểm tra.');
    }
  }

  Future<void> propose(Map<String, dynamic> line) async {
    if (!active || busy) return;
    var candidates = <Map<String, dynamic>>[];
    if (line['status'] != 'MATCHED') {
      setState(() {
        busy = true;
        failure = null;
      });
      try {
        candidates = workflowRows(await ref.read(adminApiProvider).resource(
            '/admin/finance/statement-lines/${line['id']}/candidates'));
      } catch (error) {
        if (active) {
          setState(() => failure = 'Chưa tải được gợi ý đối soát: $error');
        }
        return;
      } finally {
        if (active) setState(() => busy = false);
      }
      if (!active) return;
    }
    final input = await form('Đề xuất xử lý đối soát', [
      WorkflowField('action', 'Thao tác',
          choices: line['status'] == 'MATCHED'
              ? const {'UNMATCH': 'Gỡ liên kết thanh toán'}
              : {
                  if (candidates.isNotEmpty)
                    'MATCH_TARGET': 'Liên kết giao dịch được chọn',
                  'MATCH_PAYMENT': 'Liên kết thanh toán hiện có',
                  'MATCH_RECEIPT': 'Liên kết khoản thu nhiều hóa đơn',
                  'MARK_REVIEWED': 'Đánh dấu cần kiểm tra thêm'
                }),
      if (candidates.isNotEmpty)
        WorkflowField('candidate', 'Gợi ý cùng số tiền / khu trọ',
            minLength: 0,
            choices: {
              '': 'Chọn giao dịch hoặc nhập mã bên dưới',
              for (final candidate in candidates)
                '${candidate['kind']}:${candidate['id']}':
                    '${candidate['kind'] == 'RECEIPT' ? 'Khoản thu' : 'Thanh toán'} · ${candidate['tenantName'] ?? candidate['reference'] ?? candidate['id']} · ${workflowDate(candidate['paidAt'])}',
            }),
      const WorkflowField('paymentId', 'Mã thanh toán (chỉ khi liên kết)',
          minLength: 0, maxLength: 36),
      const WorkflowField('receiptId', 'Mã khoản thu (khi liên kết khoản thu)',
          minLength: 0, maxLength: 36),
      workflowReason,
    ]);
    if (input == null) return;
    if (input['action'] == 'MATCH_TARGET') {
      final selected = input['candidate'] ?? '';
      if (selected.isEmpty) {
        setState(() => failure = 'Chọn một giao dịch để đề xuất liên kết.');
        return;
      }
      final receipt = selected.startsWith('RECEIPT:');
      input['action'] = receipt ? 'MATCH_RECEIPT' : 'MATCH_PAYMENT';
      input[receipt ? 'receiptId' : 'paymentId'] =
          selected.substring(selected.indexOf(':') + 1);
    }
    if (input['action'] == 'MATCH_PAYMENT' && input['paymentId']!.isEmpty) {
      setState(() => failure = 'Cần mã thanh toán khi đề xuất liên kết.');
      return;
    }
    if (input['action'] == 'MATCH_RECEIPT' && input['receiptId']!.isEmpty) {
      setState(() => failure = 'Cần mã khoản thu khi đề xuất liên kết.');
      return;
    }
    await command('/admin/finance/statement-lines/${line['id']}/proposals', {
      'action': input['action'],
      'lineVersion': line['version'],
      'reason': input['reason'],
      if (input['action'] == 'MATCH_PAYMENT') 'paymentId': input['paymentId'],
      if (input['action'] == 'MATCH_RECEIPT') 'receiptId': input['receiptId'],
    });
  }

  Future<void> review(Map<String, dynamic> proposal, bool approve) async {
    final input = await form(
        approve ? 'Duyệt đề xuất độc lập' : 'Từ chối đề xuất',
        const [workflowReason]);
    if (input != null) {
      await command(
          '/admin/finance/reconciliation-proposals/${proposal['id']}/${approve ? 'approve' : 'reject'}',
          {...input, 'version': proposal['lineVersion']});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionIdentityProvider);
    ref.watch(adminCapabilitiesProvider);
    if (!active) return const SizedBox.shrink();
    final manage = can('admin.finance.reconcile');
    return AdminSectionPanel(
      icon: Icons.receipt_long_outlined,
      title: 'Đối soát sao kê ngân hàng',
      subtitle:
          'Chỉ liên kết dữ liệu đối soát; không sửa hóa đơn hoặc sổ thanh toán. Người lập không tự duyệt đề xuất.',
      children: [
        if (manage) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminOverviewTheme.background.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminOverviewTheme.line),
            ),
            child: const SelectableText(
                'CSV UTF-8: externalId,amount,occurredAt,reference\nVí dụ: TX01,1500000,2026-10-26T08:00:00+07:00,mã-receipt-hoặc-payment-hoặc-invoice'),
          ),
          const SizedBox(height: 10),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: busy ? null : importStatement,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Nhập sao kê CSV'))),
          const SizedBox(height: 12),
        ],
        if (importSummary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(importSummary!),
          ),
        ...operationState,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final status in ['UNMATCHED', 'MATCHED', 'NEEDS_REVIEW'])
            ChoiceChip(
                label: Text(workflowLabel(status)),
                selected: filter == status,
                onSelected: (_) => setState(() => filter = status))
        ]),
        const SizedBox(height: 12),
        resource(
            AdminRequest('/admin/finance/statement-lines',
                {'status': filter, 'limit': 50}),
            (response) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (workflowRows(response).isEmpty)
                      const WorkflowEmpty(
                          'Chưa có giao dịch ở trạng thái này.'),
                    for (final line in workflowRows(response))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AdminOverviewTheme.background
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminOverviewTheme.line),
                        ),
                        child: ListTile(
                            title: Text(
                              '${line['amount']} đ · ${line['externalId']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                                '${line['reference']}\n${workflowDate(line['occurredAt'])} · v${line['version']}${line['receiptId'] == null ? '' : '\nKhoản thu: ${line['receiptId']}'}'),
                            trailing: manage
                                ? IconButton(
                                    tooltip: 'Đề xuất xử lý',
                                    onPressed:
                                        busy ? null : () => propose(line),
                                    icon: const Icon(Icons.fact_check_outlined))
                                : null),
                      ),
                    Text(
                      'Hiển thị tối đa 50 dòng mới nhất theo trạng thái.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AdminOverviewTheme.muted),
                    ),
                  ],
                )),
        if (manage)
          resource(
              const AdminRequest('/admin/finance/reconciliation-proposals'),
              (response) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 28),
                        Text('Đề xuất chờ người thứ hai duyệt',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (workflowRows(response).isEmpty)
                          const WorkflowEmpty('Không có đề xuất chờ duyệt.'),
                        for (final proposal in workflowRows(response))
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AdminOverviewTheme.background
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AdminOverviewTheme.line),
                            ),
                            child: ListTile(
                                title: Text(
                                    '${proposal['action']} · ${(proposal['line'] as Map?)?['amount']} đ'),
                                subtitle: Text(
                                    '${proposal['reason']}\n${proposal['makerId'] == workflowOwner ? 'Bạn là người lập; cần admin khác duyệt.' : 'Người lập: ${proposal['makerId']}'}'),
                                trailing: proposal['makerId'] == workflowOwner
                                    ? null
                                    : PopupMenuButton<bool>(
                                        enabled: !busy,
                                        onSelected: (approve) =>
                                            review(proposal, approve),
                                        itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                  value: true,
                                                  child: Text('Duyệt')),
                                              PopupMenuItem(
                                                  value: false,
                                                  child: Text('Từ chối'))
                                            ])),
                          ),
                      ])),
      ],
    );
  }
}
