import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/reports.dart';
import '../notifications/notifications_providers.dart';
import '../rooms/property_selection_provider.dart';
import '../billing/billing_providers.dart';
import '../auth/auth_navigation.dart';
import '../auth/auth_providers.dart';
import '../../core/network/api_failure.dart';
import '../../core/utils/request_key.dart';
import 'reports_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(monthlyReportProvider);
    final remindersAsync = ref.watch(billingRemindersProvider);
    final session = ref.watch(sessionControllerProvider).session;
    final propertyId = ref.watch(selectedPropertyProvider);
    final canManagePolicy = sessionHasPermission(session, 'billing.policy') &&
        (session?.user.role != 'staff' || propertyId != null);
    final policyAsync =
        canManagePolicy ? ref.watch(billingReminderPolicyProvider) : null;
    final month = ref.watch(selectedReportMonthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('Báo cáo'),
        actions: [
          IconButton(
            tooltip: 'Xuất CSV',
            onPressed: () => _exportCsv(context, ref),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(monthlyReportProvider);
          ref.invalidate(billingRemindersProvider);
          ref.invalidate(billingReminderPolicyProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MonthPicker(month: month),
            const SizedBox(height: 12),
            reportAsync.when(
              loading: () => const _LoadingCard(),
              error: (error, _) => _Card(child: Text('$error')),
              data: (report) => _ReportSummary(report: report),
            ),
            const SizedBox(height: 12),
            remindersAsync.when(
              loading: () => const _LoadingCard(),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => _ReminderCard(items: items),
            ),
            if (policyAsync != null) ...[
              const SizedBox(height: 12),
              policyAsync.when(
                loading: () => const _LoadingCard(),
                error: (error, _) => _Card(child: Text('$error')),
                data: (payload) => ReminderPolicyCard(
                    payload: payload, propertyId: propertyId),
              ),
            ],
            const SizedBox(height: 12),
            reportAsync.maybeWhen(
              data: (report) => _InvoiceDebtCard(invoices: report.invoices),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final month = ref.read(selectedReportMonthProvider);
    final propertyId = ref.read(selectedPropertyProvider);
    final export = await ref.read(reportsApiProvider).monthlyExport(
          month: month.toIso8601String(),
          propertyId: propertyId,
        );
    await Clipboard.setData(ClipboardData(text: export.content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã copy CSV: ${export.filename}')),
    );
  }
}

class ReminderPolicyCard extends ConsumerWidget {
  const ReminderPolicyCard({super.key, required this.payload, this.propertyId});

  final Map<String, dynamic> payload;
  final String? propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy =
        (payload['policy'] as Map?)?.cast<String, dynamic>() ?? const {};
    final inherited = (payload['inherited'] as Map?)?.cast<String, dynamic>();
    final effective = inherited ?? policy;
    final enabled = effective['enabled'] == true;
    final before = _days(effective['beforeDays'], const [3, 1]);
    final overdue = _days(effective['overdueDays'], const [1, 7, 30]);
    final channels = (effective['channels'] as List? ?? const [])
        .map((value) => value.toString())
        .join(', ');
    final scope = propertyId == null ? 'toàn chủ trọ' : 'khu trọ đang chọn';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: _Title('Chính sách nhắc nợ')),
            TextButton.icon(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _ReminderPolicyDialog(
                    payload: payload, propertyId: propertyId),
              ).then((saved) {
                if (saved == true) {
                  ref.invalidate(billingReminderPolicyProvider);
                }
              }),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Cấu hình'),
            ),
          ]),
          Text('Phạm vi: $scope',
              style: const TextStyle(color: Color(0xFF8891A8))),
          const SizedBox(height: 6),
          Text(enabled ? 'Đang bật' : 'Đang tắt',
              style: TextStyle(
                  color: enabled ? AppTheme.primary : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w800)),
          Text(
              'Trước hạn: ${before.isEmpty ? 'không nhắc' : '${before.join(', ')} ngày'} · Quá hạn: ${overdue.isEmpty ? 'không nhắc' : '${overdue.join(', ')} ngày'}${effective['onDueDate'] == true ? ' · đúng hạn' : ''}'),
          Text(channels.isEmpty ? 'Chưa chọn kênh gửi' : 'Kênh: $channels'),
          if (inherited != null)
            const Text('Đang kế thừa cấu hình mặc định của chủ trọ.'),
        ],
      ),
    );
  }

  static List<int> _days(Object? value, List<int> fallback) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : fallback;
}

