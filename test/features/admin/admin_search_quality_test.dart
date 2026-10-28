import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/features/admin/admin_console_providers.dart';
import 'package:rental_room_management/features/admin/admin_moderation_quality_panel.dart';
import 'package:rental_room_management/features/admin/admin_providers.dart';
import 'package:rental_room_management/features/admin/admin_search_results.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/models/admin_models.dart';

final _identity = StateProvider<String?>((ref) => 'reviewer');
final _permissions = StateProvider<List<String>>((ref) => [
      'admin.dashboard.view',
      'admin.finance.read',
      'admin.moderation.reports',
      'admin.listings.moderate'
    ]);

class _Api extends AdminApi {
  _Api() : super(Dio());
  final calls = <(String, Map<String, dynamic>)>[];
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> authorizedCommand(
      String path, Map<String, dynamic> data,
      {bool patch = false, required AdminStepUpPrompt prompt}) async {
    calls.add((path, data));
    return pending?.future ??
        {
          'data': {'outcome': 'AGREE'}
        };
  }
}

Map<String, dynamic> _group(String name, {bool more = true}) => {
      'kind': 'PAYMENT',
      'items': [
        {'id': name, 'amount': 1200000, 'invoiceId': 'invoice-safe'}
      ],
      'meta': {'total': 21, 'hasMore': more}
    };

Future<ProviderContainer> _pump(WidgetTester tester, Widget child,
    {List<AdminRequest>? requests,
    List<String>? permissions,
    String? owner = 'reviewer',
    _Api? api,
    Size size = const Size(1200, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(overrides: [
    _identity.overrideWith((ref) => owner),
    if (permissions != null) _permissions.overrideWith((ref) => permissions),
    sessionIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
    adminCapabilitiesProvider.overrideWith(
        (ref) async => AdminCapabilities(ref.watch(_permissions))),
    if (api != null) adminApiProvider.overrideWithValue(api),
    adminResourceProvider.overrideWith((ref, request) async {
      requests?.add(request);
      if (request.path == '/admin/search')
        return {
          'data': [_group('payment-page-2', more: false)]
        };
      if (request.path.startsWith('/admin/resources/'))
        return {
          'data': {
            'id': 'payment-detail',
            'amount': 1200000,
            'invoiceId': 'invoice-safe'
          }
        };
      if (request.path.endsWith('/quality'))
        return {
          'data': {
            'decisions': [],
            'qa': {'total': 0},
            'generatedAt': '2026-10-27T00:00:00Z'
          }
        };
      if (request.path.endsWith('/samples'))
        return {
          'data': [
            {
              'id': 'decision-1',
              'kind': 'LISTING',
              'actorId': 'other-moderator',
              'fromStatus': 'PENDING',
              'toStatus': 'REJECTED',
              'version': 8
            }
          ],
          'meta': {'hasMore': false}
        };
      return {
        'data': {
          'id': 'decision-1',
          'kind': 'LISTING',
          'version': 8,
          'reason': 'Original decision reason',
          'evidence': {
            'content': {'title': 'Snapshot evidence'}
          },
          'qualityReview': null
        }
      };
    }),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width < 500 ? 1.5 : 1)),
            child: child!),
        home: RepaintBoundary(
            key: const ValueKey('search-quality-qa'),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20), child: child))),
      )));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['ADMIN_QA_OUTPUT'];
  if (directory == null) return;
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('search-quality-qa')));
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(File('assets/fonts/Manrope-VariableFont_wght.ttf')
              .readAsBytes()
              .then(ByteData.sublistView)))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets(
      'payment pagination changes only its group and revocation removes cached data',
      (tester) async {
    final requests = <AdminRequest>[];
    final container = await _pump(
        tester,
        AdminSearchResultGroup(
            query: 'invoice', group: _group('payment-first')),
        requests: requests);
    expect(find.text('payment-first'), findsOneWidget);
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(requests.last.query,
        {'search': 'invoice', 'kind': 'PAYMENT', 'page': 2, 'limit': 10});
    expect(find.text('payment-page-2'), findsOneWidget);
    container.read(_permissions.notifier).state = ['admin.dashboard.view'];
    await tester.pumpAndSettle();
    expect(find.text('payment-page-2'), findsNothing);
  });

  testWidgets(
      'QA is lazy, independently scoped and submits the exact decision version once',
      (tester) async {
    final requests = <AdminRequest>[];
    final api = _Api()..pending = Completer<Map<String, dynamic>>();
    final container = await _pump(tester, const AdminModerationQualityPanel(),
        requests: requests, api: api);
    expect(
        requests.any((request) => request.path.endsWith('/samples/decision-1')),
        isFalse);
    expect(requests.first.query['timezone'], 'Asia/Ho_Chi_Minh');
    final sample = find.text('Tin đăng · PENDING → REJECTED');
    await tester.ensureVisible(sample);
    await tester.tap(sample);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ghi nhận QA'));
    await tester.tap(find.text('Ghi nhận QA'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Lý do (ghi vào audit)'),
        'Independent policy evidence reviewed');
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    expect(api.calls.single.$1,
        '/admin/moderation-policies/quality/samples/decision-1/review');
    expect(api.calls.single.$2['version'], 8);
    expect(api.calls.single.$2['outcome'], 'AGREE');
    container.read(_identity.notifier).state = 'another-user';
    await tester.pump();
    api.pending!.complete({
      'data': {'outcome': 'AGREE'}
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Snapshot evidence'), findsNothing);
    expect(api.calls, hasLength(1));
  });

  testWidgets('restricted QA and finance details never fetch', (tester) async {
    final requests = <AdminRequest>[];
    await _pump(
        tester,
        const Column(children: [
          AdminModerationQualityPanel(),
          AdminSearchResourceDetail(kind: 'PAYMENT', id: 'payment-id')
        ]),
        permissions: ['admin.dashboard.view'],
        requests: requests);
    expect(requests, isEmpty);
  });

  for (final size in [const Size(390, 1000), const Size(1200, 1000)]) {
    testWidgets(
        'quality fits ${size.width} and has an explicit freshness and non-sanction definition',
        (tester) async {
      await _pump(tester, const AdminModerationQualityPanel(), size: size);
      expect(find.textContaining('không tự áp dụng chế tài'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'quality-${size.width.toInt()}');
    });
    testWidgets('search pagination fits ${size.width} with enlarged text',
        (tester) async {
      await _pump(
          tester,
          AdminSearchResultGroup(
              query: 'invoice', group: _group('payment-first')),
          size: size);
      expect(find.text('Trang sau'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'search-${size.width.toInt()}');
    });
  }
}
