import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
            id: 'owner', fullName: 'Owner', email: 'qa@test.local'),
        accessToken: 'test',
        refreshToken: 'test',
      ));
}

class _Repository extends MaintenanceRepository {
  _Repository() : super(MaintenanceApi(Dio()));
  var status = MaintenanceStatus.open;
  int completions = 0;
  bool fail = false;
  MaintenanceTicket get ticket => MaintenanceTicket(
        id: 'ticket',
        propertyId: 'property',
        roomId: 'room',
        title: 'QA repair',
        status: status,
        priority: MaintenancePriority.medium,
        imageUrls: const ['/uploads/qa.png'],
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
              actualCost: 0));
  @override
  Future<MaintenanceTicket> complete(String id,
      {int? actualCost,
      String? note,
      bool createExpense = true,
      String? completedAt}) async {
    completions++;
    if (fail) throw Exception('QA completion failed');
    status = MaintenanceStatus.done;
    return ticket;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: [
    sessionControllerProvider.overrideWith(_Session.new),
    maintenanceRepositoryProvider.overrideWithValue(repository),
    selectedPropertyProvider.overrideWith((_) => null),
  ], child: const MaterialApp(home: MaintenanceScreen())));
  await tester.pumpAndSettle();
}

Future<void> _openComplete(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hoàn tất'));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.widgetWithText(TextField, 'Chi phí thực tế'), '10000');
}

void main() {
  for (final cancel in [true, false]) {
    testWidgets('focused completion closes safely, cancel=$cancel',
        (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await _openComplete(tester);
      await tester.tap(find.widgetWithText(
          cancel ? TextButton : ElevatedButton, cancel ? 'Hủy' : 'Hoàn tất'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repository.completions, cancel ? 0 : 1);
    });
  }
  testWidgets('failed completion preserves fields for retry', (tester) async {
    final repository = _Repository()..fail = true;
    await _mount(tester, repository);
    await _openComplete(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hoàn tất'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
    expect(find.textContaining('QA completion failed'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hoàn tất'));
    await tester.pumpAndSettle();
    expect(repository.completions, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelled repair cannot be completed from menu', (tester) async {
    await _mount(tester, _Repository()..status = MaintenanceStatus.cancelled);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn tất'), findsNothing);
  });
  testWidgets('landlord can find tenant attachments', (tester) async {
    await _mount(tester, _Repository());
    expect(find.text('File 1'), findsOneWidget);
  });
}
