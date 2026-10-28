import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_overview_theme.dart';
import 'package:rental_room_management/features/admin/admin_permissions_editor.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

final _identity = StateProvider<String?>((ref) => 'root');
final _rights = StateProvider<List<String>>(
    (ref) => ['admin.admins.manage', ..._permissions]);
const _permissions = [
  'admin.dashboard.view',
  'admin.support.read',
  'admin.plans.view',
  'admin.plans.manage',
  'admin.verifications.view',
];
const _preset = ['admin.dashboard.view', 'admin.support.read'];
Map<String, dynamic> _access({bool editable = true, int version = 4}) => {
      'data': {
        'id': 'target',
        'preset': 'support',
        'permissions': _preset,
        'presetPermissions': _preset,
        'delegablePermissions': _permissions,
        'version': version,
        'isActive': true,
        'canCustomizePermissions': editable,
      }
    };

Future<ProviderContainer> _pump(WidgetTester tester,
    {bool editable = true,
    List<Map<String, dynamic>>? results,
    Future<Map<String, dynamic>> Function()? load,
    Size size = const Size(1200, 1000),
    double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
    adminCapabilitiesProvider
        .overrideWith((ref) async => AdminCapabilities(ref.watch(_rights))),
    adminResourceProvider.overrideWith((ref, request) async {
      if (request.path == '/admin/permission-catalog') {
        return {
          'data': {
            'permissions': _permissions,
            'presets': {
              'support': _preset,
              'analyst': ['admin.dashboard.view', 'admin.plans.view'],
              'moderator': _preset,
              'super_admin': _permissions,
            },
          }
        };
      }
      return load != null ? load() : _access(editable: editable);
    }),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AdminOverviewTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => const AdminPermissionsEditor(
                      userId: 'target', fullName: 'Nhân sự hỗ trợ'));
              if (result != null) results?.add(result);
            },
            child: const Text('Mở quyền'),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mở quyền'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _submit(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.ensureVisible(fields.first);
  await tester.enterText(fields.first, '123456');
  await tester.ensureVisible(fields.last);
  await tester.enterText(fields.last, 'Cấp quyền theo yêu cầu đã được duyệt');
  await tester.tap(find.text('Lưu thay đổi'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows stored grants and returns an explicit versioned command',
      (tester) async {
    final results = <Map<String, dynamic>>[];
    await _pump(tester, results: results);
    expect(find.text('Quyền hiệu lực: 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grant:admin.plans.view')));
    await tester.pump();
    expect(find.text('So với vai trò: thêm 1, bỏ 0 quyền.'), findsOneWidget);
    await _submit(tester);
    expect(results.single, containsPair('version', 4));
    expect(results.single['permissions'], [..._preset, 'admin.plans.view']);
    expect(results.single['preset'], 'support');
    expect(results.single['isActive'], true);
  });

  testWidgets('requires reason and MFA, keeps dashboard grant mandatory',
      (tester) async {
    final results = <Map<String, dynamic>>[];
    await _pump(tester, results: results);
    final dashboard = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('grant:admin.dashboard.view')));
    expect(dashboard.onChanged, isNull);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();
    expect(results, isEmpty);
    expect(find.text('Nhập mã MFA hợp lệ.'), findsOneWidget);
    expect(find.text('Nhập lý do ít nhất 10 ký tự.'), findsOneWidget);
  });

  testWidgets('preset-only operators cannot submit an explicit grant list',
      (tester) async {
    final results = <Map<String, dynamic>>[];
    await _pump(tester, editable: false, results: results);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('grant:admin.plans.view')))
            .onChanged,
        isNull);
    await _submit(tester);
    expect(results.single.containsKey('permissions'), false);
  });

  for (final permissionLoss in [false, true]) {
    testWidgets(
        'blocks an open editor after ${permissionLoss ? 'permission loss' : 'account switch'}',
        (tester) async {
      final results = <Map<String, dynamic>>[];
      final container = await _pump(tester, results: results);
      if (permissionLoss) {
        container.read(_rights.notifier).state = [];
      } else {
        container.read(_identity.notifier).state = 'other-admin';
      }
      await tester.pumpAndSettle();
      expect(find.text('Không thể chỉnh sửa quyền'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsNothing);
      expect(results, isEmpty);
    });
  }

  testWidgets('does not rebase an old draft on a newly fetched version',
      (tester) async {
    var version = 4;
    final results = <Map<String, dynamic>>[];
    final container = await _pump(tester,
        results: results, load: () async => _access(version: version));
    version = 5;
    container.invalidate(adminResourceProvider(
        const AdminRequest('/admin/admins/target/access')));
    await tester.pumpAndSettle();
    expect(find.text('Tải bản mới'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(results, isEmpty);
    await tester.ensureVisible(find.text('Tải bản mới'));
    await tester.tap(find.text('Tải bản mới'));
    await tester.pumpAndSettle();
    await _submit(tester);
    expect(results.single['version'], 5);
  });

  testWidgets('read errors have retry but never enable saving', (tester) async {
    var failures = true;
    await _pump(tester, load: () async {
      if (failures) throw StateError('network unavailable');
      return _access();
    });
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    failures = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Quyền hiệu lực: 2'), findsOneWidget);
  });

  testWidgets('320px large-text layout scrolls without overflow',
      (tester) async {
    await _pump(tester, size: const Size(320, 760), scale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byType(TextFormField).last);
    expect(tester.takeException(), isNull);
  });
}
