import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/chatbot/chatbot_providers.dart';
import 'package:rental_room_management/features/rooms/property_selection_provider.dart';
import 'package:rental_room_management/models/chatbot.dart';
import 'chatbot_test_support.dart';

void main() {
  late ChatTestRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = ChatTestRepository();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      chatbotRepositoryProvider.overrideWithValue(repository),
    ]);
    container.listen(chatbotControllerProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  test('allows only one in-flight question', () async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    final controller = container.read(chatbotControllerProvider.notifier);
    final first = controller.send('Câu hỏi A');
    await controller.send('Câu hỏi B');
    expect(repository.calls, 1);
    expect(container.read(chatbotControllerProvider).isSending, isTrue);
    pending.complete(chatTestAnswer);
    await first;
    expect(container.read(chatbotControllerProvider).messages, hasLength(2));
  });
  test('account change cancels and discards a late response', () async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    final first = container
        .read(chatbotControllerProvider.notifier)
        .send('Riêng tài khoản A');
    final cancellation = repository.cancellation!;
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await container.pump();
    expect(cancellation.isCancelled, isTrue);
    pending.complete(chatTestAnswer);
    await first;
    expect(container.read(chatbotControllerProvider).sessionId, 'b');
    expect(container.read(chatbotControllerProvider).messages, isEmpty);
  });
  test('property change cancels and starts an empty conversation', () async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    final first = container
        .read(chatbotControllerProvider.notifier)
        .send('Câu hỏi khu cũ');
    final cancellation = repository.cancellation!;
    container.read(selectedPropertyProvider.notifier).state = 'new-property';
    await container.pump();
    expect(cancellation.isCancelled, isTrue);
    pending.complete(chatTestAnswer);
    await first;
    expect(container.read(chatbotControllerProvider).messages, isEmpty);
    expect(
        container.read(chatbotControllerProvider).propertyId, 'new-property');
  });
  test('logout then login to the same account cannot restore an old result',
      () async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    final first = container
        .read(chatbotControllerProvider.notifier)
        .send('Câu hỏi phiên cũ');
    final session =
        container.read(sessionControllerProvider.notifier) as ChatTestSession;
    session.change(null);
    session.change(chatSession('a'));
    pending.complete(chatTestAnswer);
    await first;
    await container.pump();
    expect(container.read(chatbotControllerProvider).messages, isEmpty);
  });
  test(
      'explicit retry makes a new request without duplicating the user message',
      () async {
    repository.respond =
        (_) => Future.error(const ApiFailure(code: 'AI_BUSY', message: 'Bận'));
    final controller = container.read(chatbotControllerProvider.notifier);
    await controller.send('Cách tạo hóa đơn?');
    expect(container.read(chatbotControllerProvider).error?.code, 'AI_BUSY');
    expect(repository.calls, 1);
    repository.respond = (_) async => chatTestAnswer;
    await controller.retry();
    expect(repository.calls, 2);
    expect(container.read(chatbotControllerProvider).messages, hasLength(2));
    expect(container.read(chatbotControllerProvider).error, isNull);
  });
  test('dispose cancels an active request', () async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    final first =
        container.read(chatbotControllerProvider.notifier).send('Câu hỏi');
    final cancellation = repository.cancellation!;
    container.invalidate(chatbotControllerProvider);
    expect(cancellation.isCancelled, isTrue);
    pending.complete(chatTestAnswer);
    await first;
  });
  test('non-landlord state cannot issue a request', () async {
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('staff', role: 'staff'));
    await container.pump();
    await container.read(chatbotControllerProvider.notifier).send('Câu hỏi');
    expect(repository.calls, 0);
  });
  test('source hash changes require a new question rather than stale excerpts',
      () async {
    repository.loadSource = () async => const ChatSourceDetail(
        source: ChatSource(
            id: 'c1',
            documentId: 'd1',
            contentHash: 'new-hash',
            title: 'Hóa đơn',
            heading: ''),
        text: 'Changed document');
    await expectLater(
        container.read(chatSourceProvider(chatTestSource).future),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'code', 'KNOWLEDGE_NOT_FOUND')));
  });
}
