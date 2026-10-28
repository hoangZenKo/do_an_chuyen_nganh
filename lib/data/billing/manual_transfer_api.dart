import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../features/auth/auth_providers.dart';

class TransferAccount {
  const TransferAccount(
      {this.version = 0,
      this.enabled = false,
      this.bankName = '',
      this.accountName = '',
      this.accountNumber = '',
      this.qrImagePath});

  final int version;
  final bool enabled;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? qrImagePath;

  factory TransferAccount.fromJson(Map<String, dynamic> data) =>
      TransferAccount(
          version: data['version'] as int,
          enabled: data['enabled'] == true,
          bankName: data['bankName'] as String? ?? '',
          accountName: data['accountName'] as String? ?? '',
          accountNumber: data['accountNumber'] as String? ?? '',
          qrImagePath: data['qrImagePath'] as String?);

  Map<String, dynamic> toJson() => {
        'version': version,
        'enabled': enabled,
        'bankName': bankName.trim(),
        'accountName': accountName.trim(),
        'accountNumber': accountNumber.trim(),
        'qrImagePath': qrImagePath
      };
}

class TransferInstructions {
  const TransferInstructions(
      {required this.reference,
      required this.remainingAmount,
      required this.pendingAmount,
      required this.availableAmount,
      required this.canSubmit,
      this.account});

  final String reference;
  final int remainingAmount;
  final int pendingAmount;
  final int availableAmount;
  final bool canSubmit;
  final TransferAccount? account;

  factory TransferInstructions.fromJson(Map<String, dynamic> data) =>
      TransferInstructions(
          reference: data['reference'] as String,
          remainingAmount: data['remainingAmount'] as int,
          pendingAmount: data['pendingAmount'] as int,
          availableAmount: data['availableAmount'] as int,
          canSubmit: data['canSubmit'] == true,
          account: data['account'] is Map
              ? TransferAccount.fromJson({
                  ...Map<String, dynamic>.from(data['account'] as Map),
                  'enabled': true
                })
              : null);
}

class ManualTransferApi {
  const ManualTransferApi(this._dio);
  final Dio _dio;

  Future<T> _request<T>(Future<Response<dynamic>> Function() operation,
      T Function(Map<String, dynamic>) decode) async {
    try {
      final response = await operation();
      return decode(
          Map<String, dynamic>.from((response.data as Map)['data'] as Map));
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: error.response?.data);
    } on TypeError {
      throw const ApiFailure(message: 'Thông tin chuyển khoản không hợp lệ.');
    }
  }

  Future<TransferAccount> account(String propertyId) => _request(
      () => _dio.get('/properties/$propertyId/transfer-account'),
      TransferAccount.fromJson);
  Future<TransferAccount> save(String propertyId, TransferAccount account) =>
      _request(
          () => _dio.put('/properties/$propertyId/transfer-account',
              data: account.toJson()),
          TransferAccount.fromJson);
  Future<TransferInstructions> instructions(String invoiceId) => _request(
      () => _dio.get('/tenant/invoices/$invoiceId/transfer-instructions'),
      TransferInstructions.fromJson);
}

final manualTransferApiProvider = Provider<ManualTransferApi>((ref) {
  ref.watch(sessionIdentityProvider);
  return ManualTransferApi(ref.watch(sessionDioProvider).client);
});

final transferInstructionsProvider =
    FutureProvider.autoDispose.family<TransferInstructions, String>((ref, id) {
  ref.watch(sessionIdentityProvider);
  return ref.watch(manualTransferApiProvider).instructions(id);
});
