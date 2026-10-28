import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/admin/admin_bulk_preview_dialog.dart';
import 'package:rental_room_management/features/admin/admin_inbox_filters.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/admin_workspace_models.dart';

final _owner = StateProvider<String?>((ref) => 'admin-1');
final _permissions = StateProvider<List<String>>((ref) =>
    ['admin.moderation.bulk', 'admin.listings.moderate']);

void main() {
  test('inbox deep links only accept known filters and bounded search', () {
    expect(adminInboxFilters({
      'status': 'OPEN',
      'assignment': 'mine',
      'sla': 'overdue',
      'search': ' queue ',
      'redirect': 'https://example.test',
      'page': '99999999',
    }, incidents: true), {
      'status': 'OPEN', 'assignment': 'mine', 'search': 'queue',
    });
    expect(adminInboxFilters({
      'status': 'invalid',
      'priority': 'not-a-priority',
      'sla': 'due_soon',
      'sort': 'resolution_due',
      'teamId': 'not-a-uuid',
      'search': 'x' * 101,
    }, incidents: false), {'sla': 'due_soon', 'sort': 'resolution_due'});
  });

  test('workspace actions cannot leave their canonical route', () {
    AdminWorkspaceItem item(String path) => AdminWorkspaceItem.fromJson({
      'key': 'support_overdue', 'label': 'Support',
      'route': '/admin/support-center', 'actionPath': path,
      'status': 'OK', 'pendingCount': 1,
    });
    expect(item('/admin/support-center?sla=overdue').destination,
        '/admin/support-center?sla=overdue');
    for (final path in [
      'https://example.test/admin/support-center',
      '//example.test/admin/support-center',
      '/admin/finance-reconciliation',
      '/admin/support-center#private',
    ]) {
      expect(item(path).destination, '/admin/support-center');
    }
  });

  Future<ProviderContainer> pumpPreview(WidgetTester tester,
      {bool blocked = false}) async {
    final container = ProviderContainer(overrides: [
      sessionIdentityProvider.overrideWith((ref) => ref.watch(_owner)),
      adminCapabilitiesProvider.overrideWith((ref) async =>
          AdminCapabilities(ref.watch(_permissions))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: AdminBulkPreviewDialog(
          owner: 'admin-1', permission: 'admin.listings.moderate',
          preview: {
            'data': [{
              'id': 'listing-1', 'kind': 'LISTING', 'version': 1,
              'decision': 'PUBLISH', 'currentStatus': 'PENDING',
              'ready': !blocked, 'reason': 'Version conflict',
            }],
            'summary': {'total': 1, 'ready': blocked ? 0 : 1, 'blocked': blocked ? 1 : 0},
          },
        )))));
    await tester.pumpAndSettle();
    return container;
  }

  bool confirmationEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận xử lý'))
      .onPressed != null;

  testWidgets('partial preview blocks the entire batch', (tester) async {
    await pumpPreview(tester, blocked: true);
    expect(confirmationEnabled(tester), false);
    expect(find.text('Version conflict'), findsOneWidget);
  });

  testWidgets('permission revocation hides preview and disables execution',
      (tester) async {
    final container = await pumpPreview(tester);
    expect(confirmationEnabled(tester), true);
    container.read(_permissions.notifier).state = [];
    await tester.pumpAndSettle();
    expect(confirmationEnabled(tester), false);
    expect(find.text('LISTING · listing-1'), findsNothing);
  });

  testWidgets('session replacement cannot reuse a previous preview',
      (tester) async {
    final container = await pumpPreview(tester);
    container.read(_owner.notifier).state = 'other-admin';
    await tester.pumpAndSettle();
    expect(confirmationEnabled(tester), false);
    expect(find.text('LISTING · listing-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
