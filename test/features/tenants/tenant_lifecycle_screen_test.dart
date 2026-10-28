import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/tenants/tenant_lifecycle_api.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/tenants/tenant_lifecycle_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/tenant_portal.dart';

final _identity = StateProvider<String?>((ref) => 'tenant-user');

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
      user: LandlordUser(
          id: 'tenant-user',
          fullName: 'Tenant',
          email: 'tenant@example.test',
          role: 'tenant'),
      accessToken: 'access',
      refreshToken: 'refresh'));
}

class _Api extends TenantLifecycleApi {
  _Api() : super(Dio(), ownerId: 'tenant-user');
  bool failRead = false, failCancel = false;
  int cancels = 0;
  @override
  Future<LifecyclePage> requests(
      {required bool tenant,
      required String leaseId,
      String? status,
      String? cursor}) async {
    if (failRead)
      throw const ApiFailure(message: 'Network unavailable', statusCode: 503);
    return LifecyclePage([
      {
        'id': 'request',
        'type': 'RENEWAL',
        'status': 'PENDING',
        'note': 'Keep this request visible',
        'updatedAt': '2026-10-27T00:00:00Z'
      }
    ], null);
  }

  @override
  Future<List<Map<String, dynamic>>> occupants(String leaseId,
          {required bool tenant}) async =>
      [];
  @override
  Future<Map<String, dynamic>?> settlement(String leaseId) async => null;
  @override
  Future<void> cancel(Map<String, dynamic> request) async {
    cancels++;
    if (failCancel) throw const ApiFailure(message: 'Unknown result');
  }
}

const _lease = TenantPortalLease(
    id: 'lease',
    roomId: 'room',
    roomName: 'A101',
    propertyId: 'property',
    propertyName: 'Property',
    monthlyRent: 3500000);
Future<ProviderContainer> _mount(WidgetTester tester, _Api api) async {
  final container = ProviderContainer(overrides: [
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
    sessionControllerProvider.overrideWith(_Session.new),
    tenantLifecycleApiProvider.overrideWithValue(api),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
          home: TenantLifecycleScreen(leaseId: 'lease', tenantLease: _lease))));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('tenant sees cancellation but never landlord review controls',
      (tester) async {
    await _mount(tester, _Api());
    expect(find.text('Hủy yêu cầu'), findsOneWidget);
    expect(find.text('Duyệt'), findsNothing);
    expect(find.text('Từ chối'), findsNothing);
    expect(find.text('Gửi yêu cầu mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keeps loaded requests when a refresh fails', (tester) async {
    final api = _Api();
    await _mount(tester, api);
    api.failRead = true;
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Keep this request visible'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('uncertain cancellation does not automatically replay',
      (tester) async {
    final api = _Api()..failCancel = true;
    await _mount(tester, api);
    await tester.tap(find.text('Hủy yêu cầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.cancels, 1);
    expect(
        find.textContaining('Chưa xác định kết quả thao tác'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Hủy yêu cầu'))
            .onPressed,
        isNull);
  });
  testWidgets('account change hides the previous tenants data', (tester) async {
    final container = await _mount(tester, _Api());
    container.read(_identity.notifier).state = 'other-user';
    await tester.pumpAndSettle();
    expect(find.textContaining('Keep this request visible'), findsNothing);
    expect(find.textContaining('Phiên tài khoản đã thay đổi'), findsOneWidget);
  });
  testWidgets('request form validates dates and reasons before submission',
      (tester) async {
    await _mount(tester, _Api());
    await tester.tap(find.text('Gửi yêu cầu mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập ngày hợp lệ theo YYYY-MM-DD.'), findsOneWidget);
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
