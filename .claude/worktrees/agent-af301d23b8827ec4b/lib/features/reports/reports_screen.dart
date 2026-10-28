import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/reports.dart';
import '../notifications/notifications_providers.dart';
import '../rooms/property_selection_provider.dart';
import 'reports_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(monthlyReportProvider);
    final remindersAsync = ref.watch(billingRemindersProvider);
    final month = ref.watch(selectedReportMonthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}
