import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/models/admin_models.dart';

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  Object body = {
    'data': [
      {
        'id': 'customer-1',
        'fullName': 'Customer',
        'email': 'c***@example.test',
        'phone': '***123',
        'role': 'LANDLORD',
        'isActive': true,
        'version': 7,
        'createdAt': '2026-10-27T03:00:00Z',
      }
    ],
    'meta': {'page': 2, 'limit': 20, 'total': 21, 'pages': 2},
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('accounts binds owner and serializes filters without losing metadata',
      () async {
    final adapter = _Adapter();
    final api = AdminApi(
        Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
          ..httpClientAdapter = adapter,
        ownerId: 'admin-1');
    final result = await api.accounts(
      page: 2,
      search: '  Customer  ',
      role: 'LANDLORD',
      status: 'active',
      from: '2026-10-01T00:00:00+07:00',
      to: '2026-10-27T23:59:59.999+07:00',
    );
    expect(adapter.request.path, '/admin/accounts');
    expect(adapter.request.extra['expectedUserId'], 'admin-1');
    expect(adapter.request.queryParameters, {
      'page': 2,
      'limit': 20,
      'search': 'Customer',
      'role': 'LANDLORD',
      'status': 'active',
      'from': '2026-10-01T00:00:00+07:00',
      'to': '2026-10-27T23:59:59.999+07:00',
    });
    expect(result.total, 21);
    expect(result.pages, 2);
    expect(result.data.single.version, 7);
    expect(result.data.single.email, 'c***@example.test');
  });

  test('query identity includes date boundaries', () {
    const first = AdminAccountsQuery(from: '2026-10-01T00:00:00Z');
    const second = AdminAccountsQuery(from: '2026-10-02T00:00:00Z');
    expect(first, isNot(second));
    expect(first.copyWith(page: 2).from, first.from);
    expect(first.copyWith(clearDates: true).from, isNull);
  });

  test('detail preserves version, counts and masked history projection',
      () async {
    final adapter = _Adapter();
    final account = (adapter.body as Map)['data'][0] as Map<String, dynamic>;
    adapter.body = {
      'data': {
        ...account,
        'counts': {'properties': 3, 'tenants': 5},
        'staffProfile': {'landlordId': 'owner'},
        'tenantProfile': null,
        'history': [
          {
            'id': 'log-1',
            'action': 'admin.account_restore',
            'summary': 'Verified account recovery',
            'createdAt': '2026-10-27T03:00:00Z'
          }
        ]
      }
    };
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'admin-1');
    final result = await api.account('customer-1');
    expect(adapter.request.path, '/admin/accounts/customer-1');
    expect(adapter.request.extra['expectedUserId'], 'admin-1');
    expect(result.account.version, 7);
    expect(result.properties, 3);
    expect(result.tenants, 5);
    expect(result.staffLandlordId, 'owner');
    expect(result.history.single.summary, 'Verified account recovery');
  });

  test(
      'status uses reason/version and owner binding through authorized command',
      () async {
    final adapter = _Adapter();
    adapter.body = {
      'data': {
        ...(adapter.body as Map)['data'][0] as Map,
        'isActive': false,
        'version': 8
      }
    };
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'admin-1');
    final result = await api.updateAccountStatus('customer-1',
        isActive: false,
        version: 7,
        reason: 'Verified support request',
        prompt: () async => null);
    expect(adapter.request.path, '/admin/accounts/customer-1/suspend');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.data,
        {'reason': 'Verified support request', 'version': 7});
    expect(adapter.request.extra['expectedUserId'], 'admin-1');
    expect(result.version, 8);
  });

  test('revoke, reset and reveal use existing protected contracts', () async {
    final adapter = _Adapter()
      ..body = {
        'data': {'revoked': true, 'revokedSessions': 2}
      };
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'admin-1');
    expect(
        await api.revokeAccountSessions('customer-1',
            reason: 'Reported lost device', prompt: () async => null),
        2);
    expect(adapter.request.path, '/admin/accounts/customer-1/revoke-sessions');
    adapter.body = {
      'data': {'queued': true}
    };
    await api.resetAccountPassword('customer-1',
        reason: 'Verified support request', prompt: () async => null);
    expect(adapter.request.path, '/admin/accounts/customer-1/reset-password');
    adapter.body = {
      'data': {
        'id': 'customer-1',
        'email': 'customer@example.test',
        'phone': null
      }
    };
    final contacts = await api.revealAccountContacts('customer-1',
        reason: 'Verified support request', prompt: () async => null);
    expect(adapter.request.path, '/admin/accounts/customer-1/reveal');
    expect(contacts.email, 'customer@example.test');
    expect(contacts.phone, isNull);
  });
}
