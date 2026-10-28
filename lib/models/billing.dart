import 'package:flutter/material.dart';

enum UtilityType {
  electricity,
  water;

  String get label => switch (this) {
        UtilityType.electricity => 'Điện',
        UtilityType.water => 'Nước',
      };

  static UtilityType fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return UtilityType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => UtilityType.electricity,
    );
  }
}

enum InvoiceStatus {
  unpaid,
  partial,
  paid,
  cancelled;

  String get label => switch (this) {
        InvoiceStatus.unpaid => 'Chưa thu',
        InvoiceStatus.partial => 'Thu một phần',
        InvoiceStatus.paid => 'Đã thu',
        InvoiceStatus.cancelled => 'Đã hủy',
      };

  Color get color => switch (this) {
        InvoiceStatus.unpaid => const Color(0xFFEF4444),
        InvoiceStatus.partial => const Color(0xFFF59E0B),
        InvoiceStatus.paid => const Color(0xFF10B981),
        InvoiceStatus.cancelled => const Color(0xFF9CA3AF),
      };

  static InvoiceStatus fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return InvoiceStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => InvoiceStatus.unpaid,
    );
  }
}

enum PaymentMethod {
  cash,
  bankTransfer,
  other;

  String get label => switch (this) {
        PaymentMethod.cash => 'Tiền mặt',
        PaymentMethod.bankTransfer => 'Chuyển khoản',
        PaymentMethod.other => 'Khác',
      };

  String get wire => switch (this) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.bankTransfer => 'bank_transfer',
        PaymentMethod.other => 'other',
      };

  static PaymentMethod fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    if (raw == 'bank_transfer' || raw == 'banktransfer') {
      return PaymentMethod.bankTransfer;
    }
    if (raw == 'other') return PaymentMethod.other;
    return PaymentMethod.cash;
  }
}

enum PaymentType {
  payment,
  reversal;

  String get label => switch (this) {
        PaymentType.payment => 'Thanh toán',
        PaymentType.reversal => 'Hoàn tác',
      };

  static PaymentType fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return raw == 'reversal' ? PaymentType.reversal : PaymentType.payment;
  }
}

class BillingLease {
  const BillingLease({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.tenantId,
    required this.tenantName,
    required this.monthlyRent,
    this.fixedFeeAmount = 0,
    this.fixedFees = const [],
    this.startDate,
  });

  final String id;
  final String roomId;
  final String roomName;
  final String tenantId;
  final String tenantName;
  final int monthlyRent;
  final int fixedFeeAmount;
  final List<BillingFixedFee> fixedFees;
  final DateTime? startDate;

  factory BillingLease.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BillingLease(
      id: data['id'] as String,
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? 'Phòng',
      tenantId: data['tenantId'] as String? ?? '',
      tenantName: data['tenantName'] as String? ?? 'Khách thuê',
      monthlyRent: _int(data['monthlyRent']),
      fixedFeeAmount: _int(data['fixedFeeAmount']),
      fixedFees: data['fixedFees'] is List
          ? (data['fixedFees'] as List)
              .whereType<Map<String, dynamic>>()
              .map(BillingFixedFee.fromJson)
              .toList(growable: false)
          : const [],
      startDate: _date(data['startDate']),
    );
  }
}

class BillingMeterReadingDraft {
  const BillingMeterReadingDraft({
    required this.utilityType,
    required this.previousReading,
    required this.currentReading,
    required this.unitPrice,
  });

  final UtilityType utilityType;
  final int previousReading;
  final int currentReading;
  final int unitPrice;

  Map<String, dynamic> toJson() => {
        'utilityType': utilityType.name,
        'previousReading': previousReading,
        'currentReading': currentReading,
        'unitPrice': unitPrice,
      };
}

class MeterReading {
  const MeterReading({
    required this.id,
    required this.roomId,
    required this.utilityType,
    required this.billingMonth,
    required this.previousReading,
    required this.currentReading,
    required this.unitPrice,
    required this.usage,
    required this.amount,
    this.note,
  });

  final String id;
  final String roomId;
  final UtilityType utilityType;
  final DateTime? billingMonth;
  final int previousReading;
  final int currentReading;
  final int unitPrice;
  final int usage;
  final int amount;
  final String? note;

