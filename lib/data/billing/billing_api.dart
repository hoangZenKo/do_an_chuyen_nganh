import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/billing.dart';
import '../../models/billing_tariff.dart';
import '../../models/reports.dart';
import '../../models/tenant_portal.dart';

class BillingApi {
  const BillingApi(this._dio);

  final Dio _dio;

  Future<List<BillingTariffVersion>> tariffs(String propertyId) async {
    final response = await _request(() => _dio.get(
          '/billing/tariffs',
          queryParameters: {'propertyId': propertyId},
        ));
    return _parseList(response.data)
        .map(BillingTariffVersion.fromJson)
        .toList(growable: false);
  }

  Future<BillingTariffVersion> proposeTariff(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/tariffs/proposals', data: payload),
    );
    return BillingTariffVersion.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<BillingTariffImpact> tariffImpact(String id) async {
    final response = await _request(
      () => _dio.get('/billing/tariffs/$id/impact'),
    );
    return BillingTariffImpact.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<BillingTariffVersion> reviewTariff(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/tariffs/$id/review', data: payload),
    );
    return BillingTariffVersion.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<BillingLease>> activeLeases({String? month}) async {
    final response = await _request(() => _dio.get(
          '/billing/active-leases',
          queryParameters: {if (month != null) 'month': month},
        ));
    return _parseList(response.data).map(BillingLease.fromJson).toList();
  }

  Future<List<Invoice>> invoices({
    InvoiceStatus? status,
    String? month,
    String? propertyId,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/billing/invoices',
        queryParameters: {
          if (status != null) 'status': status.name,
          if (month != null) 'month': month,
          if (propertyId != null) 'propertyId': propertyId,
        },
      ),
    );
    return _parseList(response.data).map(Invoice.fromJson).toList();
  }

  Future<Invoice> invoice(String invoiceId) async {
    final response = await _request(
      () => _dio.get('/billing/invoices/$invoiceId'),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MeterReading>> meterReadings({
    String? roomId,
    String? month,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/billing/meter-readings',
        queryParameters: {
          if (roomId != null) 'roomId': roomId,
          if (month != null) 'month': month,
        },
      ),
    );
    return _parseList(response.data).map(MeterReading.fromJson).toList();
  }

  Future<MeterReading> createMeterReading(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/billing/meter-readings', data: payload),
    );
    return MeterReading.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BulkInvoicePreflight> bulkInvoicePreflight(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/invoices/bulk/preflight', data: payload),
    );
    return BulkInvoicePreflight.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<BulkInvoiceGenerationResult> createBulkInvoices(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/invoices/bulk', data: payload),
    );
    return BulkInvoiceGenerationResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<BillingAutomation> billingAutomation(String propertyId) async {
    final response = await _request(
      () => _dio.get(
        '/billing/automation',
        queryParameters: {'propertyId': propertyId},
      ),
    );
    return BillingAutomation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BillingAutomation> updateBillingAutomation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.put('/billing/automation', data: payload),
    );
    return BillingAutomation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BillingAutomationPreview> billingAutomationPreview(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/automation/preview', data: payload),
    );
    return BillingAutomationPreview.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<BillingAutomationRunResult> runBillingAutomation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/automation/run', data: payload),
    );
    return BillingAutomationRunResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<ZaloReminderSendResult> runInvoiceReminders(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post(
        '/billing/reminders/run',
        queryParameters: payload,
      ),
    );
    return ZaloReminderSendResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<Invoice> createInvoice(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/billing/invoices', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Invoice> updateInvoice(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.patch('/billing/invoices/$invoiceId', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Invoice> recordPayment(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/invoices/$invoiceId/payments', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Invoice> cancelInvoice(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/invoices/$invoiceId/cancel', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Invoice> reversePayment(
    String invoiceId,
    String paymentId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post(
        '/billing/invoices/$invoiceId/payments/$paymentId/reverse',
        data: payload,
      ),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PaymentProof>> paymentProofs({String? status}) async {
    final response = await _request(
      () => _dio.get(
        '/billing/payment-proofs',
        queryParameters: {if (status != null) 'status': status},
      ),
    );
    return _parseList(response.data)
        .map(PaymentProof.fromJson)
        .toList(growable: false);
  }

  Future<PaymentProof> reviewPaymentProof(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.post('/billing/payment-proofs/$id/review', data: payload),
    );
    return PaymentProof.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> aging({
    String? propertyId,
    String? roomId,
    String? tenantId,
    String? groupBy,
  }) async {
    final response =
        await _request(() => _dio.get('/billing/aging', queryParameters: {
              if (propertyId != null) 'propertyId': propertyId,
              if (roomId != null) 'roomId': roomId,
              if (tenantId != null) 'tenantId': tenantId,
              if (groupBy != null) 'groupBy': groupBy,
            }));
    return _dataMap(response.data);
  }

  Future<Invoice> replaceInvoice(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () =>
          _dio.post('/billing/invoices/$invoiceId/replacement', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Invoice> adjustInvoice(
    String invoiceId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () =>
          _dio.post('/billing/invoices/$invoiceId/adjustments', data: payload),
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createReceipt(
      Map<String, dynamic> payload) async {
    final response =
        await _request(() => _dio.post('/billing/receipts', data: payload));
    return _dataMap(response.data);
  }

  Future<List<Map<String, dynamic>>> receipts({String? tenantId}) async {
    final response = await _request(() => _dio.get('/billing/receipts',
        queryParameters: {if (tenantId != null) 'tenantId': tenantId}));
    return _parseList(response.data);
  }

  Future<Map<String, dynamic>> releaseAllocation(String receiptId,
      String allocationId, Map<String, dynamic> payload) async {
    final response = await _request(() => _dio.post(
        '/billing/receipts/$receiptId/allocations/$allocationId/release',
        data: payload));
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> allocateReceipt(
    String receiptId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(() => _dio.post(
          '/billing/receipts/$receiptId/allocations',
          data: payload,
        ));
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> refundReceipt(
    String receiptId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(() => _dio.post(
          '/billing/receipts/$receiptId/refunds',
          data: payload,
        ));
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> reminderPolicy({String? propertyId}) async {
    final response = await _request(() => _dio.get(
          '/billing/reminder-policy',
          queryParameters: {if (propertyId != null) 'propertyId': propertyId},
        ));
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> updateReminderPolicy(
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      () => _dio.put('/billing/reminder-policy', data: payload),
    );
    return _dataMap(response.data);
  }

  Future<Map<String, dynamic>> previewInvoice(
      Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/billing/invoices/preview', data: payload),
    );
    return _dataMap(response.data);
  }

  List<Map<String, dynamic>> _parseList(Object? data) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Map<String, dynamic> _dataMap(Object? data) {
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    if (data is Map<String, dynamic>) return data;
    throw const ApiFailure(message: 'The server returned an invalid response.');
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    } on TypeError {
      throw const ApiFailure(
        message: 'The server returned an invalid response.',
      );
    }
  }
}
