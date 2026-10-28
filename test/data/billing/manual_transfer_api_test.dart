import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/manual_transfer_api.dart';

class Adapter implements HttpClientAdapter {
  Object? response;
  int status = 200;
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(response), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Adapter adapter;
  late ManualTransferApi api;
  setUp(() {
    adapter = Adapter();
    api = ManualTransferApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter);
  });
  test(
      'fetches a per-property account and preserves the account number as text',
      () async {
    adapter.response = {
      'data': {
        'version': 2,
        'enabled': true,
        'bankName': 'Bank',
        'accountName': 'OWNER',
        'accountNumber': '00123456'
      }
    };
    final account = await api.account('property');
    expect(adapter.request.path, '/properties/property/transfer-account');
    expect(account.accountNumber, '00123456');
    expect(account.version, 2);
  });
  test('sends full versioned settings and an explicit null when removing QR',
      () async {
    adapter.response = {
      'data': {'version': 3, 'enabled': false}
    };
    await api.save(
        'property',
        const TransferAccount(
            version: 2,
            bankName: ' Bank ',
            accountName: ' OWNER ',
            accountNumber: '00123456'));
    expect(adapter.request.method, 'PUT');
    expect(adapter.request.data, {
      'version': 2,
      'enabled': false,
      'bankName': 'Bank',
      'accountName': 'OWNER',
      'accountNumber': '00123456',
      'qrImagePath': null
    });
  });
  test('parses pending balance without treating it as payment confirmation',
      () async {
    adapter.response = {
      'data': {
        'reference': 'HD invoice',
        'remainingAmount': 10000,
        'pendingAmount': 10000,
        'availableAmount': 0,
        'canSubmit': false,
        'account': null
      }
    };
    final instructions = await api.instructions('invoice');
    expect(
        adapter.request.path, '/tenant/invoices/invoice/transfer-instructions');
    expect(instructions.remainingAmount, 10000);
    expect(instructions.pendingAmount, 10000);
    expect(instructions.canSubmit, isFalse);
  });
  test('preserves stale-write conflicts rather than retrying automatically',
      () async {
    adapter.status = 409;
    adapter.response = {
      'error': {'message': 'Recipient changed. Reload.'}
    };
    await expectLater(
        api.save('property', const TransferAccount()),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 409)));
  });
  test('rejects malformed successful instructions', () async {
    adapter.response = {
      'data': {'canSubmit': true, 'remainingAmount': 'not-money'}
    };
    await expectLater(api.instructions('invoice'), throwsA(isA<ApiFailure>()));
  });
}
