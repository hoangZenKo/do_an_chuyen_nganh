import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_access_review_panel.dart';
import 'package:rental_room_management/features/admin/admin_case_timeline_dialog.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_landlord_detail_screen.dart';
import 'package:rental_room_management/features/admin/admin_production_panels.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_sla_policy_screen.dart';
import 'package:rental_room_management/features/admin/admin_overview_shell.dart';
import 'package:rental_room_management/features/admin/admin_step_up.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

const _permissions = [
  'admin.dashboard.view',
  'admin.admins.manage',
  'admin.support.read',
  'admin.support.manage',
  'admin.properties.view',
  'admin.finance.read',
  'admin.operations.view',
  'admin.operations.manage',
];
final _currentPermissions = StateProvider<List<String>>((ref) => _permissions);
final _currentOwner = StateProvider<String?>((ref) => 'admin-1');

class _RecordingApi extends AdminApi {
  _RecordingApi() : super(Dio());
  String? commandPath;
  Map<String, dynamic>? payload;
  bool? patched;

  @override
  Future<Map<String, dynamic>> authorizedCommand(
      String path, Map<String, dynamic> data,
      {bool patch = false, required AdminStepUpPrompt prompt}) async {
    commandPath = path;
    payload = data;
    patched = patch;
    return {
      'data': {'id': 'owner-1', 'isActive': false, 'updated': true}
    };
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, Widget child,
    {Map<String, dynamic> response = const {'data': []},
    List<String> permissions = _permissions,
    Size size = const Size(1200, 1000),
    _RecordingApi? api,
    AdminLandlordDetail? landlord,
    List<AdminRequest>? requests}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(overrides: [
    _currentPermissions.overrideWith((ref) => permissions),
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_currentOwner)),
    adminCapabilitiesProvider.overrideWith(
        (ref) async => AdminCapabilities(ref.watch(_currentPermissions))),
    if (api != null) adminApiProvider.overrideWithValue(api),
    if (landlord != null)
      adminLandlordDetailProvider(landlord.id)
          .overrideWith((ref) async => landlord),
    adminResourceProvider.overrideWith((ref, request) async {
      requests?.add(request);
      return response;
    }),
    adminWorkspaceResourceProvider.overrideWith((ref, request) async {
      requests?.add(request);
      if (request.path == '/admin/operations/incidents') {
        final data = response['data'];
        final incidents = data is Map ? data['incidents'] as List? ?? [] : [];
        return {
          'data': incidents,
          'meta': {'total': incidents.length, 'pages': 1},
        };
      }
      return response;
    }),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: child is AdminSlaPolicyScreen ||
                  child is AdminLandlordDetailScreen ||
                  child is Scaffold
              ? child
              : Scaffold(body: SingleChildScrollView(child: child)))));
  await tester.pumpAndSettle();
  return container;
}

Widget _dialogLauncher(Widget dialog) => Scaffold(
    body: Builder(
        builder: (context) => TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('Open'))));

const _case = {
  'requester': {'fullName': 'Requester One', 'role': 'LANDLORD'},
  'links': [
    {
      'kind': 'PROPERTY',
      'targetId': 'property-1',
      'resource': {'name': 'Linked property'}
    },
    {
      'kind': 'INVOICE',
      'targetId': 'invoice-private',
      'resource': {'status': 'UNPAID', 'totalAmount': 7654321, 'paidAmount': 0}
    },
  ],
  'activity': [],
  'escalations': [],
  'relatedTickets': [],
};

const _sla = {
  'data': {
    'version': 3,
    'enabled': true,
    'timezone': 'Asia/Ho_Chi_Minh',
    'weekdays': [1, 2, 3, 4, 5],
    'startMinute': 540,
    'endMinute': 1020,
    'holidays': [],
    'pauseWaiting': true,
    'responseMinutes': {'LOW': 120, 'NORMAL': 60, 'HIGH': 30, 'URGENT': 15},
    'resolutionMinutes': {'LOW': 480, 'NORMAL': 240, 'HIGH': 120, 'URGENT': 60},
    'escalationMinutes': [0, 60, 120],
  }
};