  factory MeterReading.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return MeterReading(
      id: data['id'] as String,
      roomId: data['roomId'] as String? ?? '',
      utilityType: UtilityType.fromWire(data['utilityType']),
      billingMonth: _date(data['billingMonth']),
      previousReading: _int(data['previousReading']),
      currentReading: _int(data['currentReading']),
      unitPrice: _int(data['unitPrice']),
      usage: _int(data['usage']),
      amount: _int(data['amount']),
      note: data['note'] as String?,
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.type,
    this.reversalOfPaymentId,
    this.paidAt,
    this.note,
  });

  final String id;
  final String invoiceId;
  final int amount;
  final PaymentMethod method;
  final PaymentType type;
  final String? reversalOfPaymentId;
  final DateTime? paidAt;
  final String? note;

  bool get canReverse => type == PaymentType.payment;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return Payment(
      id: data['id'] as String,
      invoiceId: data['invoiceId'] as String? ?? '',
      amount: _int(data['amount']),
      method: PaymentMethod.fromWire(data['method']),
      type: PaymentType.fromWire(data['type']),
      reversalOfPaymentId: data['reversalOfPaymentId'] as String?,
      paidAt: _date(data['paidAt']),
      note: data['note'] as String?,
    );
  }
}

enum BulkInvoiceItemStatus {
  ready,
  existing,
  created;

  String get label => switch (this) {
        BulkInvoiceItemStatus.ready => 'Sẵn sàng',
        BulkInvoiceItemStatus.existing => 'Đã có hóa đơn',
        BulkInvoiceItemStatus.created => 'Đã tạo',
      };

  static BulkInvoiceItemStatus fromWire(Object? value) {
    final raw = value?.toString().toLowerCase().trim();
    return BulkInvoiceItemStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => BulkInvoiceItemStatus.ready,
    );
  }
}

class BulkUtilityReadings {
  const BulkUtilityReadings({this.electricity, this.water});

  final MeterReading? electricity;
  final MeterReading? water;

