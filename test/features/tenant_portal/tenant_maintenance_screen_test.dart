import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/tenant_portal/tenant_portal_api.dart';
import 'package:rental_room_management/data/tenant_portal/tenant_portal_repository.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_maintenance_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/models/maintenance.dart';
import 'package:rental_room_management/data/uploads/upload_api.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';

final _identity = StateProvider<String>((_) => 'tenant-qa');

class _Picker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      FilePickerResult(
          [PlatformFile(name: 'qa.png', size: 10, path: '/tmp/qa.png')]);
}

class _Uploads extends UploadApi {
  _Uploads() : super(Dio());
  Completer<String>? pending;
  @override
  Future<String> uploadFile(String path, {bool publicListing = false}) async =>
      pending == null ? '/uploads/qa.png' : await pending!.future;
}

const _title = 'DEMO - Vòi nước phòng A101 bị rò';
const _description =
    'Yêu cầu thử nghiệm luồng sửa chữa, không phải sự cố thật.';
const _ticket = MaintenanceTicket(
  id: 'ticket-1',
  propertyId: 'property-1',
  roomId: 'room-1',
  status: MaintenanceStatus.open,
  priority: MaintenancePriority.medium,
  title: _title,
  description: _description,
);

class _Repository extends TenantPortalRepository {
  _Repository() : super(TenantPortalApi(Dio()));

  List<MaintenanceTicket> tickets = [];
  final submissions = <Map<String, Object?>>[];
  Completer<MaintenanceTicket>? pendingSubmission;
  bool failSubmission = false;

  @override
  Future<List<MaintenanceTicket>> maintenance() async => tickets;

  @override
  Future<MaintenanceTicket> createMaintenance({
    required String title,
    String? description,
    MaintenancePriority priority = MaintenancePriority.medium,
    List<String> imageUrls = const [],
  }) async {
    submissions.add({
      'title': title,
      'description': description,
      'priority': priority,
      'imageUrls': imageUrls,
    });
    if (failSubmission) throw Exception('Không gửi được yêu cầu thử nghiệm');
    final ticket = await (pendingSubmission?.future ?? Future.value(_ticket));
    tickets = [ticket];
    return ticket;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository,
    {_Uploads? uploads}) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      tenantPortalRepositoryProvider.overrideWithValue(repository),
      uploadApiProvider.overrideWithValue(uploads ?? _Uploads()),
      sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
    ],
    child: const MaterialApp(home: TenantMaintenanceScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Tiêu đề'), _title);
  await tester.enterText(find.widgetWithText(TextField, 'Mô tả'), _description);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cannot submit while attachment is still uploading',
      (tester) async {
    FilePicker.platform = _Picker();
    final pending = Completer<String>();
    final repository = _Repository();
    await _mount(tester, repository, uploads: _Uploads()..pending = pending);
    await _openForm(tester);
    await tester.ensureVisible(find.text('Upload ảnh/file'));
    await tester.tap(find.text('Upload ảnh/file'));
    await tester.pump();
    await tester.ensureVisible(find.text('Gửi yêu cầu'));
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
              of: find.text('Gửi yêu cầu'),
              matching:
                  find.byWidgetPredicate((widget) => widget is FilledButton),
            ))
            .onPressed,
        isNull);
    pending.complete('/uploads/qa.png');
    await tester.pumpAndSettle();
    await _tap(tester, 'Gửi yêu cầu');
    expect((repository.submissions.single['imageUrls'] as List).length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late success cannot pop a newly opened form', (tester) async {
    final pending = Completer<MaintenanceTicket>();
    await _mount(tester, _Repository()..pendingSubmission = pending);
    await _openForm(tester);
    await tester.ensureVisible(find.text('Gửi yêu cầu'));
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(TextField).first)).pop();
    await tester.pump(const Duration(milliseconds: 20));
    Navigator.of(tester.element(find.byType(TenantMaintenanceScreen))).push(
        MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('New page stays open'))));
    pending.complete(_ticket);
    await tester.pumpAndSettle();
    expect(find.text('New page stays open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('removed uploaded attachment is not silently submitted again',
      (tester) async {
    FilePicker.platform = _Picker();
    final repository = _Repository();
    await _mount(tester, repository);
    await _openForm(tester);
    await _tap(tester, 'Upload ảnh/file');
    expect(find.byType(Chip), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();
    await _tap(tester, 'Gửi yêu cầu');
    expect(repository.submissions.single['imageUrls'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open form cannot submit old tenant data after account switches',
      (tester) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _openForm(tester);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(TenantMaintenanceScreen)));
    container.read(_identity.notifier).state = 'another-tenant';
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(find.text('Gửi yêu cầu'), findsNothing);
    container.read(_identity.notifier).state = 'tenant-qa';
    await tester.pumpAndSettle();
    expect(find.text('Gửi yêu cầu'), findsNothing);
    expect(repository.submissions, isEmpty);
  });
  testWidgets(
      'cancel focused incident form safely and reopen with empty fields',
      (tester) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _openForm(tester);
    await _tap(tester, 'Hủy');
    expect(tester.takeException(), isNull);
    expect(repository.submissions, isEmpty);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submit incident without attachment and refresh ticket list',
      (tester) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _openForm(tester);
    await _tap(tester, 'Gửi yêu cầu');
    expect(tester.takeException(), isNull);
    expect(find.text('Báo sự cố bảo trì'), findsNothing);
    expect(find.text(_title), findsOneWidget);
    expect(repository.submissions.single, {
      'title': _title,
      'description': _description,
      'priority': MaintenancePriority.medium,
      'imageUrls': <String>[],
    });
  });

  testWidgets('failed submission keeps form available for retry',
      (tester) async {
    final repository = _Repository()..failSubmission = true;
    await _mount(tester, repository);
    await _openForm(tester);
    await _tap(tester, 'Gửi yêu cầu');
    expect(find.textContaining('Không gửi được yêu cầu thử nghiệm'),
        findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    repository.failSubmission = false;
    await _tap(tester, 'Gửi yêu cầu');
    expect(find.text('Báo sự cố bảo trì'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismiss form while request pending without late UI updates',
      (tester) async {
    final pending = Completer<MaintenanceTicket>();
    final repository = _Repository()..pendingSubmission = pending;
    await _mount(tester, repository);
    await _openForm(tester);
    await tester.ensureVisible(find.text('Gửi yêu cầu'));
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(TextField).first)).pop();
    await tester.pumpAndSettle();
    pending.complete(_ticket);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Báo sự cố bảo trì'), findsNothing);
  });

  testWidgets('close focused ticket reply sheet safely', (tester) async {
    await _mount(tester, _Repository()..tickets = [_ticket]);
    await _tap(tester, _title);
    await tester.enterText(find.byType(TextField), 'Phản hồi thử nghiệm');
    await _tap(tester, 'Đóng');
    expect(tester.takeException(), isNull);
  });
}
