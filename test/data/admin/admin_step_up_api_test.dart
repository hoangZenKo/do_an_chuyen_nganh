import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody _stepUpRequired() => _json({
      'error': {
        'code': 'ADMIN_STEP_UP_REQUIRED',
        'message': 'Fresh verification required',
      }
    }, 403);

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.responses);
  final List<ResponseBody> responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

AdminApi _api(_SequenceAdapter adapter) => AdminApi(
    Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter,
    ownerId: 'admin-1');

void main() {
  test('ordinary commands do not prompt for unnecessary step-up', () async {
    final adapter = _SequenceAdapter([
      _json({
        'data': {'updated': true}
      })
    ]);
    final result = await _api(adapter).authorizedCommand('/admin/example', {},
        prompt: () async => fail('Must not prompt'));
    expect((result['data'] as Map)['updated'], true);
    expect(adapter.requests, hasLength(1));
  });

  test('step-up retries once with the exact frozen payload and session owner',
      () async {
    final adapter = _SequenceAdapter([
      _stepUpRequired(),
      _json({
        'data': {'token': 'single-use-grant'}
      }, 201),
      _json({
        'data': {'updated': true}
      }),
    ]);
    final payload = <String, dynamic>{
      'reason': 'Review operational access',
      'items': [
        {'id': 'original', 'version': 1}
      ],
    };
    await _api(adapter).authorizedCommand('/admin/moderation-v2/bulk', payload,
        prompt: () async {
      (payload['items'] as List).clear();
      return '654321';
    });
    final initial = adapter.requests[0];
    final grant = adapter.requests[1];
    final retry = adapter.requests[2];
    expect(grant.path, '/admin/me/security/step-up');
    expect(grant.data, {
      'method': 'POST',
      'path': initial.path,
      'payload': initial.data,
      'code': '654321',
      'reason': 'Review operational access',
    });
    expect(retry.data, initial.data);
    expect((retry.data as Map)['items'], hasLength(1));
    expect(retry.headers['X-Admin-Step-Up'], 'single-use-grant');
    expect(initial.headers.containsKey('X-Admin-Step-Up'), false);
    for (final request in adapter.requests) {
      expect(request.extra['expectedUserId'], 'admin-1');
    }
  });

  test('PATCH command keeps the same method after step-up', () async {
    final adapter = _SequenceAdapter([
      _stepUpRequired(),
      _json({
        'data': {'token': 'grant'}
      }),
      _json({'data': {}}),
    ]);
    await _api(adapter).authorizedCommand('/admin/example', {'version': 1},
        patch: true, prompt: () async => '654321');
    expect(adapter.requests[0].method, 'PATCH');
    expect((adapter.requests[1].data as Map)['method'], 'PATCH');
    expect(adapter.requests[2].method, 'PATCH');
  });

  test(
      'legacy landlord status supports step-up without bypassing audit version',
      () async {
    final adapter = _SequenceAdapter([
      _stepUpRequired(),
      _json({
        'data': {'token': 'landlord-grant'}
      }),
      _json({
        'data': {'id': 'owner-1', 'isActive': false}
      }),
    ]);
    final record = await _api(adapter).updateLandlordStatus('owner-1',
        isActive: false,
        reason: 'Suspend pending investigation',
        version: 5,
        prompt: () async => '654321');
    expect(record.isActive, false);
    expect(adapter.requests[2].method, 'PATCH');
    expect(adapter.requests[2].data, {
      'isActive': false,
      'reason': 'Suspend pending investigation',
      'version': 5,
    });
    expect(adapter.requests[2].headers['X-Admin-Step-Up'], 'landlord-grant');
  });

  test('cancelled verification never issues a grant or repeats the action',
      () async {
    final adapter = _SequenceAdapter([_stepUpRequired()]);
    await expectLater(
        _api(adapter)
            .authorizedCommand('/admin/example', {}, prompt: () async => null),
        throwsA(isA<ApiFailure>()));
    expect(adapter.requests, hasLength(1));
  });

  test('permission failures do not trigger MFA or retry', () async {
    final adapter = _SequenceAdapter([
      _json({
        'error': {'code': 'FORBIDDEN', 'message': 'Permission revoked'}
      }, 403)
    ]);
    await expectLater(
        _api(adapter).authorizedCommand('/admin/example', {},
            prompt: () async => fail('Must not prompt')),
        throwsA(isA<ApiFailure>()
            .having((error) => error.code, 'error code', 'FORBIDDEN')));
    expect(adapter.requests, hasLength(1));
  });

  test('a rejected one-time grant does not start an infinite verification loop',
      () async {
    final adapter = _SequenceAdapter([
      _stepUpRequired(),
      _json({
        'data': {'token': 'expired-grant'}
      }),
      _stepUpRequired(),
    ]);
    var prompts = 0;
    await expectLater(
        _api(adapter).authorizedCommand('/admin/example', {}, prompt: () async {
          prompts++;
          return '654321';
        }),
        throwsA(isA<ApiFailure>()));
    expect(prompts, 1);
    expect(adapter.requests, hasLength(3));
  });

  test('audit export retries CSV using scoped grant, filters and reason',
      () async {
    final adapter = _SequenceAdapter([
      _stepUpRequired(),
      _json({
        'data': {'token': 'audit-grant'}
      }),
      ResponseBody.fromString('id,summary\r\naudit-1,Reviewed', 201, headers: {
        Headers.contentTypeHeader: ['text/csv; charset=utf-8']
      }),
    ]);
    final csv = await _api(adapter).authorizedAuditExport(
        {'from': '2026-10-25T00:00:00Z'},
        reason: 'Review account incident', prompt: () async => '654321');
    expect(csv, contains('audit-1'));
    expect(adapter.requests[2].path, '/admin/audit-logs/export');
    expect(adapter.requests[2].data, adapter.requests[0].data);
    expect(adapter.requests[2].headers['X-Admin-Step-Up'], 'audit-grant');
    expect(adapter.requests[2].extra['expectedUserId'], 'admin-1');
  });
}
