import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/tenants/lease_settlement_api.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Object? body;
  final int status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _data() => {
      'id': 'settlement',
      'version': 1,
      'refundStatus': 'PENDING',
      'snapshot': {},
      'previewFingerprint': List.filled(64, 'a').join(),
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
        'outstandingInvoiceAmount'
      ])
        key: 0,
      'lines': [
        {'description': 'Rent', 'amount': 0}
      ],
    };

LeaseSettlementApi _api(_Adapter adapter, {String? owner = 'owner'}) =>
    LeaseSettlementApi(
        Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
          ..httpClientAdapter = adapter,
        ownerId: owner);

void main() {
  test('loads an absent settlement without inventing a record', () async {
    final adapter = _Adapter({'data': null});
    expect(await _api(adapter).get('lease'), isNull);
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/leases/lease/settlement');
    expect(adapter.requests.single.extra['expectedUserId'], 'owner');
  });

  test('loads an existing settlement', () async {
    expect(await _api(_Adapter({'data': _data()})).get('lease'), _data());
  });

  for (final action in ['preview', 'confirm', 'refund']) {
    test('$action binds the owner and preserves the request exactly', () async {
      final adapter = _Adapter({'data': _data()});
      final api = _api(adapter);
      final payload = {'idempotencyKey': 'stable-key', 'version': 1};
      final response = switch (action) {
        'preview' => await api.preview('lease', payload),
        'confirm' => await api.confirm('lease', payload),
        _ => await api.refund('lease', payload),
      };
      expect(response, _data());
      expect(adapter.requests.single.path, '/leases/lease/settlement/$action');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, payload);
      expect(adapter.requests.single.extra['expectedUserId'], 'owner');
    });
  }

  test('does not send anything without a session identity', () async {
    for (final owner in [null, '']) {
      final adapter = _Adapter({'data': _data()});
      await expectLater(
          _api(adapter, owner: owner).get('lease'), throwsA(isA<ApiFailure>()));
      expect(adapter.requests, isEmpty);
    }
  });

  test('preserves conflict status and message so the UI clears stale previews',
      () async {
    final adapter = _Adapter({
      'error': {'code': 'CONFLICT', 'message': 'Preview is stale'}
    }, status: 409);
    await expectLater(
        _api(adapter).confirm('lease', {}),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.message, 'message', 'Preview is stale')));
  });

  test('rejects null mutation data and malformed successful responses',
      () async {
    for (final body in [
      null,
      {},
      {'data': null},
      {'data': []},
      {'data': {}},
      {
        'data': {..._data(), 'refundAmount': 'not a number'}
      },
      {
        'data': {
          ..._data(),
          'lines': [
            {'amount': 'bad'}
          ]
        }
      }
    ]) {
      await expectLater(_api(_Adapter(body)).confirm('lease', {}),
          throwsA(isA<ApiFailure>()));
    }
  });

  test('rejects a preview without a valid fingerprint', () async {
    final adapter = _Adapter({
      'data': {..._data(), 'previewFingerprint': 'bad'}
    });
    await expectLater(
        _api(adapter).preview('lease', {}), throwsA(isA<ApiFailure>()));
  });
}
