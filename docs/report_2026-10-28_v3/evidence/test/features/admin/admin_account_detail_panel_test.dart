import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/data/admin/admin_repository.dart';
import 'package:rental_room_management/features/admin/admin_account_detail_panel.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_account_detail.dart';
import 'package:rental_room_management/models/admin_models.dart';
import '../../fixtures/admin_accounts_capture.dart';

final _owner = StateProvider<String?>((ref) => 'operator');
final _rights = StateProvider<List<String>>((ref) => [
      'admin.accounts.view',
      'admin.accounts.suspend',
      'admin.sessions.revoke',
      'admin.accounts.manage',
      'admin.pii.reveal'
    ]);

AdminAccountDetail _detail({bool active = true}) => AdminAccountDetail(
        account: AdminAccount(
            id: 'customer',
            fullName: 'Customer account',
            email: 'c***@example.test',
            phone: '***678',
            role: 'LANDLORD',
            isActive: active,
            version: 7,
            createdAt: DateTime.utc(2026, 10, 27)),
        properties: 3,
        tenants: 5,
        history: const [
          AdminAuditEntry(
              id: 'history',
              action: 'admin.account_restore',
              resourceType: 'user',
              summary: 'Verified account recovery')
        ]);

class _Api extends AdminApi {
  _Api() : super(Dio());
  final calls = <String>[];
  int? version;
  String? reason;
  Object? failure;
  Completer<AdminAccount>? pending;
  Completer<AdminAccountContacts>? pendingContacts;

  @override
  Future<AdminAccount> updateAccountStatus(String id,
      {required bool isActive,
      required int version,
      required String reason,
      required AdminStepUpPrompt prompt}) async {
    calls.add(isActive ? 'restore' : 'suspend');
    this.version = version;
    this.reason = reason;
    if (failure != null) throw failure!;
    return pending == null
        ? _detail(active: isActive).account
        : pending!.future;
  }

  @override
  Future<AdminAccountContacts> revealAccountContacts(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    calls.add('reveal');
    if (pendingContacts != null) return pendingContacts!.future;
    return const AdminAccountContacts(
        email: 'private@example.test', phone: '0912345678');
  }

  @override
  Future<int> revokeAccountSessions(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    calls.add('revoke');
    return 2;
  }

  @override
  Future<void> resetAccountPassword(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    calls.add('reset');
  }
}

class _Repository extends AdminRepository {
  _Repository(_Api api) : super(api: api);
  int reads = 0;
  bool active = true;
  Object? failure;
  @override
  Future<AdminAccountDetail> account(String id) async {
    reads++;
    if (failure != null) throw failure!;
    return _detail(active: active);
  }
}

Future<ProviderContainer> _pump(
    WidgetTester tester, _Api api, _Repository repository,
    {List<String>? rights,
    Size size = const Size(1000, 1000),
    double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionIdentityProvider.overrideWith((ref) => ref.watch(_owner)),
        if (rights != null) _rights.overrideWith((ref) => rights),
        adminCapabilitiesProvider
            .overrideWith((ref) async => AdminCapabilities(ref.watch(_rights))),
        adminApiProvider.overrideWithValue(api),
        adminRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: const RepaintBoundary(
              key: adminAccountsCaptureKey,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child:
                          AdminAccountDetailPanel(accountId: 'customer')))))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

Future<void> _reason(WidgetTester tester, String action) async {
  final button = find.text(action);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byType(TextFormField), 'Verified support case ACCT-123');
  await tester.tap(find.text('Xác nhận'));
  await tester.pump();
}

