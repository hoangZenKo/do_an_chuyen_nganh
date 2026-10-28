import 'package:dio/dio.dart';
import '../../core/network/api_failure.dart';

class LeaseSettlementApi {
  const LeaseSettlementApi(this.dio, {required this.ownerId});
  final Dio dio;
  final String? ownerId;

  Future<Map<String, dynamic>?> get(String leaseId) => _request(leaseId);
  Future<Map<String, dynamic>> preview(
          String leaseId, Map<String, dynamic> input) async =>
      (await _request(leaseId, action: 'preview', input: input))!;
  Future<Map<String, dynamic>> confirm(
          String leaseId, Map<String, dynamic> input) async =>
      (await _request(leaseId, action: 'confirm', input: input))!;
  Future<Map<String, dynamic>> refund(
          String leaseId, Map<String, dynamic> input) async =>
      (await _request(leaseId, action: 'refund', input: input))!;

  Future<Map<String, dynamic>?> _request(String leaseId,
      {String? action, Map<String, dynamic>? input}) async {
    if (ownerId == null || ownerId!.trim().isEmpty) {
      throw const ApiFailure(message: 'Phiên đăng nhập đã hết hạn.');
    }
    try {
      final response = await dio.request(
          '/leases/$leaseId/settlement${action == null ? '' : '/$action'}',
          data: input,
          options: Options(
              method: action == null ? 'GET' : 'POST',
              extra: {'expectedUserId': ownerId}));
      final body = response.data;
      if (body is! Map ||
          !body.containsKey('data') ||
          (body['data'] == null && action != null)) {
        throw const ApiFailure(message: 'Phản hồi quyết toán không hợp lệ.');
      }
      if (body['data'] == null) return null;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      if (!_valid(data, preview: action == 'preview')) {
        throw const ApiFailure(message: 'Phản hồi quyết toán không hợp lệ.');
      }
      return data;
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: error.response?.data);
    } on TypeError {
      throw const ApiFailure(message: 'Phản hồi quyết toán không hợp lệ.');
    }
  }

  bool _valid(Map<String, dynamic> data, {required bool preview}) {
    for (final key in [
      'rentAmount',
      'electricityAmount',
      'waterAmount',
      'otherCharges',
      'totalCharges',
      'depositBalance',
      'depositApplied',
      'refundAmount',
      'balanceDue',
      'outstandingInvoiceAmount',
    ]) {
      final amount = data[key];
      if (amount is! int || amount < 0 || amount > 2147483647) return false;
    }
    final lines = data['lines'];
    if (lines is! List ||
        lines.any((line) =>
            line is! Map ||
            line['description'] is! String ||
            line['amount'] is! int ||
            (line['amount'] as int) < 0)) {
      return false;
    }
    if (preview) {
      final fingerprint = data['previewFingerprint'];
      return fingerprint is String &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint);
    }
    return data['id'] is String &&
        (data['id'] as String).isNotEmpty &&
        data['version'] is int &&
        (data['version'] as int) > 0 &&
        ['NOT_DUE', 'PENDING', 'PAID'].contains(data['refundStatus']) &&
        data['snapshot'] is Map;
  }
}
