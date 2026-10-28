import '../../models/billing.dart';
import '../../models/billing_receipt.dart';
import '../../models/billing_tariff.dart';
import '../../models/reports.dart';
import '../../models/tenant_portal.dart';
import 'billing_api.dart';

class BillingRepository {
  const BillingRepository(this._api);

  final BillingApi _api;

  Future<List<BillingTariffVersion>> tariffs(String propertyId) =>
      _api.tariffs(propertyId);

  Future<BillingTariffVersion> proposeTariff({
    required String requestKey,
    required String propertyId,
    String? roomId,
    required String kind,
    required String serviceKey,
    required String name,
    required String unit,
    required int amount,
    required bool isActive,
    required String effectiveFrom,
    required List<Map<String, dynamic>> tiers,
    required String reason,
  }) =>
      _api.proposeTariff({
        'requestKey': requestKey,
        'propertyId': propertyId,
        if (roomId != null) 'roomId': roomId,
        'kind': kind,
        'serviceKey': serviceKey.trim(),
        'name': name.trim(),
        'unit': unit.trim(),
        'amount': amount,
        'isActive': isActive,
        'effectiveFrom': effectiveFrom,
        'tiers': tiers,
        'reason': reason.trim(),
      });

  Future<BillingTariffImpact> tariffImpact(String id) => _api.tariffImpact(id);

  Future<BillingTariffVersion> reviewTariff({
    required String id,
    required String requestKey,
    required String decision,
    required String reason,
  }) =>
      _api.reviewTariff(id, {
        'requestKey': requestKey,
        'decision': decision,
        'reason': reason.trim(),
      });

  Future<List<BillingLease>> activeLeases({String? month}) =>
      _api.activeLeases(month: month);

  Future<List<Invoice>> invoices({
    InvoiceStatus? status,
    String? month,
    String? propertyId,
  }) =>
      _api.invoices(status: status, month: month, propertyId: propertyId);

  Future<Invoice> invoice(String invoiceId) => _api.invoice(invoiceId);

  Future<List<MeterReading>> meterReadings({
    String? roomId,
    String? month,
  }) =>
      _api.meterReadings(roomId: roomId, month: month);

  Future<MeterReading> createMeterReading({
    required String roomId,
    required UtilityType utilityType,
    required String billingMonth,
    required int previousReading,
    required int currentReading,
    required int unitPrice,
  }) {
    return _api.createMeterReading({
      'roomId': roomId,
      'utilityType': utilityType.name,
      'billingMonth': billingMonth,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'unitPrice': unitPrice,
    });
  }

  Future<BulkInvoicePreflight> bulkInvoicePreflight({
    required String propertyId,
    required String billingMonth,
  }) {
    return _api.bulkInvoicePreflight({
      'propertyId': propertyId,
      'billingMonth': billingMonth,
    });
  }

  Future<BulkInvoiceGenerationResult> createBulkInvoices({
    required String propertyId,
    required String billingMonth,
    String? dueDate,
    List<BulkInvoiceReadingDraft> readings = const [],
  }) {
    return _api.createBulkInvoices({
      'propertyId': propertyId,
      'billingMonth': billingMonth,
      if (dueDate != null && dueDate.trim().isNotEmpty) 'dueDate': dueDate,
      if (readings.isNotEmpty)
        'readings': readings.map((reading) => reading.toJson()).toList(),
    });
  }

  Future<BillingAutomation> billingAutomation(String propertyId) {
    return _api.billingAutomation(propertyId);
  }

  Future<BillingAutomation> updateBillingAutomation({
    required String propertyId,
    required bool isEnabled,
    required int invoiceDay,
    required int dueDay,
  }) {
    return _api.updateBillingAutomation({
      'propertyId': propertyId,
      'isEnabled': isEnabled,
      'invoiceDay': invoiceDay,
      'dueDay': dueDay,
    });
  }

  Future<BillingAutomationPreview> billingAutomationPreview({
    required String propertyId,
    String? billingMonth,
  }) {
    return _api.billingAutomationPreview({
      'propertyId': propertyId,
      if (billingMonth != null && billingMonth.trim().isNotEmpty)
        'billingMonth': billingMonth.trim(),
    });
  }

  Future<BillingAutomationRunResult> runBillingAutomation({
    required String propertyId,
    String? billingMonth,
    List<BulkInvoiceReadingDraft> readings = const [],
  }) {
    return _api.runBillingAutomation({
      'propertyId': propertyId,
      if (billingMonth != null && billingMonth.trim().isNotEmpty)
        'billingMonth': billingMonth.trim(),
      if (readings.isNotEmpty)
        'readings': readings.map((reading) => reading.toJson()).toList(),
    });
  }

  Future<ZaloReminderSendResult> runInvoiceReminders({
    String? propertyId,
    String? dueSoonDays,
  }) {
    return _api.runInvoiceReminders({
      if (propertyId != null && propertyId.trim().isNotEmpty)
        'propertyId': propertyId.trim(),
      if (dueSoonDays != null && dueSoonDays.trim().isNotEmpty)
        'dueSoonDays': dueSoonDays.trim(),
    });
  }