void main() {
  setUpAll(loadAdminAccountsCaptureFonts);
  testWidgets('detail shows counts and history; suspend binds current version',
      (tester) async {
    final api = _Api();
    final repository = _Repository(api);
    await _pump(tester, api, repository);
    expect(find.text('3 khu trọ · 5 hồ sơ người thuê'), findsOneWidget);
    expect(find.text('Verified account recovery'), findsOneWidget);
    await captureAdminAccounts(tester, 'account-detail-desktop');
    await _reason(tester, 'Khóa tài khoản');
    await tester.pumpAndSettle();
    expect(api.calls, ['suspend']);
    expect(api.version, 7);
    expect(api.reason, 'Verified support case ACCT-123');
    expect(repository.reads, 2);
  });

  testWidgets('conflict requires reload, does not automatically retry mutation',
      (tester) async {
    final api = _Api()
      ..failure = const ApiFailure(message: 'Changed', statusCode: 409);
    final repository = _Repository(api);
    await _pump(tester, api, repository);
    await _reason(tester, 'Khóa tài khoản');
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu đã thay đổi. Hãy tải lại trước khi thao tác.'),
        findsOneWidget);
    expect(api.calls, ['suspend']);
    await tester.ensureVisible(find.text('Tải lại tài khoản'));
    await tester.tap(find.text('Tải lại tài khoản'));
    await tester.pumpAndSettle();
    expect(repository.reads, 2);
    expect(api.calls, ['suspend']);
  });

  testWidgets('PII dialog vanishes immediately when session changes',
      (tester) async {
    final api = _Api();
    final container = await _pump(tester, api, _Repository(api));
    await _reason(tester, 'Xem liên hệ có ghi log');
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsOneWidget);
    container.read(_owner.notifier).state = 'another-admin';
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsNothing);
    expect(find.text('Customer account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'revoking permission closes an open confirmation without issuing a command',
      (tester) async {
    final api = _Api();
    final container = await _pump(tester, api, _Repository(api));
    await tester.tap(find.text('Khóa tài khoản'));
    await tester.pumpAndSettle();
    container.read(_rights.notifier).state = ['admin.accounts.view'];
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets(
      'read-only admin cannot mutate; missing account has specific state',
      (tester) async {
    final api = _Api();
    final repository = _Repository(api)
      ..failure = const ApiFailure(message: 'Not found', statusCode: 404);
    await _pump(tester, api, repository, rights: ['admin.accounts.view']);
    expect(find.text('Không tìm thấy tài khoản.'), findsOneWidget);
    expect(find.text('Khóa tài khoản'), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('detail renders on a narrow screen at 200 percent text',
      (tester) async {
    final api = _Api();
    await _pump(tester, api, _Repository(api),
        size: const Size(320, 1000), textScale: 2);
    expect(find.text('Customer account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureAdminAccounts(tester, 'account-detail-mobile-large-text');
  });

  testWidgets('read-only view exposes no mutation or unmasked contacts',
      (tester) async {
    final api = _Api();
    await _pump(tester, api, _Repository(api), rights: ['admin.accounts.view']);
    expect(find.text('Customer account'), findsOneWidget);
    for (final action in [
      'Khóa tài khoản',
      'Thu hồi phiên',
      'Gửi reset mật khẩu',
      'Xem liên hệ có ghi log'
    ]) {
      expect(find.text(action), findsNothing);
    }
    expect(find.text('private@example.test'), findsNothing);
  });

  testWidgets('restore binds version and inactive accounts cannot reset',
      (tester) async {
    final api = _Api();
    final repository = _Repository(api)..active = false;
    await _pump(tester, api, repository);
    final reset = find.widgetWithText(OutlinedButton, 'Gửi reset mật khẩu');
    expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
    await _reason(tester, 'Mở lại tài khoản');
    await tester.pumpAndSettle();
    expect(api.calls, ['restore']);
    expect(api.version, 7);
  });

  testWidgets('revoke and reset confirm reasons and reload detail',
      (tester) async {
    final api = _Api();
    final repository = _Repository(api);
    await _pump(tester, api, repository);
    await _reason(tester, 'Thu hồi phiên');
    await tester.pumpAndSettle();
    await _reason(tester, 'Gửi reset mật khẩu');
    await tester.pumpAndSettle();
    expect(api.calls, ['revoke', 'reset']);
    expect(repository.reads, 3);
  });

  testWidgets(
      'pending mutation disables actions; late result cannot restore old UI',
      (tester) async {
    final api = _Api()..pending = Completer<AdminAccount>();
    final repository = _Repository(api);
    final container = await _pump(tester, api, repository);
    await _reason(tester, 'Khóa tài khoản');
    await tester.pump(const Duration(milliseconds: 400));
    final suspend = find.ancestor(
        of: find.text('Khóa tài khoản'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton));
    expect(tester.widget<OutlinedButton>(suspend).onPressed, isNull);
    container.read(_owner.notifier).state = null;
    await tester.pump();
    api.pending!.complete(_detail(active: false).account);
    await tester.pumpAndSettle();
    expect(find.text('Customer account'), findsNothing);
    expect(find.text('Đã ghi nhận thao tác.'), findsNothing);
    expect(repository.reads, 1);
    expect(api.calls, ['suspend']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('private contacts stay hidden after app backgrounding',
      (tester) async {
    final api = _Api();
    await _pump(tester, api, _Repository(api));
    await _reason(tester, 'Xem liên hệ có ghi log');
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsNothing);
    expect(find.text('Thông tin đã được ẩn. Đóng và xác thực lại khi cần.'),
        findsOneWidget);
  });

  testWidgets('restored permission cannot resurrect an old PII reveal',
      (tester) async {
    final api = _Api();
    final container = await _pump(tester, api, _Repository(api));
    await _reason(tester, 'Xem liên hệ có ghi log');
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsOneWidget);
    final previous = container.read(_rights);
    container.read(_rights.notifier).state = ['admin.accounts.view'];
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsNothing);
    container.read(_rights.notifier).state = previous;
    await tester.pumpAndSettle();
    expect(find.text('private@example.test'), findsNothing);
    expect(api.calls, ['reveal']);
  });

  testWidgets('PII arriving after backgrounding starts hidden', (tester) async {
    final api = _Api()..pendingContacts = Completer<AdminAccountContacts>();
    await _pump(tester, api, _Repository(api));
    await _reason(tester, 'Xem liên hệ có ghi log');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    api.pendingContacts!.complete(
        const AdminAccountContacts(email: 'late-private@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('late-private@example.test'), findsNothing);
    expect(find.text('Thông tin đã được ẩn. Đóng và xác thực lại khi cần.'),
        findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
