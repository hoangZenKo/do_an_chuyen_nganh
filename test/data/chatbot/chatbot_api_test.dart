import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/chatbot/chatbot_api.dart';
import 'package:rental_room_management/models/chatbot.dart';

final _source = {
  'id': 'c1',
  'documentId': 'd1',
  'contentHash': 'hash',
  'title': 'Hóa đơn',
  'heading': 'Tạo hóa đơn'
};
Map<String, dynamic> _answer({String status = 'answered'}) => {
      'data': {
        'requestId': 'r1',
        'status': status,
        'answer': 'Mở Hóa đơn.',
        'sources': status == 'answered' ? [_source] : [],
      }
    };

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200, this.timeout = false});
  final Object body;
  final int status;
  final bool timeout;
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    if (timeout) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Dio client(_Adapter adapter) => Dio(BaseOptions(
      baseUrl: 'http://localhost/api/v1',
      receiveTimeout: const Duration(seconds: 15)))
    ..httpClientAdapter = adapter;

  test('parses the envelope and only chat uses a 70 second timeout', () async {
    final adapter = _Adapter(_answer());
    final dio = client(adapter);
    final result =
        await ChatbotApi(dio).ask('Cách tạo hóa đơn?', propertyId: 'p1');
    expect(result.status, ChatAnswerStatus.answered);
    expect(result.sources.single.title, 'Hóa đơn');
    expect(adapter.request.data,
        {'message': 'Cách tạo hóa đơn?', 'propertyId': 'p1'});
    expect(adapter.request.receiveTimeout, const Duration(seconds: 70));
    expect(dio.options.receiveTimeout, const Duration(seconds: 15));
  });
  test('parses insufficient evidence without sources', () async {
    final result = await ChatbotApi(
            client(_Adapter(_answer(status: 'insufficient_evidence'))))
        .ask('Nội quy?');
    expect(result.status, ChatAnswerStatus.insufficientEvidence);
    expect(result.sources, isEmpty);
  });
  for (final body in [
    {},
    {
      'data': {'status': 'wrong'}
    },
    {
      'data': {...(_answer()['data'] as Map), 'sources': []}
    },
    {
      'data': {
        ...(_answer()['data'] as Map),
        'sources': [_source, _source]
      }
    },
    {
      'data': {...(_answer()['data'] as Map), 'answer': 123}
    }
  ]) {
    test('rejects malformed payload $body', () async {
      await expectLater(
          ChatbotApi(client(_Adapter(body))).ask('Câu hỏi'),
          throwsA(isA<ApiFailure>()
              .having((error) => error.code, 'code', 'AI_INVALID_RESPONSE')));
    });
  }
  for (final entry
      in {429: 'AI_BUSY', 503: 'AI_UNAVAILABLE', 504: 'AI_TIMEOUT'}.entries) {
    test('maps HTTP ${entry.key} without automatic retries', () async {
      final adapter = _Adapter({
        'error': {'code': entry.value, 'message': 'Thử lại sau'}
      }, status: entry.key);
      await expectLater(
          ChatbotApi(client(adapter)).ask('Câu hỏi'),
          throwsA(isA<ApiFailure>()
              .having((error) => error.statusCode, 'status', entry.key)
              .having((error) => error.code, 'code', entry.value)));
    });
  }
  test('maps client deadline failures', () async {
    await expectLater(
        ChatbotApi(client(_Adapter({}, timeout: true))).ask('Câu hỏi'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'code', 'AI_TIMEOUT')));
  });
  test('fetches current source text with the property scope and normal timeout',
      () async {
    final adapter = _Adapter({
      'data': {..._source, 'text': 'Nguồn đã được kiểm tra quyền.'}
    });
    final result =
        await ChatbotApi(client(adapter)).source('c1', propertyId: 'p1');
    expect(result.text, contains('kiểm tra quyền'));
    expect(adapter.request.path, '/chatbot/sources/c1');
    expect(adapter.request.queryParameters, {'propertyId': 'p1'});
    expect(adapter.request.receiveTimeout, const Duration(seconds: 15));
  });
}
