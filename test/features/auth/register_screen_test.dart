import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/auth/auth_api.dart';
import 'package:rental_room_management/data/auth/auth_repository.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
import 'package:rental_room_management/features/auth/account_access_link.dart';
import 'package:rental_room_management/features/auth/auth_form.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/auth/register_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';

class _MemoryStorage extends SecureSessionStorage {
  AuthSession? session;

  @override
  Future<void> write(AuthSession value) async => session = value;
}

class _RegistrationAdapter implements HttpClientAdapter {
  _RegistrationAdapter({this.errorCode, this.statusCode = 409});

  String? errorCode;
  final int statusCode;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (errorCode != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {
            'code': errorCode,
            'message': errorCode == 'EMAIL_ALREADY_REGISTERED'
                ? 'Email is already registered.'
                : 'Unable to complete the request.',
          },
          'requestId': 'signup-request-123',
        }),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final seeker = options.path == '/auth/register-seeker';
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'user': {
            'id': 'registered-user',
            'fullName': 'Test User',
            'email': 'register@example.test',
            'role': seeker ? 'tenant' : 'landlord',
          },
          'accessToken': 'test-access',
          'refreshToken': 'test-refresh',
        },
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _mount(WidgetTester tester,
    {_RegistrationAdapter? adapter}) async {
  final router = GoRouter(initialLocation: registerRoute, routes: [
    GoRoute(path: registerRoute, builder: (_, __) => const RegisterScreen()),
    for (final route in [exploreRoute, dashboardRoute])
      GoRoute(
        path: route,
        builder: (_, __) =>
            const Scaffold(body: Text('Registered successfully')),
      ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      if (adapter != null)
        authRepositoryProvider.overrideWithValue(AuthRepository(
          api: AuthApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
            ..httpClientAdapter = adapter),
          storage: _MemoryStorage(),
        )),
    ],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Finder _input(String hint) => find.descendant(
      of: find.byWidgetPredicate(
          (widget) => widget is AuthTextField && widget.hintText == hint),
      matching: find.byType(TextFormField),
    );

Future<void> _fill(WidgetTester tester,
    {String phone = '090 123 4567',
    String password = 'StrongPassword!123'}) async {
  for (final entry in {
    'Full name': ' Test User ',
    'Email address': 'register@example.test',
    'Phone number': phone,
    'Password': password,
    'Confirm password': password,
  }.entries) {
    await tester.ensureVisible(_input(entry.key));
    await tester.enterText(_input(entry.key), entry.value);
    await tester.pumpAndSettle();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Sign Up');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test('password errors identify missing rules without changing legacy login',
      () {
    expect(accountPasswordValidation('abc123'), 'Dùng từ 12 đến 128 ký tự.');
    expect(accountPasswordValidation('abc123abc123'),
        'Cần thêm: chữ hoa, ký tự đặc biệt.');
    expect(accountPasswordValidation('StrongPassword!123'), isNull);
    expect(accountPasswordValidation('A1!${'a' * 126}'),
        'Dùng từ 12 đến 128 ký tự.');
    expect(passwordValue('abc123'), isNull);
  });

  testWidgets('purpose selector matches the light authentication fields',
      (tester) async {
    await _mount(tester);
    final dropdown =
        tester.widget<DropdownButton<bool>>(find.byType(DropdownButton<bool>));
    expect(dropdown.style?.color, kAuthText);
    expect(dropdown.style?.fontSize, 15);
    expect(dropdown.dropdownColor, kAuthCardBg);
    expect(dropdown.isExpanded, isTrue);

    final decorator = tester.widget<InputDecorator>(find.descendant(
      of: find.byType(DropdownButtonFormField<bool>),
      matching: find.byType(InputDecorator),
    ));
    expect(decorator.decoration.fillColor, kAuthInputBg);
    final border = decorator.decoration.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, kAuthBorder);
    expect(border.borderRadius, BorderRadius.circular(16));
    final focused = decorator.decoration.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.color, kAuthBorderFocused);
    expect(decorator.decoration.labelText, isNull);
    expect(find.text('Bạn muốn sử dụng ứng dụng để'), findsOneWidget);
  });

  testWidgets('purpose menu allows switching between both account types',
      (tester) async {
    await _mount(tester);
    final selector = find.byType(DropdownButton<bool>);
    expect(tester.widget<DropdownButton<bool>>(selector).value, isTrue);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final menuText = tester.element(find.text('Quản lý nhà trọ').last);
    expect(DefaultTextStyle.of(menuText).style.color, kAuthText);
    await tester.tap(find.text('Quản lý nhà trọ').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<bool>>(selector).value, isFalse);

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm thuê phòng').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<bool>>(selector).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purpose selector fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester);
    await tester.ensureVisible(find.byType(DropdownButton<bool>));
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows password and phone warnings while entering invalid data',
      (tester) async {
    await _mount(tester);
    final password = find.descendant(
      of: find.byWidgetPredicate(
          (widget) => widget is AuthTextField && widget.hintText == 'Password'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(password, 'abc123');
    await tester.pumpAndSettle();
    expect(find.text('Dùng từ 12 đến 128 ký tự.'), findsOneWidget);
    final phone = find.descendant(
      of: find.byWidgetPredicate((widget) =>
          widget is AuthTextField && widget.hintText == 'Phone number'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(phone, '123');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Nhập số Việt Nam hợp lệ (vd. 0901234567) hoặc số có mã quốc gia.'),
        findsOneWidget);
  });

  testWidgets('updates password errors and dependent confirmation while typing',
      (tester) async {
    await _mount(tester);
    expect(find.text('Dùng từ 12 đến 128 ký tự.'), findsNothing);
    expect(
      find.text(
          'Mật khẩu 12–128 ký tự, có chữ hoa, chữ thường, số và ký tự đặc biệt.'),
      findsOneWidget,
    );
    await tester.enterText(_input('Password'), 'abc123abc123');
    await tester.pumpAndSettle();
    expect(find.text('Cần thêm: chữ hoa, ký tự đặc biệt.'), findsOneWidget);
    await tester.enterText(_input('Password'), 'StrongPassword!123');
    await tester.enterText(_input('Confirm password'), 'StrongPassword!123');
    await tester.pumpAndSettle();
    expect(find.text('Cần thêm: chữ hoa, ký tự đặc biệt.'), findsNothing);
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsNothing);
    await tester.enterText(_input('Password'), 'AnotherStrong!123');
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
  });

  for (final seeker in [true, false]) {
    testWidgets(
        'registers ${seeker ? 'seeker' : 'landlord'} with normalized phone',
        (tester) async {
      final adapter = _RegistrationAdapter();
      await _mount(tester, adapter: adapter);
      if (!seeker) {
        await tester.tap(find.byType(DropdownButton<bool>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Quản lý nhà trọ').last);
        await tester.pumpAndSettle();
      }
      await _fill(tester);
      await _submit(tester);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path,
          seeker ? '/auth/register-seeker' : '/auth/register');
      expect(adapter.requests.single.data, {
        'fullName': 'Test User',
        'email': 'register@example.test',
        'phone': '+84901234567',
        'password': 'StrongPassword!123',
      });
      expect(find.text('Registered successfully'), findsOneWidget);
    });
  }

  testWidgets('explains duplicate email visibly and allows correcting it',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = _RegistrationAdapter(errorCode: 'EMAIL_ALREADY_REGISTERED');
    await _mount(tester, adapter: adapter);
    await _fill(tester);
    await _submit(tester);
    final warning = find
        .text('Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.');
    expect(warning, findsOneWidget);
    expect(warning.hitTestable(), findsOneWidget);
    expect(find.text('Email is already registered.'), findsNothing);
    expect(find.text('Registered successfully'), findsNothing);

    adapter.errorCode = null;
    await tester.ensureVisible(_input('Email address'));
    await tester.enterText(_input('Email address'), 'new-email@example.test');
    await _submit(tester);
    expect(adapter.requests.last.data['email'], 'new-email@example.test');
    expect(find.text('Registered successfully'), findsOneWidget);
  });

  for (final failure in [
    (
      code: 'RATE_LIMITED',
      status: 429,
      message:
          'Bạn đã thử đăng ký quá nhiều lần. Vui lòng đợi một phút rồi thử lại.',
    ),
    (
      code: 'INTERNAL_SERVER_ERROR',
      status: 500,
      message:
          'Máy chủ đang gặp lỗi. Vui lòng thử lại sau. Mã hỗ trợ: signup-request-123.',
    ),
  ]) {
    testWidgets('explains ${failure.code} without hiding the failure',
        (tester) async {
      final adapter = _RegistrationAdapter(
          errorCode: failure.code, statusCode: failure.status);
      await _mount(tester, adapter: adapter);
      await _fill(tester);
      await _submit(tester);
      expect(find.text(failure.message).hitTestable(), findsOneWidget);
      expect(find.text('Registered successfully'), findsNothing);
    });
  }

  testWidgets('does not send a request for invalid password or phone',
      (tester) async {
    final adapter = _RegistrationAdapter();
    await _mount(tester, adapter: adapter);
    await _fill(tester, password: 'abc123', phone: '123');
    await _submit(tester);
    expect(adapter.requests, isEmpty);
    expect(find.text('Dùng từ 12 đến 128 ký tự.'), findsOneWidget);
    expect(
        find.text(
            'Nhập số Việt Nam hợp lệ (vd. 0901234567) hoặc số có mã quốc gia.'),
        findsOneWidget);
  });

  testWidgets('validates empty fields on submit without sending a request',
      (tester) async {
    final adapter = _RegistrationAdapter();
    await _mount(tester, adapter: adapter);
    await _submit(tester);
    expect(adapter.requests, isEmpty);
    for (final message in [
      'Vui lòng nhập họ tên.',
      'Vui lòng nhập số điện thoại.',
      'Dùng từ 12 đến 128 ký tự.',
      'Vui lòng nhập lại mật khẩu.',
    ]) {
      expect(find.text(message), findsOneWidget);
    }
  });

  testWidgets(
      'rejects overlong names and preserves existing international phones',
      (tester) async {
    await _mount(tester);
    final name = tester.widget<TextFormField>(_input('Full name'));
    expect(name.validator!('a' * 121), 'Họ tên không quá 120 ký tự.');
    final phone = tester.widget<TextFormField>(_input('Phone number'));
    for (final value in [
      '0901234567',
      '+84901234567',
      '+16502530000',
      '02412345678'
    ]) {
      expect(phone.validator!(value), isNull, reason: value);
    }
    for (final value in [
      'abc',
      '123',
      '09012345678',
      '+840901234567',
      '0000000000'
    ]) {
      expect(phone.validator!(value), isNotNull, reason: value);
    }
  });
}