void main() {
  testWidgets('MFA dialog validates input and suppresses results after logout',
      (tester) async {
    String? result;
    var active = true;
    await _pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await promptAdminStepUp(context, () => active);
                },
                child: const Text('Verify'))),
        size: const Size(390, 844));
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác thực'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập mã xác thực hợp lệ.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '654321');
    active = false;
    await tester.tap(find.text('Xác thực'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled MFA dialog does not return a code', (tester) async {
    String? result = 'not-cancelled';
    await _pump(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  result = await promptAdminStepUp(context, () => true);
                },
                child: const Text('Verify'))));
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets(
      'timeline removes financial resources immediately after revocation',
      (tester) async {
    final container = await _pump(
        tester,
        _dialogLauncher(
            const AdminCaseTimelineDialog(data: _case, owner: 'admin-1')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('7654321'), findsOneWidget);
    container.read(_currentPermissions.notifier).state = _permissions
        .where((permission) => permission != 'admin.finance.read')
        .toList();
    await tester.pumpAndSettle();
    expect(find.textContaining('7654321'), findsNothing);
    expect(find.textContaining('invoice-private'), findsNothing);
    expect(find.textContaining('Linked property'), findsOneWidget);
    container.read(_currentOwner.notifier).state = 'another-admin';
    await tester.pumpAndSettle();
    expect(find.text('Quyền truy cập đã thay đổi'), findsOneWidget);
    expect(find.textContaining('Requester One'), findsNothing);
    expect(find.textContaining('Linked property'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access review hides self-approval and binds the target version',
      (tester) async {
    final api = _RecordingApi();
    await _pump(tester, const AdminAccessReviewPanel(), api: api, response: {
      'data': [
        for (final id in ['admin-1', 'admin-2'])
          {
            'id': id,
            'fullName': id,
            'email': 'a***@example.test',
            'isActive': true,
            'adminProfile': {
              'reviewVersion': 7,
              'mfaEnabled': true,
              'permissions': ['admin.support.read']
            }
          }
      ],
      'meta': {'total': 2}
    });
    await tester.tap(find.text('Rà soát quyền admin'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi nhận rà soát'), findsOneWidget);
    await tester.tap(find.text('Ghi nhận rà soát'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lý do (ghi vào audit)'),
        'Reviewed permissions with team lead');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commandPath, '/admin/access-reviews/admin-2');
    expect(api.payload?['version'], 7);
    expect(api.payload?['nextReviewAt'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restricted access review never fetches privileged data',
      (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, const AdminAccessReviewPanel(),
        permissions: const ['admin.dashboard.view'], requests: requests);
    expect(find.text('Rà soát quyền admin'), findsNothing);
    expect(requests, isEmpty);
  });

  testWidgets(
      'legacy landlord status collects a reason and submits its version',
      (tester) async {
    final api = _RecordingApi();
    await _pump(tester, const AdminLandlordDetailScreen(landlordId: 'owner-1'),
        api: api,
        permissions: const [
          ..._permissions,
          'admin.accounts.manage',
          'admin.accounts.suspend'
        ],
        landlord: const AdminLandlordDetail(
            id: 'owner-1',
            fullName: 'Owner',
            email: 'o***@example.test',
            phone: null,
            isActive: true,
            propertyCount: 0,
            roomCount: 0,
            occupiedCount: 0,
            tenantCount: 0,
            activeLeaseCount: 0,
            recentProperties: [],
            version: 8));
    await tester.tap(find.text('Khóa tài khoản'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(ElevatedButton, 'Khóa tài khoản');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Nhập lý do tối thiểu 10 ký tự.'), findsOneWidget);
    expect(api.commandPath, isNull);
    await tester.enterText(
        find.byType(TextFormField), 'Suspend while reviewing abuse evidence');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(api.commandPath, '/admin/landlords/owner-1/status');
    expect(api.patched, true);
    expect(api.payload, {
      'isActive': false,
      'reason': 'Suspend while reviewing abuse evidence',
      'version': 8,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('SLA policy is readable on phone and saves typed versioned data',
      (tester) async {
    final api = _RecordingApi();
    await _pump(tester, const AdminSlaPolicyScreen(),
        api: api, response: _sla, size: const Size(390, 844));
    expect(find.byType(AdminOverviewShell), findsOneWidget);
    expect(find.textContaining('Ticket cũ giữ nguyên'), findsOneWidget);
    await tester.ensureVisible(find.text('Cấu hình SLA'));
    await tester.tap(find.text('Cấu hình SLA'));
    await tester.pumpAndSettle();
    final reasonField =
        find.widgetWithText(TextFormField, 'Lý do (ghi vào audit)');
    await tester.ensureVisible(reasonField);
    await tester.enterText(reasonField, 'Approved support business calendar');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commandPath, '/admin/support-sla-policy');
    expect(api.patched, true);
    expect(api.payload?['version'], 3);
    expect(api.payload?['weekdays'], [1, 2, 3, 4, 5]);
    expect(api.payload?['startMinute'], 540);
    expect(api.payload?['pauseWaiting'], true);
    expect((api.payload?['responseMinutes'] as Map)['URGENT'], 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restricted SLA screen never fetches the policy', (tester) async {
    final requests = <AdminRequest>[];
    await _pump(tester, const AdminSlaPolicyScreen(),
        permissions: const ['admin.support.read', 'admin.support.manage'],
        requests: requests);
    expect(find.text('Không còn quyền cấu hình SLA.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('incident snooze submits a reason, version and bounded expiry',
      (tester) async {
    final api = _RecordingApi();
    await _pump(tester, const AdminOperationsPanel(), api: api, response: {
      'data': {
        'database': 'ok',
        'incidents': [
          {
            'id': 'incident-1',
            'title': 'Queue backlog',
            'status': 'OPEN',
            'severity': 'WARNING',
            'version': 4,
            'occurrences': 2,
            'conditionActive': true,
          }
        ],
      }
    });
    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạm hoãn 4 giờ'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lý do (tối thiểu 10 ký tự)'),
        'Provider outage under investigation');
    final before = DateTime.now().toUtc();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(api.commandPath, '/admin/operations/incidents/incident-1/actions');
    expect(api.payload?['action'], 'SNOOZE');
    expect(api.payload?['version'], 4);
    final until = DateTime.parse(api.payload!['snoozedUntil'] as String);
    expect(until.difference(before).inMinutes, inInclusiveRange(239, 240));
    expect(tester.takeException(), isNull);
  });
}
