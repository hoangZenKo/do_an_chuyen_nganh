import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/tenants/tenant_api.dart';

ResponseBody _json(String body, int statusCode) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final ResponseBody response;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

TenantApi _api(_RecordingAdapter adapter) {
  return TenantApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
  );
}

void main() {
  test('list serializes lifecycle query', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"t1","fullName":"Tenant",'
        '"isActive":false,"activeLease":null}]}',
        200,
      ),
    );

    final tenants = await _api(adapter).list(lifecycle: 'inactive');

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/tenants');
    expect(adapter.request.queryParameters, {'lifecycle': 'inactive'});
    expect(tenants.single.isActive, isFalse);
  });

  test('setActive patches tenant lifecycle status', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"t1","fullName":"Tenant",'
        '"isActive":true,"activeLease":null}}',
        200,
      ),
    );

    final tenant = await _api(adapter).setActive('t1', true);

    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/tenants/t1/status');
    expect(adapter.request.data, isA<Map>());
    expect((adapter.request.data as Map)['isActive'], isTrue);
    expect(tenant.isActive, isTrue);
  });

  test('delete removes unused tenant', () async {
    final adapter = _RecordingAdapter(_json('', 204));

    await _api(adapter).delete('t1');

    expect(adapter.request.method, 'DELETE');
    expect(adapter.request.path, '/tenants/t1');
  });
}
