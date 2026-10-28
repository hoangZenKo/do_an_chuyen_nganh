import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/models/billing_tariff.dart';

class _Adapter implements HttpClientAdapter {
  Object response = <String, dynamic>{'data': <String, dynamic>{}};
  int status = 200;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(response), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _tariff({String state = 'PROPOSED'}) => {
      'id': 'tariff',
      'propertyId': 'property',
      'roomId': 'room',
      'serviceKey': 'electricity',
      'name': 'Điện',
      'kind': 'ELECTRICITY',
      'unit': 'kWh',
      'amount': 3000,
      'isActive': true,
      'version': 2,
      'state': state,
      'effectiveFrom': '2026-11-01T00:00:00.000Z',
      'tiers': [
        {'upTo': 50, 'unitPrice': 2000},
        {'upTo': null, 'unitPrice': 3000},
      ],
      'reason': 'New provider rate',
      'reviewReason': state == 'REJECTED' ? 'Incorrect rate' : null,
    };

void main() {
  late _Adapter adapter;
  late BillingApi api;
  late BillingRepository repository;

  setUp(() {
    adapter = _Adapter();
    api = BillingApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter);
    repository = BillingRepository(api);
  });

  test('parses property versions without losing scope, tiers or review reason',
      () async {
    adapter.response = {
      'data': [_tariff(state: 'REJECTED')]
    };
    final rows = await repository.tariffs('property');
    expect(adapter.requests.single.path, '/billing/tariffs');
    expect(adapter.requests.single.queryParameters, {'propertyId': 'property'});
    expect(rows.single.roomId, 'room');
    expect(rows.single.isRejected, isTrue);
    expect(rows.single.reviewReason, 'Incorrect rate');
    expect(rows.single.tiers.last.upTo, isNull);
    expect(rows.single.tiers.first.toJson(), {'upTo': 50, 'unitPrice': 2000});
  });

  test('posts a complete proposal through existing command API', () async {
    adapter.response = {'data': _tariff()};
    final result = await repository.proposeTariff(
      requestKey: 'key',
      propertyId: 'property',
      roomId: 'room',
      kind: 'ELECTRICITY',
      serviceKey: ' electricity ',
      name: ' Điện ',
      unit: ' kWh ',
      amount: 3000,
      isActive: true,
      effectiveFrom: '2026-11-01T00:00:00.000Z',
      tiers: const [
        {'upTo': null, 'unitPrice': 3000}
      ],
      reason: ' New rate ',
    );
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/billing/tariffs/proposals');
    expect(request.data, {
      'requestKey': 'key',
      'propertyId': 'property',
      'roomId': 'room',
      'kind': 'ELECTRICITY',
      'serviceKey': 'electricity',
      'name': 'Điện',
      'unit': 'kWh',
      'amount': 3000,
      'isActive': true,
      'effectiveFrom': '2026-11-01T00:00:00.000Z',
      'tiers': [
        {'upTo': null, 'unitPrice': 3000}
      ],
      'reason': 'New rate',
    });
    expect(result.isProposed, isTrue);
  });

  test(
      'impact preserves prior version, override exclusions and blocking reasons',
      () async {
    adapter.response = {
      'data': {
        'proposed': _tariff(),
        'previous': _tariff(state: 'APPROVED'),
        'rooms': [
          {'id': 'room', 'name': 'A101'}
        ],
        'overriddenRooms': [
          {'id': 'override', 'name': 'A102'}
        ],
        'issuedInvoices': 1,
        'lockedPeriods': 2,
        'canApprove': false,
        'blockingReasons': ['ISSUED_INVOICES', 'LOCKED_PERIODS'],
      }
    };
    final result = await repository.tariffImpact('tariff');
    expect(adapter.requests.single.path, '/billing/tariffs/tariff/impact');
    expect(result.previous!.isApproved, isTrue);
    expect(result.rooms.single.name, 'A101');
    expect(result.overriddenRooms.single.id, 'override');
    expect(result.blockingReasons, ['ISSUED_INVOICES', 'LOCKED_PERIODS']);
    expect(result.canApprove, isFalse);
  });

  test('reviews with a stable caller-supplied command key and audit reason',
      () async {
    adapter.response = {'data': _tariff(state: 'APPROVED')};
    final result = await repository.reviewTariff(
      id: 'tariff',
      requestKey: 'review-key',
      decision: 'APPROVED',
      reason: ' Checked ',
    );
    expect(adapter.requests.single.path, '/billing/tariffs/tariff/review');
    expect(adapter.requests.single.data, {
      'requestKey': 'review-key',
      'decision': 'APPROVED',
      'reason': 'Checked',
    });
    expect(result.isApproved, isTrue);
  });

  test('conflicts and permission failures are surfaced without replay',
      () async {
    for (final status in [403, 409, 500]) {
      adapter.status = status;
      adapter.response = {
        'error': {'code': 'TARIFF_ALREADY_REVIEWED', 'message': 'Changed'}
      };
      await expectLater(
          repository.reviewTariff(
            id: 'tariff',
            requestKey: 'key',
            decision: 'APPROVED',
            reason: 'Checked',
          ),
          throwsA(isA<ApiFailure>()
              .having((error) => error.statusCode, 'status', status)));
    }
    expect(adapter.requests, hasLength(3));
  });

  test('old impact payloads remain readable without new metadata', () {
    final impact = BillingTariffImpact.fromJson({
      'proposed': _tariff(),
      'rooms': [],
      'canApprove': true,
    });
    expect(impact.overriddenRooms, isEmpty);
    expect(impact.blockingReasons, isEmpty);
    expect(impact.previous, isNull);
  });
}
