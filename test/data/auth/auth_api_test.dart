import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/data/auth/auth_api.dart';

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

void main() {
  test('me requests auth/me and parses the data envelope', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        '{"data":{"id":"u1","fullName":"Test User","email":"test@example.com","phone":null,"role":"landlord"}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;

    final user = await AuthApi(dio).me();

    expect(adapter.request.path, '/auth/me');
    expect(user.id, 'u1');
    expect(user.role, 'landlord');
  });
}
