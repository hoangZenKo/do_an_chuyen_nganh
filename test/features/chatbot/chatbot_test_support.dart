import 'package:dio/dio.dart';
import 'package:rental_room_management/data/chatbot/chatbot_api.dart';
import 'package:rental_room_management/data/chatbot/chatbot_repository.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/chatbot.dart';

AuthSession chatSession(String account, {String role = 'landlord'}) =>
    AuthSession(
        user: LandlordUser(
            id: account,
            fullName: account,
            email: '$account@example.com',
            role: role),
        accessToken: 'token-$account',
        refreshToken: 'refresh-$account');

class ChatTestSession extends SessionController {
  @override
  SessionState build() => SessionState.authenticated(chatSession('a'));
  void change(AuthSession? session) {
    state = session == null
        ? const SessionState.unauthenticated()
        : SessionState.authenticated(session);
  }
}

const chatTestSource = ChatSource(
    id: 'c1',
    documentId: 'd1',
    contentHash: 'hash',
    title: 'Hóa đơn',
    heading: 'Tạo hóa đơn');
const chatTestAnswer = ChatAnswer(
    requestId: 'r1',
    status: ChatAnswerStatus.answered,
    answer: 'Mở mục Hóa đơn để tạo hóa đơn.',
    sources: [chatTestSource]);

class ChatTestRepository extends ChatbotRepository {
  ChatTestRepository() : super(ChatbotApi(Dio()));
  Future<ChatAnswer> Function(String)? respond;
  Future<ChatSourceDetail> Function()? loadSource;
  int calls = 0;
  int sourceCalls = 0;
  CancelToken? cancellation;
  String? property;

  @override
  Future<ChatAnswer> ask(String message,
      {String? propertyId, CancelToken? cancelToken}) {
    calls++;
    cancellation = cancelToken;
    property = propertyId;
    return respond?.call(message) ?? Future.value(chatTestAnswer);
  }

  @override
  Future<ChatSourceDetail> source(String id,
      {String? propertyId, CancelToken? cancelToken}) {
    sourceCalls++;
    return loadSource?.call() ??
        Future.value(const ChatSourceDetail(
            source: chatTestSource,
            text: 'Nguồn gốc: mở Hóa đơn, chọn hợp đồng.'));
  }
}
