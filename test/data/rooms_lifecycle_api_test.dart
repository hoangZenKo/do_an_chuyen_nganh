import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/rooms/room_api.dart';

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

RoomApi _api(_RecordingAdapter adapter) {
  return RoomApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
  );
}

void main() {
  test('listByProperty serializes lifecycle query', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"r1","propertyId":"p1","name":"P.101",'
        '"status":"vacant","isActive":false}]}',
        200,
      ),
    );

    final rooms = await _api(adapter).listByProperty(
      'p1',
      lifecycle: 'inactive',
    );

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/properties/p1/rooms');
    expect(adapter.request.queryParameters, {'lifecycle': 'inactive'});
    expect(rooms.single.isActive, isFalse);
  });

  test('setActive patches room lifecycle status', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"r1","propertyId":"p1","name":"P.101",'
        '"status":"vacant","isActive":true}}',
        200,
      ),
    );

    final room = await _api(adapter).setActive('r1', true);

    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.path, '/rooms/r1/status');
    expect(adapter.request.data, isA<Map>());
    expect((adapter.request.data as Map)['isActive'], isTrue);
    expect(room.isActive, isTrue);
  });

  test('delete removes unused room', () async {
    final adapter = _RecordingAdapter(_json('', 204));

    await _api(adapter).delete('r1');

    expect(adapter.request.method, 'DELETE');
    expect(adapter.request.path, '/rooms/r1');
  });
}
