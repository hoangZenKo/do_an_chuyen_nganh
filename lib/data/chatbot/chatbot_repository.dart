import 'package:dio/dio.dart';

import '../../models/chatbot.dart';
import 'chatbot_api.dart';

class ChatbotRepository {
  const ChatbotRepository(this._api);
  final ChatbotApi _api;

  Future<ChatAnswer> ask(String message,
          {String? propertyId, CancelToken? cancelToken}) =>
      _api.ask(message, propertyId: propertyId, cancelToken: cancelToken);

  Future<ChatSourceDetail> source(String id,
          {String? propertyId, CancelToken? cancelToken}) =>
      _api.source(id, propertyId: propertyId, cancelToken: cancelToken);
}
