class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.summary,
    required this.invoiceStatus,
    required this.expenseByCategory,
    required this.revenueByMethod,
    required this.invoices,
  });

  final DateTime? month;
  final ReportSummary summary;
  final Map<String, int> invoiceStatus;
  final List<ReportBucket> expenseByCategory;
  final List<ReportBucket> revenueByMethod;
  final List<ReportInvoice> invoices;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return MonthlyReport(
      month: _date(data['month']),
      summary: ReportSummary.fromJson(
        data['summary'] is Map<String, dynamic>
            ? data['summary'] as Map<String, dynamic>
            : const {},
      ),
      invoiceStatus: data['invoiceStatus'] is Map<String, dynamic>
          ? (data['invoiceStatus'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, _int(value)),
            )
          : const {},
      expenseByCategory: _list(data['expenseByCategory'])
          .map(ReportBucket.fromJson)
          .toList(growable: false),
      revenueByMethod: _list(data['revenueByMethod'])
          .map(ReportBucket.fromJson)
          .toList(growable: false),
      invoices: _list(data['invoices'])
          .map(ReportInvoice.fromJson)
          .toList(growable: false),
    );
  }
}

class ReportSummary {
  const ReportSummary({
    required this.activeLeases,
    required this.invoiceCount,
    required this.billedAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
    required this.expenseAmount,
    required this.estimatedProfit,
    required this.depositCollected,
    required this.depositReturned,
  });

  final int activeLeases;
  final int invoiceCount;
  final int billedAmount;
  final int receivedAmount;
  final int outstandingAmount;
  final int expenseAmount;
  final int estimatedProfit;
  final int depositCollected;
  final int depositReturned;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      activeLeases: _int(json['activeLeases']),
      invoiceCount: _int(json['invoiceCount']),
      billedAmount: _int(json['billedAmount']),
      receivedAmount: _int(json['receivedAmount']),
      outstandingAmount: _int(json['outstandingAmount']),
      expenseAmount: _int(json['expenseAmount']),
      estimatedProfit: _int(json['estimatedProfit']),
      depositCollected: _int(json['depositCollected']),
      depositReturned: _int(json['depositReturned']),
    );
  }
}

class ReportBucket {
  const ReportBucket({required this.label, required this.amount});
  final String label;
  final int amount;

  factory ReportBucket.fromJson(Map<String, dynamic> json) {
    return ReportBucket(
      label: (json['category'] ?? json['method'] ?? '').toString(),
      amount: _int(json['amount']),
    );
  }
}

class ReportInvoice {
  const ReportInvoice({
    required this.id,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.roomName,
    this.tenantName,
    this.dueDate,
  });

  final String id;
  final String? roomName;
  final String? tenantName;
  final int totalAmount;
  final int paidAmount;
  final int remainingAmount;
  final String status;
  final DateTime? dueDate;

  factory ReportInvoice.fromJson(Map<String, dynamic> json) {
    return ReportInvoice(
      id: json['id'] as String? ?? '',
      roomName: json['roomName'] as String?,
      tenantName: json['tenantName'] as String?,
      totalAmount: _int(json['totalAmount']),
      paidAmount: _int(json['paidAmount']),
      remainingAmount: _int(json['remainingAmount']),
      status: json['status'] as String? ?? 'unpaid',
      dueDate: _date(json['dueDate']),
    );
  }
}

class BillingReminder {
  const BillingReminder({
    required this.id,
    required this.kind,
    required this.invoiceId,
    required this.remainingAmount,
    required this.suggestedMessage,
    this.tenantName,
    this.roomName,
    this.dueDate,
    this.daysOverdue = 0,
    this.daysUntilDue,
  });

  final String id;
  final String kind;
  final String invoiceId;
  final String? tenantName;
  final String? roomName;
  final int remainingAmount;
  final DateTime? dueDate;
  final int daysOverdue;
  final int? daysUntilDue;
  final String suggestedMessage;

  factory BillingReminder.fromJson(Map<String, dynamic> json) {
    return BillingReminder(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'due_soon',
      invoiceId: json['invoiceId'] as String? ?? '',
      tenantName: json['tenantName'] as String?,
      roomName: json['roomName'] as String?,
      remainingAmount: _int(json['remainingAmount']),
      dueDate: _date(json['dueDate']),
      daysOverdue: _int(json['daysOverdue']),
      daysUntilDue:
          json['daysUntilDue'] == null ? null : _int(json['daysUntilDue']),
      suggestedMessage: json['suggestedMessage'] as String? ?? '',
    );
  }
}

class ZaloReminderSendResult {
  const ZaloReminderSendResult({
    required this.total,
    required this.sent,
    required this.failed,
    required this.skipped,
  });

  final int total;
  final int sent;
  final int failed;
  final int skipped;

  factory ZaloReminderSendResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return ZaloReminderSendResult(
      total: _int(data['total']),
      sent: _int(data['sent']),
      failed: _int(data['failed']),
      skipped: _int(data['skipped']),
    );
  }
}

class ReportExport {
  const ReportExport({
    required this.filename,
    required this.mimeType,
    required this.content,
  });

  final String filename;
  final String mimeType;
  final String content;

  factory ReportExport.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return ReportExport(
      filename: data['filename'] as String? ?? 'monthly-report.csv',
      mimeType: data['mimeType'] as String? ?? 'text/csv',
      content: data['content'] as String? ?? '',
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  final raw = value is List ? value : const [];
  return raw.whereType<Map<String, dynamic>>().toList(growable: false);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