  factory BulkUtilityReadings.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const BulkUtilityReadings();
    return BulkUtilityReadings(
      electricity: json['electricity'] is Map<String, dynamic>
          ? MeterReading.fromJson(json['electricity'] as Map<String, dynamic>)
          : null,
      water: json['water'] is Map<String, dynamic>
          ? MeterReading.fromJson(json['water'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BulkInvoicePreflightItem {
  const BulkInvoicePreflightItem({
    required this.leaseId,
    required this.roomId,
    required this.roomName,
    required this.tenantId,
    required this.tenantName,
    required this.monthlyRent,
    required this.fixedFeeAmount,
    required this.fixedFees,
    required this.status,
    required this.meterReadings,
    required this.suggestedMeterReadings,
    this.invoice,
  });

  final String leaseId;
  final String roomId;
  final String roomName;
  final String tenantId;
  final String tenantName;
  final int monthlyRent;
  final int fixedFeeAmount;
  final List<BillingFixedFee> fixedFees;
  final BulkInvoiceItemStatus status;
  final Invoice? invoice;
  final BulkUtilityReadings meterReadings;
  final BulkUtilityReadings suggestedMeterReadings;

  bool get hasInvoice => status == BulkInvoiceItemStatus.existing;

  factory BulkInvoicePreflightItem.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BulkInvoicePreflightItem(
      leaseId: data['leaseId'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? 'Phòng',
      tenantId: data['tenantId'] as String? ?? '',
      tenantName: data['tenantName'] as String? ?? 'Khách thuê',
      monthlyRent: _int(data['monthlyRent']),
      fixedFeeAmount: _int(data['fixedFeeAmount']),
      fixedFees: data['fixedFees'] is List
          ? (data['fixedFees'] as List)
              .whereType<Map<String, dynamic>>()
              .map(BillingFixedFee.fromJson)
              .toList(growable: false)
          : const [],
      status: BulkInvoiceItemStatus.fromWire(data['status']),
      invoice: data['invoice'] is Map<String, dynamic>
          ? Invoice.fromJson(data['invoice'] as Map<String, dynamic>)
          : null,
      meterReadings: BulkUtilityReadings.fromJson(data['meterReadings']),
      suggestedMeterReadings:
          BulkUtilityReadings.fromJson(data['suggestedMeterReadings']),
    );
  }
}

class BillingFixedFee {
  const BillingFixedFee({
    required this.id,
    required this.name,
    required this.amount,
  });

  final String id;
  final String name;
  final int amount;

  factory BillingFixedFee.fromJson(Map<String, dynamic> json) {
    return BillingFixedFee(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: _int(json['amount']),
    );
  }
}

class BulkInvoicePreflight {
  const BulkInvoicePreflight({
    required this.propertyId,
    required this.billingMonth,
    required this.totalCount,
    required this.readyCount,
    required this.existingCount,
    required this.items,
  });

  final String propertyId;
  final DateTime? billingMonth;
  final int totalCount;
  final int readyCount;
  final int existingCount;
  final List<BulkInvoicePreflightItem> items;

  factory BulkInvoicePreflight.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    final items = data['items'] is List ? data['items'] as List : const [];
    return BulkInvoicePreflight(
      propertyId: data['propertyId'] as String? ?? '',
      billingMonth: _date(data['billingMonth']),
      totalCount: _int(data['totalCount']),
      readyCount: _int(data['readyCount']),
      existingCount: _int(data['existingCount']),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(BulkInvoicePreflightItem.fromJson)
          .toList(growable: false),
    );
  }
}

class BulkInvoiceGenerationItem {
  const BulkInvoiceGenerationItem({
    required this.leaseId,
    required this.status,
    required this.invoice,
  });

  final String leaseId;
  final BulkInvoiceItemStatus status;
  final Invoice invoice;

  factory BulkInvoiceGenerationItem.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BulkInvoiceGenerationItem(
      leaseId: data['leaseId'] as String? ?? '',
      status: BulkInvoiceItemStatus.fromWire(data['status']),
      invoice: Invoice.fromJson(data['invoice'] as Map<String, dynamic>),
    );
  }
}

class BulkInvoiceGenerationResult {
  const BulkInvoiceGenerationResult({
    required this.propertyId,
    required this.billingMonth,
    required this.totalCount,
    required this.createdCount,
    required this.existingCount,
    required this.results,
  });

  final String propertyId;
  final DateTime? billingMonth;
  final int totalCount;
  final int createdCount;
  final int existingCount;
  final List<BulkInvoiceGenerationItem> results;

  factory BulkInvoiceGenerationResult.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    final results =
        data['results'] is List ? data['results'] as List : const [];
    return BulkInvoiceGenerationResult(
      propertyId: data['propertyId'] as String? ?? '',
      billingMonth: _date(data['billingMonth']),
      totalCount: _int(data['totalCount']),
      createdCount: _int(data['createdCount']),
      existingCount: _int(data['existingCount']),
      results: results
          .whereType<Map<String, dynamic>>()
          .map(BulkInvoiceGenerationItem.fromJson)
          .toList(growable: false),
    );
  }
}

class BillingAutomation {
  const BillingAutomation({
    required this.id,
    required this.landlordId,
    required this.propertyId,
    required this.isEnabled,
    required this.invoiceDay,
    required this.dueDay,
    this.propertyName,
    this.lastRunMonth,
    this.lastRunAt,
  });

  final String id;
  final String landlordId;
  final String propertyId;
  final String? propertyName;
  final bool isEnabled;
  final int invoiceDay;
  final int dueDay;
  final DateTime? lastRunMonth;
  final DateTime? lastRunAt;

  factory BillingAutomation.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BillingAutomation(
      id: data['id'] as String? ?? '',
      landlordId: data['landlordId'] as String? ?? '',
      propertyId: data['propertyId'] as String? ?? '',
      propertyName: data['propertyName'] as String?,
      isEnabled: data['isEnabled'] == true,
      invoiceDay: _int(data['invoiceDay']),
      dueDay: _int(data['dueDay']),
      lastRunMonth: _date(data['lastRunMonth']),
      lastRunAt: _date(data['lastRunAt']),
    );
  }
}

class BillingAutomationPreview {
  const BillingAutomationPreview({
    required this.automation,
    required this.preflight,
    this.dueDate,
  });

  final BillingAutomation automation;
  final BulkInvoicePreflight preflight;
  final DateTime? dueDate;

