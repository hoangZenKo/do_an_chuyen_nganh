import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import 'billing_api.dart';

class BillingRepository {
  const BillingRepository(this._api);

  final BillingApi _api;

  Future<List<BillingLease>> activeLeases() => _api.activeLeases();

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
}