  Future<Invoice> createInvoice({
    required String leaseId,
    required String billingMonth,
    String? dueDate,
    int otherAmount = 0,
    String? note,
    List<BillingMeterReadingDraft> meterReadings = const [],
  }) {
    return _api.createInvoice({
      'leaseId': leaseId,
      'billingMonth': billingMonth,
      if (dueDate != null && dueDate.trim().isNotEmpty) 'dueDate': dueDate,
      'otherAmount': otherAmount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (meterReadings.isNotEmpty)
        'meterReadings':
            meterReadings.map((reading) => reading.toJson()).toList(),
    });
  }

  Future<Invoice> updateInvoice({
    required String invoiceId,
    String? dueDate,
    String? note,
  }) {
    return _api.updateInvoice(invoiceId, {
      if (dueDate != null) 'dueDate': dueDate,
      if (note != null) 'note': note,
    });
  }

  Future<Invoice> recordPayment({
    required String invoiceId,
    required int amount,
    PaymentMethod method = PaymentMethod.cash,
    String? paidAt,
    String? note,
  }) {
    return _api.recordPayment(invoiceId, {
      'amount': amount,
      'method': method.wire,
      if (paidAt != null && paidAt.trim().isNotEmpty) 'paidAt': paidAt.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<Invoice> cancelInvoice({
    required String invoiceId,
    required String note,
  }) {
    return _api.cancelInvoice(invoiceId, {'note': note.trim()});
  }

  Future<Invoice> reversePayment({
    required String invoiceId,
    required String paymentId,
    required String note,
  }) {
    return _api.reversePayment(invoiceId, paymentId, {'note': note.trim()});
  }

  Future<List<PaymentProof>> paymentProofs({String? status}) =>
      _api.paymentProofs(status: status);

  Future<PaymentProof> reviewPaymentProof({
    required String proofId,
    required String status,
    String? note,
  }) {
    return _api.reviewPaymentProof(proofId, {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<Map<String, dynamic>> aging({
    String? propertyId,
    String? roomId,
    String? tenantId,
    String? groupBy,
  }) =>
      _api.aging(
        propertyId: propertyId,
        roomId: roomId,
        tenantId: tenantId,
        groupBy: groupBy,
      );

  Future<Invoice> replaceInvoice({
    required String invoiceId,
    required String requestKey,
    required String reason,
    required List<Map<String, dynamic>> lines,
    String? dueDate,
  }) =>
      _api.replaceInvoice(invoiceId, {
        'requestKey': requestKey,
        'reason': reason.trim(),
        'lines': lines,
        if (dueDate != null && dueDate.trim().isNotEmpty) 'dueDate': dueDate,
      });

  Future<Invoice> adjustInvoice({
    required String invoiceId,
    required String requestKey,
    required String kind,
    required String category,
    required String reason,
    int? amount,
    int? basisPoints,
  }) =>
      _api.adjustInvoice(invoiceId, {
        'requestKey': requestKey,
        'kind': kind,
        'category': category,
        'reason': reason.trim(),
        if (amount != null) 'amount': amount,
        if (basisPoints != null) 'basisPoints': basisPoints,
      });

  Future<Map<String, dynamic>> createReceipt({
    required String requestKey,
    required String tenantId,
    required int amount,
    required String reference,
    required List<Map<String, dynamic>> allocations,
    PaymentMethod method = PaymentMethod.bankTransfer,
    String? paidAt,
  }) =>
      _api.createReceipt({
        'requestKey': requestKey,
        'tenantId': tenantId,
        'amount': amount,
        'method': method.wire,
        'reference': reference.trim(),
        'allocations': allocations,
        if (paidAt != null && paidAt.trim().isNotEmpty) 'paidAt': paidAt,
      });

  Future<List<BillingReceipt>> receipts({String? tenantId}) async =>
      (await _api.receipts(tenantId: tenantId))
          .map(BillingReceipt.fromJson)
          .toList(growable: false);

  Future<Map<String, dynamic>> releaseAllocation(
          {required String receiptId,
          required String allocationId,
          required String requestKey,
          required String reason}) =>
      _api.releaseAllocation(receiptId, allocationId,
          {'requestKey': requestKey, 'reason': reason.trim()});

  Future<Map<String, dynamic>> allocateReceipt({
    required String receiptId,
    required String requestKey,
    required List<Map<String, dynamic>> allocations,
  }) =>
      _api.allocateReceipt(receiptId, {
        'requestKey': requestKey,
        'allocations': allocations,
      });

  Future<Map<String, dynamic>> refundReceipt({
    required String receiptId,
    required String requestKey,
    required int amount,
    required String reference,
    required String reason,
  }) =>
      _api.refundReceipt(receiptId, {
        'requestKey': requestKey,
        'amount': amount,
        'reference': reference.trim(),
        'reason': reason.trim(),
      });

  Future<Map<String, dynamic>> reminderPolicy({String? propertyId}) =>
      _api.reminderPolicy(propertyId: propertyId);

  Future<Map<String, dynamic>> updateReminderPolicy({
    required String requestKey,
    required int expectedVersion,
    String? propertyId,
    required bool enabled,
    required List<int> beforeDays,
    required bool onDueDate,
    required List<int> overdueDays,
    required List<String> channels,
  }) =>
      _api.updateReminderPolicy({
        'requestKey': requestKey,
        'expectedVersion': expectedVersion,
        if (propertyId != null) 'propertyId': propertyId,
        'enabled': enabled,
        'beforeDays': beforeDays,
        'onDueDate': onDueDate,
        'overdueDays': overdueDays,
        'channels': channels,
      });
}
