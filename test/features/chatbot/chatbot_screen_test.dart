import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/chatbot/chatbot_providers.dart';
import 'package:rental_room_management/features/chatbot/chatbot_screen.dart';
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
  });
  tearDown(() => container.dispose());
  Future<void> show(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            home: const ChatbotScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('shows independent-question notice and supported suggestions',
      (tester) async {
    await show(tester);
    expect(find.text('Bạn muốn tìm hướng dẫn gì?'), findsOneWidget);
    expect(
        find.text(
            'Hỏi đáp tài liệu hướng dẫn. Mỗi câu hỏi được xử lý độc lập.'),
        findsOneWidget);
    expect(find.text('Phạm vi: Hướng dẫn chung'), findsOneWidget);
    expect(find.text('Cách tạo hóa đơn cho người thuê?'), findsOneWidget);
    expect(find.byTooltip('Gửi câu hỏi'), findsOneWidget);
    expect(repository.calls, 0);
  });
  testWidgets('sends a suggestion, shows loading, then an answer with source',
      (tester) async {
    final pending = Completer<ChatAnswer>();
    repository.respond = (_) => pending.future;
    await show(tester);
    await tester.tap(find.text('Cách tạo hóa đơn cho người thuê?'));
    await tester.pump();
    expect(find.text('Đang tìm nguồn và soạn câu trả lời…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    pending.complete(chatTestAnswer);
    await tester.pumpAndSettle();
    expect(find.text(chatTestAnswer.answer), findsOneWidget);
    expect(find.byTooltip('Mở nguồn: Hóa đơn'), findsOneWidget);
  });
  testWidgets('fetches source only on opening the sheet', (tester) async {
    await show(tester);
    await tester.tap(find.text('Cách tạo hóa đơn cho người thuê?'));
    await tester.pumpAndSettle();
    expect(repository.sourceCalls, 0);
    await tester.tap(find.byTooltip('Mở nguồn: Hóa đơn'));
    await tester.pumpAndSettle();
    expect(repository.sourceCalls, 1);
    expect(find.text('Nguồn gốc: mở Hóa đơn, chọn hợp đồng.'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng nguồn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mở nguồn: Hóa đơn'));
    await tester.pumpAndSettle();
    expect(repository.sourceCalls, 2);
  });
  testWidgets('shows insufficient evidence without fabricated sources',
      (tester) async {
    repository.respond = (_) async => const ChatAnswer(
        requestId: 'r2',
        status: ChatAnswerStatus.insufficientEvidence,
        answer: 'Chưa có nội quy được duyệt.',
        sources: []);
    await show(tester);
    await tester.enterText(find.byType(TextField), 'Có được nuôi mèo không?');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ căn cứ'), findsOneWidget);
    expect(find.text('Chưa có nội quy được duyệt.'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
  });
  testWidgets('retries an error only when the user requests it',
      (tester) async {
    repository.respond = (_) => Future.error(
        const ApiFailure(code: 'AI_BUSY', message: 'Trợ lý đang bận.'));
    await show(tester);
    await tester.tap(find.text('Cách tạo hóa đơn cho người thuê?'));
    await tester.pumpAndSettle();
    expect(find.text('Trợ lý đang bận.'), findsOneWidget);
    expect(repository.calls, 1);
    repository.respond = (_) async => chatTestAnswer;
    await tester.tap(find.text('Thử lại câu hỏi'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text(chatTestAnswer.answer), findsOneWidget);
  });
  testWidgets('revoked source is an error and never uses cached excerpts',
      (tester) async {
    repository.loadSource = () => Future.error(const ApiFailure(
        code: 'KNOWLEDGE_NOT_FOUND',
        statusCode: 404,
        message: 'Nguồn đã bị thu hồi.'));
    await show(tester);
    await tester.tap(find.text('Cách tạo hóa đơn cho người thuê?'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mở nguồn: Hóa đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Nguồn đã bị thu hồi.'), findsOneWidget);
    expect(find.text('Nguồn gốc: mở Hóa đơn, chọn hợp đồng.'), findsNothing);
  });
  testWidgets('account switch hides a visible source and clears the composer',
      (tester) async {
    await show(tester);
    await tester.tap(find.text('Cách tạo hóa đơn cho người thuê?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bản nháp riêng của A');
    await tester.tap(find.byTooltip('Mở nguồn: Hóa đơn'));
    await tester.pumpAndSettle();
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await tester.pumpAndSettle();
    expect(find.text('Nguồn gốc: mở Hóa đơn, chọn hợp đồng.'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp riêng của A'), findsNothing);
    expect(find.text(chatTestAnswer.answer), findsNothing);
  });
  testWidgets('fits a narrow screen with large text and keyboard insets',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, textScale: 1.8);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Cách tạo hóa đơn?');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('chat route is landlord-only even for direct links', () {
    expect(
        authRedirect(
            state: SessionState.authenticated(chatSession('owner')),
            location: chatbotRoute),
        isNull);
    expect(
        authRedirect(
            state: const SessionState.unauthenticated(),
            location: chatbotRoute),
        loginRoute);
    for (final role in ['admin', 'tenant', 'staff']) {
      final session = chatSession(role, role: role);
      expect(
          authRedirect(
              state: SessionState.authenticated(session),
              location: chatbotRoute),
          homeRouteForSession(session));
    }
  });
}
