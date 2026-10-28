import 'capture_helper.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rental_room_management/data/rooms/property_api.dart';
import 'package:rental_room_management/data/rooms/room_api.dart';
import 'package:rental_room_management/data/rooms/room_repository.dart';
import 'package:rental_room_management/features/auth/auth_navigation.dart';
import 'package:rental_room_management/features/properties/properties_list_screen.dart';
import 'package:rental_room_management/features/properties/property_form_screen.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/property.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final ResponseBody response;
  late RequestOptions request;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final bytes = await requestStream.expand((chunk) => chunk).toList();
      if (bytes.isNotEmpty) {
        body = jsonDecode(utf8.decode(bytes));
      }
    }
    return response;
  }

  @override
  void close({bool force = false}) {}
}

class _MockPropertyApi extends Mock implements PropertyApi {}

class _MockRoomApi extends Mock implements RoomApi {}

RoomRepository _repository(_MockPropertyApi propertyApi) {
  return RoomRepository(propertyApi: propertyApi, roomApi: _MockRoomApi());
}

ProviderContainer _container(RoomRepository repository) {
  return ProviderContainer(
    overrides: [roomRepositoryProvider.overrideWithValue(repository)],
  );
}

Widget _scopedApp({
  required ProviderContainer container,
  String initialLocation = propertiesRoute,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: propertiesRoute,
        builder: (_, __) => const PropertiesListScreen(),
      ),
      GoRoute(
        path: propertyFormRoute,
        builder: (_, state) => PropertyFormScreen(
          propertyId: state.uri.queryParameters['propertyId'],
        ),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

ResponseBody _jsonResponse(String body, [int statusCode = 200]) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('Property.fromJson', () {
    test('parses a bare object and computes vacant rooms', () {
      final property = Property.fromJson({
        'id': 'p1',
        'name': 'Khu A',
        'address': '123 Đường A',
        'roomCount': 5,
        'occupiedCount': 3,
      });

      expect(property.id, 'p1');
      expect(property.name, 'Khu A');
      expect(property.address, '123 Đường A');
      expect(property.isArchived, isFalse);
      expect(property.vacantCount, 2);
    });

    test('parses a data envelope and numeric strings', () {
      final property = Property.fromJson({
        'data': {
          'id': 'p2',
          'name': 'Khu B',
          'roomCount': '4',
          'occupiedCount': 2.0,
        },
      });

      expect(property.id, 'p2');
      expect(property.address, '');
      expect(property.roomCount, 4);
      expect(property.occupiedCount, 2);
      expect(property.vacantCount, 2);
    });

    test('does not expose a negative vacant count', () {
      const property = Property(
        id: 'p3',
        name: 'Khu C',
        address: '',
        roomCount: 2,
        occupiedCount: 5,
      );

      expect(property.vacantCount, 0);
    });
  });

  group('PropertyApi', () {
    test('list requests properties and parses the data envelope', () async {
      final adapter = _RecordingAdapter(_jsonResponse('''
        {
          "data": [
            {
              "id": "p1",
              "name": "Khu A",
              "address": "123",
              "roomCount": 3,
              "occupiedCount": 1
            }
          ]
        }
      '''));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;

      final properties = await PropertyApi(dio).list();

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/properties');
      expect(properties.single.name, 'Khu A');
      expect(properties.single.vacantCount, 2);
    });

    test('getById requests one property and parses an envelope', () async {
      final adapter = _RecordingAdapter(_jsonResponse('''
        {
          "data": {
            "id": "p1",
            "name": "Khu A",
            "address": "123"
          }
        }
      '''));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;

      final property = await PropertyApi(dio).getById('p1');

      expect(adapter.request.path, '/properties/p1');
      expect(property.id, 'p1');
      expect(property.name, 'Khu A');
    });

    test('create sends name and address', () async {
      final adapter = _RecordingAdapter(_jsonResponse('''
        { "data": { "id": "p1", "name": "Khu A", "address": "" } }
      ''', 201));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;

      final property = await PropertyApi(dio).create(
        name: 'Khu A',
        address: '',
      );

      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/properties');
      expect(adapter.body, {'name': 'Khu A', 'address': ''});
      expect(property.id, 'p1');
    });

    test('update sends only provided fields', () async {
      final adapter = _RecordingAdapter(_jsonResponse('''
        { "data": { "id": "p1", "name": "Tên mới", "address": "" } }
      '''));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;

      final property = await PropertyApi(dio).update('p1', name: 'Tên mới');

      expect(adapter.request.method, 'PATCH');
      expect(adapter.request.path, '/properties/p1');
      expect(adapter.body, {'name': 'Tên mới'});
      expect(property.name, 'Tên mới');
    });

    test('list can request archived properties', () async {
      final adapter = _RecordingAdapter(_jsonResponse('''
        {
          "data": [
            {
              "id": "p1",
              "name": "Khu A",
              "address": "123",
              "isArchived": true,
              "roomCount": 3,
              "occupiedCount": 1
            }
          ]
        }
      '''));
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter;

      final properties = await PropertyApi(dio).list(lifecycle: 'archived');

      expect(adapter.request.method, 'GET');
      expect(adapter.request.path, '/properties');
      expect(adapter.request.queryParameters, {'lifecycle': 'archived'});
      expect(properties.single.isArchived, isTrue);
    });

    test('setArchived and delete use lifecycle endpoints', () async {
      final archiveAdapter = _RecordingAdapter(_jsonResponse('''
        { "data": { "id": "p1", "name": "Khu A", "address": "", "isArchived": true } }
      '''));
      final archiveDio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = archiveAdapter;

      final archived = await PropertyApi(archiveDio).setArchived('p1', true);

      expect(archiveAdapter.request.method, 'PATCH');
      expect(archiveAdapter.request.path, '/properties/p1/status');
      expect(archiveAdapter.body, {'isArchived': true});
      expect(archived.isArchived, isTrue);

      final deleteAdapter = _RecordingAdapter(_jsonResponse('', 204));
      final deleteDio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = deleteAdapter;

      await PropertyApi(deleteDio).delete('p1');

      expect(deleteAdapter.request.method, 'DELETE');
      expect(deleteAdapter.request.path, '/properties/p1');
    });
  });

  group('PropertiesListScreen', () {
    late _MockPropertyApi propertyApi;
    late ProviderContainer container;

    setUp(() {
      propertyApi = _MockPropertyApi();
      container = _container(_repository(propertyApi));
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders property cards and updates the selected property',
        (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const [
                Property(
                  id: 'p1',
                  name: 'Khu A',
                  address: '123 Đường A',
                  roomCount: 5,
                  occupiedCount: 3,
                ),
                Property(
                  id: 'p2',
                  name: 'Khu B',
                  address: '',
                  roomCount: 2,
                  occupiedCount: 1,
                ),
              ]);

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      expect(find.text('Khu A'), findsOneWidget);
      expect(find.text('123 Đường A'), findsOneWidget);
      expect(find.text('5 phòng'), findsOneWidget);
      expect(find.text('3 đang thuê'), findsOneWidget);
      expect(find.text('2 trống'), findsWidgets);
      expect(find.text('Chưa có địa chỉ'), findsOneWidget);

      await tester.tap(find.text('Khu B'));
      await tester.pump();

      expect(container.read(selectedPropertyProvider), 'p2');
      expect(find.text('Đã chọn Khu B'), findsOneWidget);
    });

    testWidgets('shows empty state with a create CTA', (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const <Property>[]);

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      expect(find.text('Chưa có khu trọ'), findsOneWidget);
      expect(find.text('Tạo khu trọ'), findsOneWidget);
    });

    testWidgets('shows retry when loading properties fails', (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenThrow(Exception('boom'));

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });

  group('PropertyFormScreen', () {
    late _MockPropertyApi propertyApi;
    late ProviderContainer container;

    setUp(() {
      propertyApi = _MockPropertyApi();
      container = _container(_repository(propertyApi));
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('validates create form fields', (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const <Property>[]);

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pump();

      expect(find.text('Nhập tên khu trọ'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'a' * 121);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pump();

      expect(find.text('Tên tối đa 120 ký tự'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Khu A');
      await tester.enterText(find.byType(TextFormField).at(1), 'a' * 256);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pump();

      expect(find.text('Địa chỉ tối đa 255 ký tự'), findsOneWidget);
    });

    testWidgets('creates a property, selects it, and returns to the list',
        (tester) async {
      var listCalls = 0;
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async {
        listCalls += 1;
        return listCalls == 1
            ? const <Property>[]
            : const [
                Property(
                  id: 'p1',
                  name: 'Khu A',
                  address: '',
                ),
              ];
      });
      when(() => propertyApi.create(name: 'Khu A', address: ''))
          .thenAnswer((_) async => const Property(
                id: 'p1',
                name: 'Khu A',
                address: '',
              ));

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      await tester.enterText(find.byType(TextFormField).at(0), '  Khu A  ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo khu trọ'));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      verify(() => propertyApi.create(name: 'Khu A', address: '')).called(1);
      expect(container.read(selectedPropertyProvider), 'p1');
      expect(find.text('Khu A'), findsOneWidget);
    });

    testWidgets('prefills and updates an existing property', (tester) async {
      when(() => propertyApi.list(lifecycle: any(named: 'lifecycle')))
          .thenAnswer((_) async => const [
                Property(id: 'p1', name: 'Khu A', address: '123'),
              ]);
      when(() => propertyApi.update('p1', name: 'Khu A mới', address: '456'))
          .thenAnswer((_) async => const Property(
                id: 'p1',
                name: 'Khu A mới',
                address: '456',
              ));

      await reportPumpWidget(tester, _scopedApp(container: container));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      expect(find.text('Sửa khu trọ'), findsOneWidget);
      final nameField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      final addressField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      expect(nameField.controller?.text, 'Khu A');
      expect(addressField.controller?.text, '123');

      await tester.enterText(find.byType(TextFormField).at(0), 'Khu A mới');
      await tester.enterText(find.byType(TextFormField).at(1), '456');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle(); await reportCapture(tester, 'properties_test');

      verify(() => propertyApi.update('p1', name: 'Khu A mới', address: '456'))
          .called(1);
      expect(find.text('Khu A'), findsOneWidget);
    });
  });
}