  factory BillingAutomationPreview.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BillingAutomationPreview(
      automation: BillingAutomation.fromJson(
        data['automation'] as Map<String, dynamic>? ?? const {},
      ),
      dueDate: _date(data['dueDate']),
      preflight: BulkInvoicePreflight.fromJson(
        data['preflight'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class BillingAutomationRunResult {
  const BillingAutomationRunResult({
    required this.automation,
    required this.result,
    this.dueDate,
  });

  final BillingAutomation automation;
  final BulkInvoiceGenerationResult result;
  final DateTime? dueDate;

  factory BillingAutomationRunResult.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    return BillingAutomationRunResult(
      automation: BillingAutomation.fromJson(
        data['automation'] as Map<String, dynamic>? ?? const {},
      ),
      dueDate: _date(data['dueDate']),
      result: BulkInvoiceGenerationResult.fromJson(
        data['result'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class BulkInvoiceReadingDraft {
  const BulkInvoiceReadingDraft({
    required this.leaseId,
    required this.meterReadings,
  });

  final String leaseId;
  final List<BillingMeterReadingDraft> meterReadings;

  Map<String, dynamic> toJson() => {
        'leaseId': leaseId,
        'meterReadings':
            meterReadings.map((reading) => reading.toJson()).toList(),
      };
}

class InvoicePaymentProof {
  const InvoicePaymentProof({
    required this.id,
    required this.invoiceId,
    required this.tenantId,
    required this.amount,
    required this.method,
    required this.status,
    this.tenantName,
    this.note,
    this.proofImageUrls = const [],
    this.submittedAt,
    this.reviewedAt,
    this.reviewedById,
    this.reviewNote,
  });

  final String id;
  final String invoiceId;
  final String tenantId;
  final int amount;
  final PaymentMethod method;
  final String status;
  final String? tenantName;
  final String? note;
  final List<String> proofImageUrls;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedById;
  final String? reviewNote;

  factory InvoicePaymentProof.fromJson(Map<String, dynamic> json) {
    return InvoicePaymentProof(
      id: json['id'] as String? ?? '',
      invoiceId: json['invoiceId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      amount: _int(json['amount']),
      method: PaymentMethod.fromWire(json['method']),
      status: json['status'] as String? ?? 'pending',
      tenantName: json['tenantName'] as String?,
      note: json['note'] as String?,
      proofImageUrls: json['proofImageUrls'] is List
          ? (json['proofImageUrls'] as List)
              .map((value) => value.toString())
              .toList(growable: false)
          : const [],
      submittedAt: _date(json['submittedAt']),
      reviewedAt: _date(json['reviewedAt']),
      reviewedById: json['reviewedById'] as String?,
      reviewNote: json['reviewNote'] as String?,
    );
  }
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.id,
    required this.kind,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.amount,
    required this.source,
    this.tariffVersionId,
    this.tariffVersion,
  });

  final String id;
  final String kind;
  final String description;
  final int quantity;
  final String unit;
  final int unitPrice;
  final int amount;
  final String source;
  final String? tariffVersionId;
  final int? tariffVersion;

  bool get isLegacy => source == 'legacy';
  String get unitLabel => switch (unit) {
        'thang' => 'tháng',
        'lan' => 'lần',
        'm3' => 'm³',
        _ => unit,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> data) =>
      InvoiceLineItem(
        id: data['id'] as String? ?? '',
        kind: data['kind']?.toString().toLowerCase() ?? 'other',
        description: data['description'] as String? ?? '',
        quantity: _int(data['quantity']),
        unit: data['unit'] as String? ?? 'lan',
        unitPrice: _int(data['unitPrice']),
        amount: _int(data['amount']),
        source: data['source']?.toString().toLowerCase() ?? 'legacy',
        tariffVersionId: data['tariffVersionId'] as String?,
        tariffVersion: _intOrNull(data['tariffVersion']),
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.leaseId,
    required this.roomId,
    required this.tenantId,
    required this.billingMonth,
    required this.rentAmount,
    required this.electricityAmount,
    required this.waterAmount,
    required this.otherAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.revision = 1,
    this.replacesInvoiceId,
    this.replacementInvoiceId,
    this.adjustments = const [],
    this.isDemo = false,
    this.roomName,
    this.propertyId,
    this.propertyName,
    this.tenantName,
    this.dueDate,
    this.isOverdue = false,
    this.isDueSoon = false,
    this.daysOverdue = 0,
    this.daysUntilDue,
    this.issuedAt,
    this.cancelledAt,
    this.cancelledNote,
    this.note,
    this.payments = const [],
    this.paymentProofs = const [],
    this.lineItems = const [],
  });

  final String id;
  final String leaseId;
  final String roomId;
  final String tenantId;
  final DateTime? billingMonth;
  final int rentAmount;
  final int electricityAmount;
  final int waterAmount;
  final int otherAmount;
  final int totalAmount;
  final int paidAmount;
  final int remainingAmount;
  final InvoiceStatus status;
  final int revision;
  final String? replacesInvoiceId;
  final String? replacementInvoiceId;
  final List<Map<String, dynamic>> adjustments;
  final bool isDemo;
  final String? roomName;
  final String? propertyId;
  final String? propertyName;
  final String? tenantName;
  final DateTime? dueDate;
  final bool isOverdue;
  final bool isDueSoon;
  final int daysOverdue;
  final int? daysUntilDue;
  final DateTime? issuedAt;
  final DateTime? cancelledAt;
  final String? cancelledNote;
  final String? note;
  final List<Payment> payments;
  final List<InvoicePaymentProof> paymentProofs;
  final List<InvoiceLineItem> lineItems;

  bool get canPay => status != InvoiceStatus.cancelled && remainingAmount > 0;

  bool get canCancel => status != InvoiceStatus.cancelled && payments.isEmpty;

  bool get canReplace =>
      !isDemo &&
      status != InvoiceStatus.cancelled &&
      paidAmount == 0 &&
      payments.isEmpty &&
      replacementInvoiceId == null;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final data = _envelope(json);
    final payments =
        data['payments'] is List ? data['payments'] as List : const <Object?>[];
    return Invoice(
      id: data['id'] as String,
      leaseId: data['leaseId'] as String? ?? '',
      roomId: data['roomId'] as String? ?? '',
      tenantId: data['tenantId'] as String? ?? '',
      billingMonth: _date(data['billingMonth']),
      rentAmount: _int(data['rentAmount']),
      electricityAmount: _int(data['electricityAmount']),
      waterAmount: _int(data['waterAmount']),
      otherAmount: _int(data['otherAmount']),
      totalAmount: _int(data['totalAmount']),
      paidAmount: _int(data['paidAmount']),
      remainingAmount: _int(data['remainingAmount']),
      status: InvoiceStatus.fromWire(data['status']),
      revision: _int(data['revision']) == 0 ? 1 : _int(data['revision']),
      replacesInvoiceId: data['replacesInvoiceId'] as String?,
      replacementInvoiceId: data['replacementInvoiceId'] as String?,
      adjustments: (data['adjustments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      isDemo: data['isDemo'] == true,
      roomName: data['roomName'] as String?,
      propertyId: data['propertyId'] as String?,
      propertyName: data['propertyName'] as String?,
      tenantName: data['tenantName'] as String?,
      dueDate: _date(data['dueDate']),
      isOverdue: data['isOverdue'] == true,
      isDueSoon: data['isDueSoon'] == true,
      daysOverdue: _int(data['daysOverdue']),
      daysUntilDue: _intOrNull(data['daysUntilDue']),
      issuedAt: _date(data['issuedAt']),
      cancelledAt: _date(data['cancelledAt']),
      cancelledNote: data['cancelledNote'] as String?,
      note: data['note'] as String?,
      lineItems: (data['lineItems'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(InvoiceLineItem.fromJson)
          .toList(growable: false),
      payments: payments
          .whereType<Map<String, dynamic>>()
          .map(Payment.fromJson)
          .toList(growable: false),
      paymentProofs: (data['paymentProofs'] is List
              ? data['paymentProofs'] as List
              : const <Object?>[])
          .whereType<Map<String, dynamic>>()
          .map(InvoicePaymentProof.fromJson)
          .toList(growable: false),
    );
  }
}

Map<String, dynamic> _envelope(Map<String, dynamic> json) =>
    json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _intOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
