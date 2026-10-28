import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/auth/account_access_link.dart';
import 'package:rental_room_management/features/auth/password_recovery_dialog.dart';

void main() {
  const token = 'abcdefghijklmnopqrstuvwxyz0123456789_-ABCD';
  test('activation handles fragments, query links, and malformed tokens safely',
      () {
    expect(
        accountAccessTokenFromUri(Uri.parse('/account/activate#token=$token')),
        token);
    expect(
        accountAccessTokenFromUri(Uri.parse('/account/activate?token=$token')),
        token);
    expect(
        accountAccessTokenFromUri(Uri.parse('/account/activate#token=short')),
        isNull);
    expect(accountAccessTokenFromUri(Uri.parse('/account/activate#token=%FF')),
        isNull);
    expect(accountAccessTokenFromUri(Uri.parse('/account/activate')), isNull);
  });
  test('password rules match account-access validation', () {
    expect(accountPasswordValidation('StrongPassword!123'), isNull);
    for (final value in [
      'short',
      'alllowercasepassword',
      'ALLUPPERCASE123!',
      'NoSpecialChar123',
      'MissingNumbers!'
    ]) {
      expect(accountPasswordValidation(value), isNotNull);
    }
  });
  testWidgets(
      'recovery validates email and does not duplicate an in-flight request',
      (tester) async {
    var sends = 0;
    final pending = Completer<String>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          passwordRecoverySenderProvider.overrideWithValue((email) {
            sends++;
            return pending.future;
          })
        ],
        child:
            const MaterialApp(home: Scaffold(body: PasswordRecoveryDialog()))));
    await tester.tap(find.text('Gửi hướng dẫn'));
    await tester.pump();
    expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
    expect(sends, 0);
    await tester.enterText(find.byType(TextFormField), 'tenant@example.test');
    await tester.tap(find.text('Gửi hướng dẫn'));
    await tester.pump();
    expect(sends, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    pending.complete('Nếu tài khoản hợp lệ, hướng dẫn sẽ được gửi.');
    await tester.pumpAndSettle();
    expect(find.text('Gửi lại sau 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Gửi hướng dẫn'), findsOneWidget);
    expect(sends, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
