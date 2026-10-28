import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/settings/settings_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';

class _Session extends SessionController {
  _Session(this.role);

  final String role;
  bool loggedOut = false;

  @override
  SessionState build() => SessionState.authenticated(AuthSession(
        user: LandlordUser(
          id: 'settings-test',
          fullName: 'Nguyễn Hoàng Minh',
          email: 'landlord@example.test',
          phone: '+84901234567',
          role: role,
        ),
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
      ));

  @override
  Future<void> logout() async => loggedOut = true;
}

Future<_Session> _mount(WidgetTester tester, {String role = 'landlord'}) async {
  final session = _Session(role);
  final router = GoRouter(initialLocation: settingsRoute, routes: [
    GoRoute(path: settingsRoute, builder: (_, __) => const SettingsScreen()),
    for (final route in [settingsPasswordRoute, propertiesRoute, staffRoute])
      GoRoute(
          path: route,
          builder: (_, __) => Scaffold(body: Text('Destination: $route'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [sessionControllerProvider.overrideWith(() => session)],
    child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return session;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  testWidgets('landlord settings use a coherent light palette under dark app',
      (tester) async {
    await _mount(tester);
    final context = tester.element(find.text('Cài đặt'));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.light);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFFF3F5F8));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFF3F5F8));
    expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onSurface);
    for (final label in ['Nguyễn Hoàng Minh', 'Thông tin cá nhân']) {
      expect(_textColor(tester, label), theme.colorScheme.onSurface);
      expect(_contrast(_textColor(tester, label)!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
    }
    expect(_textColor(tester, 'landlord@example.test'),
        theme.colorScheme.onSurfaceVariant);
    expect(
        _contrast(
            theme.colorScheme.onSurfaceVariant, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5));
    expect(_textColor(tester, 'Đăng xuất'), theme.colorScheme.error);
    final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline_rounded));
    expect(icon.color, theme.colorScheme.onSurface);
    for (final divider in tester.widgetList<Divider>(find.byType(Divider))) {
      expect(divider.color, theme.colorScheme.outlineVariant);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile sheet keeps the settings surface and readable text',
      (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, Colors.white);
    final context = tester.element(find.text('Họ tên'));
    final scheme = Theme.of(context).colorScheme;
    expect(Theme.of(context).brightness, Brightness.light);
    expect(_textColor(tester, 'Họ tên'), scheme.onSurfaceVariant);
    final values = tester.widgetList<Text>(find.text('Nguyễn Hoàng Minh'));
    expect(values.last.style?.color, scheme.onSurface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language sheet has light selection colors and still closes',
      (tester) async {
    await _mount(tester);
    await tester.scrollUntilVisible(find.text('Ngôn ngữ'), 350);
    await tester.tap(find.text('Ngôn ngữ'));
    await tester.pumpAndSettle();
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        Colors.white);
    final selected = find.byIcon(Icons.check_circle_rounded);
    final scheme = Theme.of(tester.element(selected)).colorScheme;
    expect(tester.widget<Icon>(selected).color, scheme.onPrimaryContainer);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.textColor, scheme.onSurface);
    await tester.tap(find.text('Ngôn ngữ mặc định của ứng dụng'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final route in [
    (title: 'Đổi mật khẩu', destination: settingsPasswordRoute),
    (title: 'Nhà trọ của tôi', destination: propertiesRoute),
    (title: 'Nhân viên & phân quyền', destination: staffRoute),
  ]) {
    testWidgets('${route.title} keeps its navigation', (tester) async {
      await _mount(tester);
      await tester.scrollUntilVisible(find.text(route.title), 250);
      await tester.ensureVisible(find.text(route.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(route.title));
      await tester.pumpAndSettle();
      expect(find.text('Destination: ${route.destination}'), findsOneWidget);
    });
  }

  testWidgets('logout still calls the session controller', (tester) async {
    final session = await _mount(tester);
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 200);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(session.loggedOut, isTrue);
  });

  testWidgets('staff without management permission keeps restricted entries',
      (tester) async {
    await _mount(tester, role: 'staff');
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Nhà trọ của tôi'), findsNothing);
    expect(find.text('Nhân viên & phân quyền'), findsNothing);
    expect(find.text('Chủ trọ'), findsNothing);
  });

  testWidgets('small phone and large text fit including both sheets',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _mount(tester);
    await tester.scrollUntilVisible(find.text('Thông tin cá nhân'), 200);
    await tester.tap(find.text('Thông tin cá nhân'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('Họ tên'))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ngôn ngữ'), 250);
    await tester.tap(find.text('Ngôn ngữ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
