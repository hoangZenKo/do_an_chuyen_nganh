import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/data/uploads/upload_api.dart';

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

void main() {
  test('uploadFile posts multipart file and parses returned url', () async {
    final tempDir = await Directory.systemTemp.createTemp('upload_api_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}/receipt.png');
    await file.writeAsBytes([1, 2, 3, 4]);

    final adapter = _RecordingAdapter(
      _json('{"data":{"url":"/uploads/receipt.png"}}', 201),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;

    final url = await UploadApi(dio).uploadFile(file.path);

    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/uploads');
    expect(adapter.request.data, isA<FormData>());
    final form = adapter.request.data as FormData;
    expect(form.files, hasLength(1));
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'receipt.png');
    expect(Map.fromEntries(form.fields), containsPair('purpose', 'PRIVATE'));
    expect(url, '/uploads/receipt.png');
  });

  test('private attachment asks for a short-lived signed URL on the API host',
      () async {
    final adapter = _RecordingAdapter(_json(
        '{"data":{"url":"/uploads/receipt.png?access=signed","expiresInSeconds":300}}',
        200));
    final api = UploadApi(
        Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
          ..httpClientAdapter = adapter);
    expect(await api.accessUrl('https://old-api.test/uploads/receipt.png'),
        'http://localhost:3000/uploads/receipt.png?access=signed');
    expect(adapter.request.path, '/uploads/receipt.png/access');
    expect(adapter.request.method, 'GET');
    expect(await api.accessUrl('https://example.test/photo.png'),
        'https://example.test/photo.png');
  });
}
