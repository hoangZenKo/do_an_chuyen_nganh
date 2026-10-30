import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/maintenance/maintenance_api.dart';
import 'package:rental_room_management/data/maintenance/maintenance_repository.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/maintenance/maintenance_providers.dart';
import 'package:rental_room_management/features/maintenance/maintenance_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/maintenance.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
            id: 'owner-test', fullName: 'Owner', email: 'owner@example.test'),
        accessToken: 'test',
        refreshToken: 'test',
      ));
}

class _Repository extends MaintenanceRepository {
  _Repository() : super(MaintenanceApi(Dio()));

  var status = MaintenanceStatus.open;
  final comments = <MaintenanceComment>[];
  int starts = 0;
  final replies = <String>[];
  bool failComment = false;
  Completer<void>? pendingStart;
  Completer<void>? pendingComment;

  MaintenanceTicket get ticket => MaintenanceTicket(
        id: 'ticket-test',
        propertyId: 'property-test',
        roomId: 'room-test',
        roomName: 'P.201',
        title: 'Vòi nước bị rò',
        status: status,
        priority: MaintenancePriority.medium,
        comments: comments,
      );

  @override
  Future<MaintenanceListResult> list(
          {String? propertyId,
          String? roomId,
          MaintenanceStatus? status,
          MaintenancePriority? priority}) async =>
      MaintenanceListResult(
        items: [ticket],
        summary: const MaintenanceSummary(
            count: 1,
            openCount: 1,
            doneCount: 0,
            estimatedCost: 0,
            actualCost: 0),
      );

  @override
  Future<MaintenanceTicket> getById(String id) async => ticket;

  @override
  Future<MaintenanceTicket> updateStatus(
      String id, MaintenanceStatus next) async {
    starts++;
    if (pendingStart != null) await pendingStart!.future;
    status = next;
    return ticket;
  }

  @override
  Future<MaintenanceComment> addComment(
      {required String ticketId,
      required String body,
      List<String> imageUrls = const []}) async {
    replies.add(body);
    if (pendingComment != null) await pendingComment!.future;
    if (failComment) throw Exception('Không gửi được phản hồi thử nghiệm');
    final comment = MaintenanceComment(
        id: 'comment-test',
        ticketId: ticketId,
        authorId: 'owner-test',
        body: body,
        authorRole: 'landlord');
    comments.add(comment);
    return comment;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository,
    {bool detail = false}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        maintenanceRepositoryProvider.overrideWithValue(repository),
        selectedPropertyProvider.overrideWith((_) => null),
      ],
      child: MaterialApp(
          theme: AppTheme.dark,
          home: MaintenanceScreen(ticketId: detail ? 'ticket-test' : null))));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String action) async {
  final menu = find.byType(PopupMenuButton<String>);
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final family in ['Roboto', 'Ahem']) {
      await (FontLoader(family)
            ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
                .readAsBytes()
                .then(ByteData.sublistView)))
          .load();
    }
  });

  for (final detail in [false, true]) {
    testWidgets('start then reply without lifecycle errors, detail=$detail',
        (tester) async {
      final repository = _Repository();
      await _mount(tester, repository, detail: detail);
      await _menu(tester, 'Đang xử lý');
      expect(repository.status, MaintenanceStatus.inProgress);
      expect(repository.starts, 1);
      expect(tester.takeException(), isNull);
      await _menu(tester, 'Phản hồi');
      await tester.enterText(
          find.widgetWithText(TextField, 'Phản hồi'), 'Đã liên hệ thợ sửa');
      await tester.tap(find.text('Gửi'));
      await tester.pumpAndSettle();
      expect(repository.replies, ['Đã liên hệ thợ sửa']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('close focused reply and reopen with fresh input',
      (tester) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _menu(tester, 'Phản hồi');
    await tester.enterText(
        find.widgetWithText(TextField, 'Phản hồi'), 'Chưa gửi');
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _menu(tester, 'Phản hồi');
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Phản hồi'))
            .controller!
            .text,
        isEmpty);
    expect(repository.replies, isEmpty);
  });

  testWidgets('delayed status update survives a frame before replying',
      (tester) async {
    final repository = _Repository()..pendingStart = Completer<void>();
    await _mount(tester, repository);
    await _menu(tester, 'Đang xử lý');
    await tester.pump(const Duration(milliseconds: 150));
    repository.pendingStart!.complete();
    await tester.pumpAndSettle();
    expect(repository.status, MaintenanceStatus.inProgress);
    expect(find.text('Đã chuyển sang "Đang xử lý".'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed reply retains input and permits retry', (tester) async {
    final repository = _Repository()..failComment = true;
    await _mount(tester, repository);
    await _menu(tester, 'Phản hồi');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập nội dung phản hồi.'), findsOneWidget);
    expect(repository.replies, isEmpty);
    await tester.enterText(
        find.widgetWithText(TextField, 'Phản hồi'), 'Sẽ sửa chiều nay');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không gửi được phản hồi thử nghiệm'),
        findsOneWidget);
    expect(find.text('Sẽ sửa chiều nay'), findsOneWidget);
    repository.failComment = false;
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final fail in [false, true]) {
    testWidgets('dismiss pending reply safely, failure=$fail', (tester) async {
      final repository = _Repository()
        ..pendingComment = Completer<void>()
        ..failComment = fail;
      await _mount(tester, repository);
      await _menu(tester, 'Phản hồi');
      await tester.enterText(
          find.widgetWithText(TextField, 'Phản hồi'), 'Đã hẹn thợ');
      await tester.tap(find.text('Gửi'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      repository.pendingComment!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repository.replies, ['Đã hẹn thợ']);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}
