import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/chatbot.dart';

class ChatbotApi {
  const ChatbotApi(this._dio);
  final Dio _dio;

  Future<ChatAnswer> ask(String message,
      {String? propertyId, CancelToken? cancelToken}) {
    return _request(
        () => _dio.post('/chatbot/ask',
            data: {
              'message': message,
              if (propertyId != null) 'propertyId': propertyId
            },
            options: Options(receiveTimeout: const Duration(seconds: 70)),
            cancelToken: cancelToken),
        ChatAnswer.fromJson);
  }

  Future<ChatSourceDetail> source(String id,
      {String? propertyId, CancelToken? cancelToken}) {
    return _request(
        () => _dio.get('/chatbot/sources/${Uri.encodeComponent(id)}',
            queryParameters: {if (propertyId != null) 'propertyId': propertyId},
            cancelToken: cancelToken),
        ChatSourceDetail.fromJson);
  }

  Future<T> _request<T>(Future<Response<dynamic>> Function() request,
      T Function(Object?) parse) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException('Missing chatbot data');
      }
      return parse(body['data']);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      if ([
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.connectionTimeout
      ].contains(error.type)) {
        throw const ApiFailure(
            code: 'AI_TIMEOUT',
            message: 'Trợ lý phản hồi quá lâu. Bạn có thể thử lại.');
      }
      final failure = ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: error.response?.data);
      throw ApiFailure(
          code: failure.code ?? 'AI_UNAVAILABLE',
          statusCode: failure.statusCode,
          message: failure.code == null
              ? 'Chưa kết nối được trợ lý. Vui lòng thử lại sau.'
              : failure.message);
    } on FormatException {
      throw const ApiFailure(
          code: 'AI_INVALID_RESPONSE',
          message: 'Không thể đọc câu trả lời hoặc nguồn từ máy chủ.');
    } on TypeError {
      throw const ApiFailure(
          code: 'AI_INVALID_RESPONSE', message: 'Dữ liệu trợ lý không hợp lệ.');
    }
  }
}