class _ReminderPolicyDialog extends ConsumerStatefulWidget {
  const _ReminderPolicyDialog(
      {required this.payload, required this.propertyId});

  final Map<String, dynamic> payload;
  final String? propertyId;

  @override
  ConsumerState<_ReminderPolicyDialog> createState() =>
      _ReminderPolicyDialogState();
}

class _ReminderPolicyDialogState extends ConsumerState<_ReminderPolicyDialog> {
  late final TextEditingController _before;
  late final TextEditingController _overdue;
  late bool _enabled;
  late bool _onDueDate;
  late int _version;
  late Set<String> _channels;
  bool _saving = false;
  String? _error;
  String? _lastPayload;
  String? _requestKey;

  @override
  void initState() {
    super.initState();
    final ownPolicy =
        (widget.payload['policy'] as Map?)?.cast<String, dynamic>() ?? const {};
    final policy =
        (widget.payload['inherited'] as Map?)?.cast<String, dynamic>() ??
            ownPolicy;
    _before =
        TextEditingController(text: _join(policy['beforeDays'], const [3, 1]));
    _overdue = TextEditingController(
        text: _join(policy['overdueDays'], const [1, 7, 30]));
    _enabled = policy['enabled'] == true;
    _onDueDate = policy['onDueDate'] != false;
    _version = (ownPolicy['version'] as num?)?.toInt() ?? 0;
    _channels = (policy['channels'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
  }

  @override
  void dispose() {
    _before.dispose();
    _overdue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final before = _parse(_before.text, 365);
    final overdue = _parse(_overdue.text, 3650);
    if (before == null || overdue == null || (_enabled && _channels.isEmpty)) {
      setState(() => _error =
          'Mỗi danh sách tối đa 30 ngày không trùng. Trước hạn: 1–365; quá hạn: 1–3650. Chọn ít nhất một kênh khi bật.');
      return;
    }
    final channels = _channels.toList()..sort();
    final payload = jsonEncode([
      widget.propertyId,
      _version,
      _enabled,
      before,
      _onDueDate,
      overdue,
      channels
    ]);
    if (payload != _lastPayload) {
      _lastPayload = payload;
      _requestKey = newRequestKey();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(billingRepositoryProvider).updateReminderPolicy(
            requestKey: _requestKey!,
            expectedVersion: _version,
            propertyId: widget.propertyId,
            enabled: _enabled,
            beforeDays: before,
            onDueDate: _onDueDate,
            overdueDays: overdue,
            channels: channels,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiFailure
            ? error.message
            : 'Chưa lưu được. Hãy thử lại hoặc đóng và tải lại cấu hình.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Cấu hình nhắc nợ'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.propertyId == null
              ? 'Áp dụng mặc định cho toàn chủ trọ.'
              : 'Lưu sẽ tạo cấu hình riêng cho khu trọ này, thay cho mặc định của chủ trọ.'),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bật chính sách'),
              value: _enabled,
              onChanged:
                  _saving ? null : (value) => setState(() => _enabled = value)),
          TextField(
              controller: _before,
              enabled: !_saving,
              decoration: const InputDecoration(
                  labelText: 'Nhắc trước hạn (ngày)',
                  hintText: '3, 1',
                  helperText:
                      'Phân cách bằng dấu phẩy. Để trống nếu không nhắc.'),
              keyboardType: TextInputType.text),
          TextField(
              controller: _overdue,
              enabled: !_saving,
              decoration: const InputDecoration(
                  labelText: 'Nhắc quá hạn (ngày)', hintText: '1, 7, 30'),
              keyboardType: TextInputType.text),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nhắc đúng ngày đến hạn'),
              value: _onDueDate,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _onDueDate = value)),
          for (final channel in const ['APP', 'EMAIL', 'ZALO'])
            CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(channel),
                value: _channels.contains(channel),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => value == true
                        ? _channels.add(channel)
                        : _channels.remove(channel))),
          const Text(
              'EMAIL/ZALO cần cấu hình nhà cung cấp. Sở thích nhận tin của người thuê vẫn được tôn trọng. Lưu chính sách không gửi tin ngay.'),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
        ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu…' : 'Lưu'))
        ],
      ));

  static String _join(Object? value, List<int> fallback) =>
      _parseList(value)?.join(', ') ?? fallback.join(', ');
  static List<int>? _parseList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : null;
  static List<int>? _parse(String value, int maximum) {
    if (value.trim().isEmpty) return [];
    final values =
        value.split(',').map((item) => int.tryParse(item.trim())).toList();
    if (values.length > 30 ||
        values.toSet().length != values.length ||
        values.any((item) => item == null || item < 1 || item > maximum)) {
      return null;
    }
    return values.cast<int>()..sort();
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Row(
        children: [
          IconButton(
            onPressed: () => ref
                .read(selectedReportMonthProvider.notifier)
                .state = DateTime(month.year, month.month - 1, 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                formatMonth(month),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref
                .read(selectedReportMonthProvider.notifier)
                .state = DateTime(month.year, month.month + 1, 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final summary = report.summary;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Tổng hợp tháng'),
          const SizedBox(height: 12),
          _MetricRow('Đã thu', summary.receivedAmount),
          _MetricRow('Đã lập hóa đơn', summary.billedAmount),
          _MetricRow('Công nợ', summary.outstandingAmount, danger: true),
          _MetricRow('Chi phí', summary.expenseAmount),
          _MetricRow('Lợi nhuận ước tính', summary.estimatedProfit,
              strong: true),
          const Divider(height: 22),
          _MetricRow('Thu cọc', summary.depositCollected),
          _MetricRow('Hoàn/khấu trừ cọc', summary.depositReturned),
          Text(
            '${summary.activeLeases} hợp đồng active · ${summary.invoiceCount} hóa đơn',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8891A8)),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerStatefulWidget {
  const _ReminderCard({required this.items});

  final List<BillingReminder> items;

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  var _sendingZalo = false;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _Title('Nhắc nợ tự động')),
              if (widget.items.isNotEmpty)
                TextButton.icon(
                  onPressed: _sendingZalo ? null : () => _sendZalo(context),
                  icon: _sendingZalo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Gửi Zalo'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.items.isEmpty)
            const Text('Không có hóa đơn cần nhắc.')
          else
            ...widget.items.take(6).map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item.roomName ?? 'Phòng'} · ${formatCurrencyVnd(item.remainingAmount)}',
                    ),
                    subtitle: Text(item.tenantName ?? 'Tenant'),
                    trailing: IconButton(
                      tooltip: 'Copy lời nhắc',
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: item.suggestedMessage),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _sendZalo(BuildContext context) async {
    setState(() => _sendingZalo = true);
    try {
      final propertyId = ref.read(selectedPropertyProvider);
      final result = await ref
          .read(reportsApiProvider)
          .sendZaloInvoiceReminders(propertyId: propertyId);
      ref.invalidate(billingRemindersProvider);
      ref.invalidate(notificationDeliveriesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Zalo: gửi ${result.sent}/${result.total}, '
            'bỏ qua ${result.skipped}, lỗi ${result.failed}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không gửi được Zalo: $error')),
      );
    } finally {
      if (mounted) setState(() => _sendingZalo = false);
    }
  }
}

class _InvoiceDebtCard extends StatelessWidget {
  const _InvoiceDebtCard({required this.invoices});

  final List<ReportInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    final debts = invoices.where((item) => item.remainingAmount > 0).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Hóa đơn còn nợ'),
          const SizedBox(height: 8),
          if (debts.isEmpty)
            const Text('Không có công nợ trong tháng.')
          else
            ...debts.take(8).map(
                  (invoice) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(invoice.roomName ?? 'Phòng'),
                    subtitle: Text(invoice.tenantName ?? 'Khách thuê'),
                    trailing: Text(
                      formatCurrencyVnd(invoice.remainingAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(
    this.label,
    this.amount, {
    this.strong = false,
    this.danger = false,
  });

  final String label;
  final int amount;
  final bool strong;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatCurrencyVnd(amount),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: danger ? const Color(0xFFDC2626) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3348)),
      ),
      child: child,
    );
  }
}
