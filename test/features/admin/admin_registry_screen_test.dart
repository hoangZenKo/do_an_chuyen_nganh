import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_registry_screen.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

void main() {
  for (final section in AdminRegistrySection.values) {
    testWidgets('$section fits 320px at 200% text', (tester) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionIdentityProvider.overrideWithValue('operator'),
            adminCapabilitiesProvider
                .overrideWith((_) async => const AdminCapabilities([
                      'admin.verifications.view',
                      'admin.verifications.manage',
                      'admin.support.read',
                      'admin.properties.view',
                      'admin.properties.manage',
                      'admin.plans.view',
                      'admin.plans.manage',
                    ])),
            adminResourceProvider.overrideWith((ref, request) async => {
                  'data': [
                    {
                      'id': '11111111-1111-4111-8111-111111111111',
                      'landlordId': '22222222-2222-4222-8222-222222222222',
                      'propertyId': '33333333-3333-4333-8333-333333333333',
                      'ticketId': '44444444-4444-4444-8444-444444444444',
                      'version': 1,
                      'status': 'PENDING',
                      'name': 'Premium',
                      'code': 'PREMIUM',
                      'isActive': true,
                      'maxProperties': 20,
                      'maxRooms': 100,
                      'price': 100000,
                    }
                  ],
                  'meta': {'page': 1, 'limit': 20, 'total': 1}
                }),
          ],
          child: MaterialApp(
              home: AdminRegistryScreen(section: section),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('owner verification status does not request admin capabilities',
      (tester) async {
    var capabilityReads = 0;
    final requests = <String>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionIdentityProvider.overrideWithValue('owner'),
          adminCapabilitiesProvider.overrideWith((_) async {
            capabilityReads++;
            throw StateError('not admin');
          }),
          adminResourceProvider.overrideWith((ref, request) async {
            requests.add(request.path);
            return {
              'data': {
                'status': 'NEEDS_INFO',
                'version': 2,
                'ticketId': 'ticket'
              }
            };
          }),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: LandlordVerificationPanel())))));
    await tester.pumpAndSettle();
    expect(capabilityReads, 0);
    expect(requests, ['/landlord-verification']);
    expect(find.textContaining('Cần bổ sung'), findsOneWidget);
  });
  testWidgets('verification requires both verification and support access',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionIdentityProvider.overrideWithValue('operator'),
          adminCapabilitiesProvider.overrideWith((_) async =>
              const AdminCapabilities(['admin.verifications.view'])),
          adminResourceProvider.overrideWith((ref, request) async {
            reads++;
            return {'data': []};
          }),
        ],
        child: const MaterialApp(
            home: AdminRegistryScreen(
                section: AdminRegistrySection.verifications))));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.textContaining('không có quyền'), findsWidgets);
  });

  testWidgets(
      'plans show nonfinancial terms without write controls for viewers',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionIdentityProvider.overrideWithValue('operator'),
          adminCapabilitiesProvider.overrideWith(
              (_) async => const AdminCapabilities(['admin.plans.view'])),
          adminResourceProvider.overrideWith((ref, request) async => {
                'data': [
                  {
                    'id': 'plan',
                    'code': 'PRO',
                    'name': 'Pro',
                    'price': 100000,
                    'version': 1,
                    'maxProperties': 5,
                    'maxRooms': 50,
                    'isActive': true
                  },
                ],
                'meta': {'page': 1, 'limit': 20, 'total': 1}
              }),
        ],
        child: const MaterialApp(
            home: AdminRegistryScreen(section: AdminRegistrySection.plans))));
    await tester.pumpAndSettle();
    expect(find.text('Pro'), findsOneWidget);
    expect(find.textContaining('không ghi nhận doanh thu'), findsOneWidget);
    expect(find.text('Tạo gói dịch vụ'), findsNothing);
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
