import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/reviews_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/listings/listing_widgets.dart';
import 'package:rental_room_management/features/listings/manage_reviews_screen.dart';
import 'package:rental_room_management/features/listings/review_composer.dart';
import 'package:rental_room_management/features/listings/reviews_providers.dart';
import 'package:rental_room_management/models/housing.dart';
import 'package:rental_room_management/models/room_review.dart';

import '../../data/listings/reviews_repository_test.dart' show reviewJson;
import '../chatbot/chatbot_test_support.dart';

class ReviewTestRepository extends ReviewsRepository {
  ReviewTestRepository() : super(Dio());

  RoomReview? saved;
  bool eligible = true, fail = false, empty = false;
  int submissions = 0, withdrawals = 0, replies = 0, moderations = 0;
  String? replyBody, moderationStatus, moderationNote;
  bool? moderatedReply;
  final queries = <ManagedReviewsQuery>[];
  final publicPages = <int>[];

  RoomReview get sample => RoomReview.fromJson({
        ...reviewJson,
        'roomName': 'P.101',
        'propertyName': 'Trọ A',
        'replyBody': 'Cảm ơn nhận xét của bạn.',
        'replyStatus': 'PENDING',
      });

  @override
  Future<ReviewContext> context(String leaseId) async => ReviewContext(
        leaseId: leaseId,
        roomName: 'P.101',
        propertyName: 'Trọ A',
        eligible: eligible,
        reason: eligible ? null : 'Cần xác nhận nhận phòng.',
        review: saved,
      );

  @override
  Future<void> submit(String leaseId, Map<String, int> scores, String body,
      {RoomReview? existing}) async {
    submissions++;
    if (fail) {
      throw const ApiFailure(
          message: 'Đánh giá vừa thay đổi. Hãy tải lại.', statusCode: 409);
    }
    saved = RoomReview.fromJson({
      ...reviewJson,
      ...scores,
      'body': body,
      'status': 'PENDING',
      'version': (existing?.version ?? 0) + 1
    });
  }

  @override
  Future<void> withdraw(RoomReview review) async {
    withdrawals++;
    saved = RoomReview.fromJson({
      ...reviewJson,
      'status': 'HIDDEN',
      'version': review.version + 1,
      'withdrawnAt': '2026-10-24T02:00:00Z'
    });
  }

  @override
  Future<HousingPage<RoomReview>> manage(
      {required bool admin,
      required int page,
      String status = 'PENDING',
      bool replies = false}) async {
    queries.add((admin: admin, page: page, status: status, replies: replies));
    if (fail) throw const ApiFailure(message: 'Không có mạng.');
    return HousingPage(
        items: empty ? [] : [sample],
        page: page,
        total: empty ? 0 : 12,
        limit: 10);
  }

  @override
  Future<void> reply(RoomReview review, String body) async {
    replies++;
    if (fail) {
      throw const ApiFailure(
          message: 'Đánh giá vừa thay đổi. Hãy tải lại.', statusCode: 409);
    }
    replyBody = body;
  }

  @override
  Future<void> moderate(RoomReview review, String status, String note,
      {required bool reply}) async {
    moderations++;
    moderationStatus = status;
    moderationNote = note;
    moderatedReply = reply;
  }

  @override
  Future<PublicReviewPage> publicReviews(String listingId, int page) async {
    publicPages.add(page);
    return PublicReviewPage(
      page: HousingPage(
          items: empty ? [] : [sample],
          page: page,
          total: empty ? 0 : 12,
          limit: 10),
      count: empty ? 0 : 12,
      overall: empty ? null : 4,
      averages: {for (final key in reviewCriteria.keys) key: empty ? null : 4},
    );
  }
}

