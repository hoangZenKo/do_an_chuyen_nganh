import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/models/admin_models.dart';

ResponseBody _json(String body, int statusCode) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final ResponseBody response;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

AdminApi _api(_RecordingAdapter adapter) {
  return AdminApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
  );
}

void main() {
  test('scheduled report export requests plain CSV with session owner binding',
      () async {
    final adapter = _RecordingAdapter(
        ResponseBody.fromString('report,total\r\nMODERATION,3', 200, headers: {
      Headers.contentTypeHeader: ['text/csv']
    }));
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    final api = AdminApi(dio, ownerId: 'admin-1');
    expect(await api.downloadReport('run-1'), contains('MODERATION,3'));
    expect(adapter.request.path, '/admin/report-runs/run-1/download');
    expect(adapter.request.extra['expectedUserId'], 'admin-1');
  });
  test('audit export sends the applied filters, reason and session owner',
      () async {
    final adapter = _RecordingAdapter(ResponseBody.fromString(
      '"id","summary"\r\n"audit-1","Changed account"',
      201,
      headers: {
        Headers.contentTypeHeader: ['text/csv; charset=utf-8']
      },
    ));
    final api = AdminApi(
        Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
          ..httpClientAdapter = adapter,
        ownerId: 'admin-1');
    final csv = await api.exportAudit({
      'from': '2026-10-24T00:00:00Z',
      'to': '2026-10-25T00:00:00Z',
      'action': 'admin.account_suspend',
      'requestId': 'request-1234',
    }, reason: 'Investigating account suspension');
    expect(adapter.request.path, '/admin/audit-logs/export');
    expect(adapter.request.extra['expectedUserId'], 'admin-1');
    expect((adapter.request.data as Map)['reason'],
        'Investigating account suspension');
    expect((adapter.request.data as Map)['requestId'], 'request-1234');
    expect(csv, contains('audit-1'));
  });

  test('audit filters include correlation id and date boundaries', () async {
    final adapter = _RecordingAdapter(_json(
        '{"data":[],"meta":{"page":2,"limit":30,"total":0,"pages":0}}', 200));
    await _api(adapter).auditLogs(
        page: 2,
        requestId: 'request-1234',
        from: '2026-10-24T00:00:00Z',
        to: '2026-10-25T00:00:00Z');
    expect(adapter.request.queryParameters, {
      'page': 2,
      'limit': 30,
      'requestId': 'request-1234',
      'from': '2026-10-24T00:00:00Z',
      'to': '2026-10-25T00:00:00Z',
    });
  });

  test('overview requests admin overview and parses totals', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":{"generatedAt":"2026-08-07T00:00:00.000Z",'
        '"landlords":{"total":2,"active":1,"inactive":1},'
        '"properties":{"total":3},"rooms":{"total":4},'
        '"tenants":{"total":5},"leases":{"active":6},'
        '"recentLandlords":[],"recentProperties":[]}}',
        200,
      ),
    );

    final overview = await _api(adapter).overview();

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/admin/overview');
    expect(overview.landlordsTotal, 2);
    expect(overview.activeLeasesTotal, 6);
  });

  test('listLandlords serializes query and parses data envelope', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"data":[{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":"123","isActive":true,'
        '"propertyCount":1,"roomCount":2,"occupiedCount":1,'
        '"tenantCount":1}]}',
        200,
      ),
    );

    final landlords = await _api(adapter).listLandlords(
      const AdminLandlordsQuery(search: ' Owner ', status: 'active'),
    );

    expect(adapter.request.method, 'GET');
    expect(adapter.request.path, '/admin/landlords');
    expect(adapter.request.queryParameters, {
      'search': 'Owner',
      'status': 'active',
    });
    expect(landlords.single.email, 'owner@example.com');
  });

  test('landlord mutations use the expected paths and bodies', () async {
    final createAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":"123",'
        '"isActive":true,"role":"landlord"}}',
        201,
      ),
    );
    await _api(createAdapter).createLandlord(
      fullName: 'Owner',
      email: 'owner@example.com',
      phone: '123',
      password: 'password123',
    );
    expect(createAdapter.request.method, 'POST');
    expect(createAdapter.request.path, '/admin/landlords');
    expect(createAdapter.request.data, {
      'fullName': 'Owner',
      'email': 'owner@example.com',
      'phone': '123',
      'password': 'password123',
    });

    final getAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":"123","isActive":true,'
        '"propertyCount":0,"roomCount":0,"occupiedCount":0,'
        '"tenantCount":0,"activeLeaseCount":0,"recentProperties":[]}}',
        200,
      ),
    );
    await _api(getAdapter).getLandlord('u1');
    expect(getAdapter.request.method, 'GET');
    expect(getAdapter.request.path, '/admin/landlords/u1');

    final updateAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"u1","fullName":"New Owner",'
        '"email":"owner@example.com","phone":"456",'
        '"isActive":true,"role":"landlord"}}',
        200,
      ),
    );
    await _api(updateAdapter).updateLandlord('u1', fullName: 'New Owner');
    expect(updateAdapter.request.method, 'PATCH');
    expect(updateAdapter.request.path, '/admin/landlords/u1');
    expect(updateAdapter.request.data, {'fullName': 'New Owner'});

    final statusAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":"123",'
        '"isActive":false,"role":"landlord"}}',
        200,
      ),
    );
    await _api(statusAdapter).updateLandlordStatus('u1', isActive: false);
    expect(statusAdapter.request.method, 'PATCH');
    expect(statusAdapter.request.path, '/admin/landlords/u1/status');
    expect(statusAdapter.request.data, {'isActive': false});
  });

  test('property operations use the expected paths, query, and bodies',
      () async {
    final listAdapter = _RecordingAdapter(
      _json(
        '[{"id":"p1","name":"Building A","address":"123 Street",'
        '"landlord":{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":null,"isActive":true},'
        '"roomCount":2,"occupiedCount":1,"vacantCount":1}]',
        200,
      ),
    );
    final properties = await _api(listAdapter).listProperties(
      const AdminPropertiesQuery(search: ' Building ', landlordId: 'u1'),
    );
    expect(listAdapter.request.method, 'GET');
    expect(listAdapter.request.path, '/admin/properties');
    expect(listAdapter.request.queryParameters, {
      'page': 1,
      'limit': 20,
      'search': 'Building',
      'landlordId': 'u1',
    });
    expect(properties.data.single.landlord?.id, 'u1');

    final createAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"p1","name":"Building A","address":"123 Street",'
        '"landlord":{"id":"u1","fullName":"Owner",'
        '"email":"owner@example.com","phone":null,"isActive":true},'
        '"roomCount":0,"occupiedCount":0,"vacantCount":0}}',
        201,
      ),
    );
    await _api(createAdapter).createProperty(
      landlordId: 'u1',
      name: 'Building A',
      address: '123 Street',
    );
    expect(createAdapter.request.method, 'POST');
    expect(createAdapter.request.path, '/admin/properties');
    expect(createAdapter.request.data, {
      'landlordId': 'u1',
      'name': 'Building A',
      'address': '123 Street',
    });

    final getAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"p1","name":"Building A","address":"123 Street",'
        '"roomCount":1,"occupiedCount":0,"vacantCount":1,"rooms":[]}}',
        200,
      ),
    );
    await _api(getAdapter).getProperty('p1');
    expect(getAdapter.request.method, 'GET');
    expect(getAdapter.request.path, '/admin/properties/p1');

    final updateAdapter = _RecordingAdapter(
      _json(
        '{"data":{"id":"p1","name":"Building A","address":"456 Street",'
        '"roomCount":1,"occupiedCount":0,"vacantCount":1,"rooms":[]}}',
        200,
      ),
    );
    await _api(updateAdapter).updateProperty('p1', address: '456 Street');
    expect(updateAdapter.request.method, 'PATCH');
    expect(updateAdapter.request.path, '/admin/properties/p1');
    expect(updateAdapter.request.data, {'address': '456 Street'});
  });

  test('maps Dio failures to ApiFailure', () async {
    final adapter = _RecordingAdapter(
      _json(
        '{"error":{"code":"LANDLORD_EMAIL_ALREADY_REGISTERED",'
        '"message":"Email already exists"}}',
        409,
      ),
    );

    await expectLater(
      _api(adapter).createLandlord(
        fullName: 'Owner',
        email: 'owner@example.com',
        phone: '123',
        password: 'password123',
      ),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'statusCode', 409)
            .having((failure) => failure.code, 'code',
                'LANDLORD_EMAIL_ALREADY_REGISTERED'),
      ),
    );
  });
}
