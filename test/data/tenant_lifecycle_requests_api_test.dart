import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/tenants/tenant_lifecycle_api.dart';

class _Adapter implements HttpClientAdapter {
  Object? body = {'data': <dynamic>[]};
  int status = 200;
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

void main() {
  late _Adapter adapter;
  late TenantLifecycleApi api;
  setUp(() {
    adapter = _Adapter();
    api = TenantLifecycleApi(
        Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
          ..httpClientAdapter = adapter,
        ownerId: 'tenant-owner');
  });
  test('paginates and filters the tenant history using the bound identity',
      () async {
    adapter.body = {
      'data': [
        {'id': 'request'}
      ],
      'nextCursor': 'next'
    };
    final page = await api.requests(
        tenant: true, leaseId: 'lease', status: 'PENDING', cursor: 'previous');
    expect(page.nextCursor, 'next');
    expect(adapter.requests.single.path, '/tenant/lifecycle-requests');
    expect(adapter.requests.single.queryParameters, {
      'leaseId': 'lease',
      'limit': 25,
      'status': 'PENDING',
      'cursor': 'previous'
    });
    expect(adapter.requests.single.extra['expectedUserId'], 'tenant-owner');
  });
  test('review and cancellation preserve optimistic concurrency tokens',
      () async {
    final request = {
      'id': 'request',
      'updatedAt': '2026-10-27T00:00:00.000Z',
      'lease': {'updatedAt': '2026-10-26T00:00:00.000Z'}
    };
    await api.review(request, 'REJECTED', 'Needs clarification');
    expect(adapter.requests.last.data, {
      'status': 'REJECTED',
      'reason': 'Needs clarification',
      'expectedUpdatedAt': request['updatedAt'],
      'expectedLeaseUpdatedAt': '2026-10-26T00:00:00.000Z'
    });
    await api.cancel(request);
    expect(adapter.requests.last.data,
        {'expectedUpdatedAt': request['updatedAt']});
  });
  test('execution reuses its key and never sends a synthetic deposit',
      () async {
    await api.execute({'id': 'request', 'updatedAt': 'version'}, 'request-key',
        monthlyRent: 4000000);
    expect(adapter.requests.single.path,
        '/tenant-lifecycle/requests/request/execute');
    expect(adapter.requests.single.data, {
      'requestKey': 'request-key',
      'expectedUpdatedAt': 'version',
      'monthlyRent': 4000000
    });
  });
  test(
      'empty settlement remains absent and malformed lists are not accepted as empty',
      () async {
    adapter.body = {'data': null};
    expect(await api.settlement('lease'), isNull);
    await expectLater(api.requests(tenant: true, leaseId: 'lease'),
        throwsA(isA<ApiFailure>()));
  });
  test('server conflict is surfaced without replaying the mutation', () async {
    adapter.status = 409;
    adapter.body = {
      'error': {'message': 'Changed'}
    };
    await expectLater(
        api.create({'leaseId': 'lease'}),
        throwsA(isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'status', 409)));
    expect(adapter.requests, hasLength(1));
  });
  test('no request is sent without an owner identity', () async {
    final api =
        TenantLifecycleApi(Dio()..httpClientAdapter = adapter, ownerId: null);
    await expectLater(
        api.occupants('lease', tenant: true), throwsA(isA<ApiFailure>()));
    expect(adapter.requests, isEmpty);
  });
}
