import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../data/chatbot/chatbot_api.dart';
import '../../data/chatbot/chatbot_repository.dart';
import '../../models/chatbot.dart';
import '../auth/auth_providers.dart';
import '../rooms/property_selection_provider.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepository(ChatbotApi(ref.watch(sessionDioProvider).client));
});

class ChatMessage {
  const ChatMessage({required this.text, required this.isUser, this.answer});
  final String text;
  final bool isUser;
  final ChatAnswer? answer;
}

class ChatbotState {
  const ChatbotState(
      {this.messages = const [],
      this.isSending = false,
      this.error,
      this.failedQuestion,
      this.sessionId,
      this.propertyId});
  final List<ChatMessage> messages;
  final bool isSending;
  final ApiFailure? error;
  final String? failedQuestion;
  final String? sessionId;
  final String? propertyId;
}

class ChatbotController extends AutoDisposeNotifier<ChatbotState> {
  Object? _lifecycle;
  late CancelToken _cancellation;
  bool _allowed = false;

  @override
  ChatbotState build() {
    final session = ref.watch(sessionControllerProvider).session;
    final identity = ref.watch(sessionIdentityProvider);
    final propertyId = ref.watch(selectedPropertyProvider);
    final lifecycle = Object();
    _lifecycle = lifecycle;
    final cancellation = CancelToken();
    _cancellation = cancellation;
    _allowed = session?.user.role == 'landlord' && identity != null;
    ref.onDispose(() {
      cancellation.cancel('Chat scope changed');
      if (identical(_lifecycle, lifecycle)) {
        _lifecycle = null;
      }
    });
    return ChatbotState(sessionId: identity, propertyId: propertyId);
  }

  Future<void> send(String question, {bool retry = false}) async {
    final message = question.trim();
    if (state.isSending ||
        !_allowed ||
        message.isEmpty ||
        message.length > 1000) {
      return;
    }
    final lifecycle = _lifecycle;
    final session = ref.read(sessionControllerProvider).session;
    final propertyId = state.propertyId;
    final sessionId = state.sessionId;
    final messages = List<ChatMessage>.of(state.messages);
    if (!retry) {
      messages.add(ChatMessage(text: message, isUser: true));
    }
    state = ChatbotState(
        messages: List.unmodifiable(messages),
        isSending: true,
        sessionId: sessionId,
        propertyId: propertyId);
    try {
      final answer = await ref
          .read(chatbotRepositoryProvider)
          .ask(message, propertyId: propertyId, cancelToken: _cancellation);
      if (!identical(_lifecycle, lifecycle) ||
          _lifecycle == null ||
          !identical(ref.read(sessionControllerProvider).session, session) ||
          ref.read(selectedPropertyProvider) != propertyId) {
        return;
      }
      state = ChatbotState(
          messages: List.unmodifiable([
            ...messages,
            ChatMessage(text: answer.answer, isUser: false, answer: answer)
          ]),
          sessionId: sessionId,
          propertyId: propertyId);
    } catch (error) {
      if (!identical(_lifecycle, lifecycle) ||
          _lifecycle == null ||
          !identical(ref.read(sessionControllerProvider).session, session) ||
          ref.read(selectedPropertyProvider) != propertyId) {
        return;
      }
      state = ChatbotState(
          messages: List.unmodifiable(messages),
          sessionId: sessionId,
          propertyId: propertyId,
          failedQuestion: message,
          error: error is ApiFailure
              ? error
              : const ApiFailure(
                  code: 'AI_UNAVAILABLE',
                  message: 'Chưa kết nối được trợ lý. Vui lòng thử lại.'));
    }
  }

  Future<void> retry() async {
    final question = state.failedQuestion;
    if (question != null) await send(question, retry: true);
  }
}

final chatbotControllerProvider =
    AutoDisposeNotifierProvider<ChatbotController, ChatbotState>(
        ChatbotController.new);

final chatSourceProvider = FutureProvider.autoDispose
    .family<ChatSourceDetail, ChatSource>((ref, source) async {
  ref.watch(sessionControllerProvider);
  final propertyId = ref.watch(selectedPropertyProvider);
  final cancellation = CancelToken();
  ref.onDispose(() => cancellation.cancel('Source scope changed'));
  final detail = await ref
      .watch(chatbotRepositoryProvider)
      .source(source.id, propertyId: propertyId, cancelToken: cancellation);
  if (detail.source.id != source.id ||
      detail.source.documentId != source.documentId ||
      detail.source.contentHash != source.contentHash) {
    throw const ApiFailure(
        code: 'KNOWLEDGE_NOT_FOUND',
        message: 'Nguồn đã thay đổi. Vui lòng hỏi lại.');
  }
  return detail;
});
