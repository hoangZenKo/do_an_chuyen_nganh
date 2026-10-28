import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/reports.dart';

class ReportsApi {
  const ReportsApi(this._dio);

  final Dio _dio;

  Future<MonthlyReport> monthly({String? month, String? propertyId}) async {
    final response = await _request(
      () => _dio.get(
        '/reports/monthly',
        queryParameters: {
          if (month != null) 'month': month,
          if (propertyId != null) 'propertyId': propertyId,
        },
      ),
    );
    return MonthlyReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BillingReminder>> reminders({String? propertyId}) async {
    final response = await _request(
      () => _dio.get(
        '/billing/reminders',
        queryParameters: {if (propertyId != null) 'propertyId': propertyId},
      ),
    );
    final raw = response.data is Map<String, dynamic> &&
            (response.data as Map<String, dynamic>)['data'] is List
        ? (response.data as Map<String, dynamic>)['data'] as List
        : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BillingReminder.fromJson)
        .toList(growable: false);
  }

  Future<ZaloReminderSendResult> sendZaloInvoiceReminders({
    String? propertyId,
  }) async {
    final response = await _request(
      () => _dio.post(
        '/notifications/zalo/invoice-reminders',
        queryParameters: {if (propertyId != null) 'propertyId': propertyId},
      ),
    );
    return ZaloReminderSendResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<ReportExport> monthlyExport(
      {String? month, String? propertyId}) async {
    final response = await _request(
      () => _dio.get(
        '/reports/monthly/export',
        queryParameters: {
          if (month != null) 'month': month,
          if (propertyId != null) 'propertyId': propertyId,
        },
      ),
    );
    return ReportExport.fromJson(response.data as Map<String, dynamic>);
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
