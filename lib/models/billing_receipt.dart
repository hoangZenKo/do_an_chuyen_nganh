import 'billing.dart';

class BillingReceipt {
  const BillingReceipt({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.availableAmount,
    required this.refundedAmount,
    required this.method,
    required this.reference,
    required this.paidAt,
    this.allocations = const [],
    this.refunds = const [],
  });

  final String id;
  final String tenantId;
  final int amount;
  final int availableAmount;
  final int refundedAmount;
  final PaymentMethod method;
  final String reference;
  final DateTime paidAt;
  final List<BillingAllocation> allocations;
  final List<BillingReceiptRefund> refunds;

  factory BillingReceipt.fromJson(Map<String, dynamic> data) => BillingReceipt(
        id: data['id'] as String,
        tenantId: data['tenantId'] as String,
        amount: (data['amount'] as num).toInt(),
        availableAmount: (data['availableAmount'] as num).toInt(),
        refundedAmount: (data['refundedAmount'] as num?)?.toInt() ?? 0,
        method: PaymentMethod.fromWire(data['method']),
        reference: data['reference'] as String,
        paidAt: DateTime.parse(data['paidAt'] as String),
        allocations: (data['allocations'] as List? ?? const [])
            .map((row) => BillingAllocation.fromJson(
                Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
        refunds: (data['refunds'] as List? ?? const [])
            .map((row) => BillingReceiptRefund.fromJson(
                Map<String, dynamic>.from(row as Map)))
            .toList(growable: false),
      );
}

class BillingAllocation {
  const BillingAllocation(
      {required this.id,
      required this.invoiceId,
      required this.amount,
      this.releasedAt,
      this.releaseReason});

  final String id;
  final String invoiceId;
  final int amount;
  final DateTime? releasedAt;
  final String? releaseReason;

  factory BillingAllocation.fromJson(Map<String, dynamic> data) =>
      BillingAllocation(
        id: data['id'] as String,
        invoiceId: (data['payment'] as Map)['invoiceId'] as String,
        amount: (data['amount'] as num).toInt(),
        releasedAt: DateTime.tryParse(data['releasedAt']?.toString() ?? ''),
        releaseReason: data['releaseReason'] as String?,
      );
}

class BillingReceiptRefund {
  const BillingReceiptRefund(
      {required this.amount,
      required this.reason,
      required this.reference,
      required this.createdAt});

  final int amount;
  final String reason;
  final String reference;
  final DateTime createdAt;

  factory BillingReceiptRefund.fromJson(Map<String, dynamic> data) =>
      BillingReceiptRefund(
        amount: (data['amount'] as num).toInt(),
        reason: data['reason'] as String,
        reference: data['reference'] as String,
        createdAt: DateTime.parse(data['createdAt'] as String),
      );
}