void main() {
  late ProviderContainer container;
  late ReviewTestRepository repository;
  setUp(() {
    repository = ReviewTestRepository();
    container = ProviderContainer(overrides: [
      sessionControllerProvider.overrideWith(ChatTestSession.new),
      reviewsRepositoryProvider.overrideWithValue(repository),
      publicReviewsRepositoryProvider.overrideWithValue(repository),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> show(WidgetTester tester, Widget screen,
      {String role = 'tenant', double scale = 1}) async {
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('a', role: role));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget composer() => ListingTheme(
          child: Scaffold(
              body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Consumer(
            builder: (_, ref, __) => ref
                .watch(reviewContextProvider('lease-1'))
                .when(
                    data: (data) => ReviewComposer(contextData: data),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, _) => Text('$error'))),
      )));

  test('review routes are restricted to their intended roles', () {
    for (final route in [landlordReviewsRoute, adminReviewsRoute]) {
      expect(
          authRedirect(
              state: const SessionState.unauthenticated(), location: route),
          loginRoute);
      expect(
          authRedirect(
              state:
                  SessionState.authenticated(chatSession('a', role: 'tenant')),
              location: route),
          exploreRoute);
      expect(
          authRedirect(
              state:
                  SessionState.authenticated(chatSession('a', role: 'staff')),
              location: route),
          settingsRoute);
    }
    expect(
        authRedirect(
            state: SessionState.authenticated(chatSession('a')),
            location: landlordReviewsRoute),
        isNull);
    expect(
        authRedirect(
            state: SessionState.authenticated(chatSession('a', role: 'admin')),
            location: adminReviewsRoute),
        adminRoute);
  });

  testWidgets('ineligible tenants see the reason instead of a submission form',
      (tester) async {
    repository.eligible = false;
    await show(tester, composer());
    expect(find.text('Cần xác nhận nhận phòng.'), findsOneWidget);
    expect(find.text('Gửi đánh giá'), findsNothing);
  });

  testWidgets(
      'validates review text and submits all four criteria for moderation',
      (tester) async {
    await show(tester, composer());
    await tester.ensureVisible(find.text('Gửi đánh giá'));
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('Viết ít nhất 20 ký tự.'), findsOneWidget);
    expect(repository.submissions, 0);
    await tester.enterText(find.byType(TextFormField),
        'Phòng ở sạch sẽ, chi phí rõ ràng và chủ trọ hỗ trợ tốt.');
    await tester.ensureVisible(find.text('Gửi đánh giá'));
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(repository.submissions, 1);
    expect(repository.saved!.scores.keys, containsAll(reviewCriteria.keys));
    expect(find.text('Trạng thái: Chờ kiểm duyệt'), findsOneWidget);
  });

  testWidgets('conflicts preserve tenant input and offer reload',
      (tester) async {
    repository.fail = true;
    await show(tester, composer());
    const body =
        'Trải nghiệm thực tế đủ dài để gửi lại sau khi tải dữ liệu mới.';
    await tester.enterText(find.byType(TextFormField), body);
    await tester.ensureVisible(find.text('Gửi đánh giá'));
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá vừa thay đổi. Hãy tải lại.'), findsOneWidget);
    expect(find.text('Tải lại đánh giá'), findsOneWidget);
    expect(find.text(body), findsOneWidget);
  });

  testWidgets('tenant confirms withdrawal and can later resubmit',
      (tester) async {
    repository.saved = repository.sample;
    await show(tester, composer());
    await tester.ensureVisible(find.text('Gỡ đánh giá'));
    await tester.tap(find.text('Gỡ đánh giá'));
    await tester.pumpAndSettle();
    expect(repository.withdrawals, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Gỡ đánh giá'));
    await tester.pumpAndSettle();
    expect(repository.withdrawals, 1);
    expect(find.text('Trạng thái: Đã gỡ'), findsOneWidget);
    expect(find.text('Gửi đánh giá'), findsOneWidget);
  });

  testWidgets('landlord reply validates length and remains in moderation flow',
      (tester) async {
    await show(tester, const ManageReviewsScreen(), role: 'landlord');
    await tester.ensureVisible(find.text('Sửa phản hồi'));
    await tester.tap(find.text('Sửa phản hồi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' ');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ít nhất 5 ký tự.'), findsOneWidget);
    expect(repository.replies, 0);
    await tester.enterText(find.byType(TextFormField),
        'Cảm ơn bạn đã góp ý, mình sẽ kiểm tra lại.');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.replies, 1);
    expect(repository.replyBody, contains('kiểm tra lại'));
    expect(find.text('Đã gửi phản hồi, chờ kiểm duyệt.'), findsOneWidget);
  });

  testWidgets('admin filters reply queue and requires a moderation reason',
      (tester) async {
    await show(tester, const ManageReviewsScreen(admin: true), role: 'admin');
    await tester.tap(find.text('Phản hồi chủ trọ'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.replies, isTrue);
    await tester.ensureVisible(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.moderations, 0);
    await tester.enterText(
        find.byType(TextFormField), 'Cần bỏ thông tin liên hệ riêng tư.');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(repository.moderationStatus, 'REJECTED');
    expect(repository.moderatedReply, isTrue);
    expect(repository.moderationNote, contains('riêng tư'));
  });

  testWidgets(
      'account changes disable open actions instead of using new credentials',
      (tester) async {
    await show(tester, const ManageReviewsScreen(), role: 'landlord');
    await tester.ensureVisible(find.text('Sửa phản hồi'));
    await tester.tap(find.text('Sửa phản hồi'));
    await tester.pumpAndSettle();
    (container.read(sessionControllerProvider.notifier) as ChatTestSession)
        .change(chatSession('b'));
    await tester.pumpAndSettle();
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận'));
    expect(button.onPressed, isNull);
    expect(find.byType(TextFormField), findsNothing);
    expect(repository.replies, 0);
    expect(find.text('Phiên quản lý đã thay đổi. Hãy đóng và mở lại trang.'),
        findsOneWidget);
  });

  testWidgets('managed lists paginate and recover from load errors',
      (tester) async {
    repository.fail = true;
    await show(tester, const ManageReviewsScreen(), role: 'landlord');
    expect(find.textContaining('Không có mạng.'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trang sau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.page, 2);
    expect(find.text('Trang 2'), findsOneWidget);
  });

  testWidgets('empty public reviews do not show fabricated ratings',
      (tester) async {
    repository.empty = true;
    await show(
        tester,
        const ListingTheme(
            child:
                Scaffold(body: PublicReviewsSection(listingId: 'listing-1'))));
    expect(find.text('Chưa có đánh giá đã được kiểm duyệt.'), findsOneWidget);
    expect(find.textContaining('/5'), findsNothing);
  });

  testWidgets('public reviews show four criteria and allow paging',
      (tester) async {
    await show(
        tester,
        const ListingTheme(
            child: Scaffold(
                body: SingleChildScrollView(
                    child: PublicReviewsSection(listingId: 'listing-1')))));
    expect(find.text('Khu vực: 4.0/5'), findsOneWidget);
    expect(find.text('Chủ trọ: 4.0/5'), findsOneWidget);
    await tester.ensureVisible(find.text('Trang sau'));
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(repository.publicPages, [1, 2]);
  });

  testWidgets('admin review controls fit a phone with enlarged text',
      (tester) async {
    await show(tester, const ManageReviewsScreen(admin: true),
        role: 'admin', scale: 1.8);
    await tester.ensureVisible(find.text('Ẩn nội dung'));
    expect(tester.takeException(), isNull);
  });
}
