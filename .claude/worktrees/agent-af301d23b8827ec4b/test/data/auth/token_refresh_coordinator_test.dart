import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
import 'package:rental_room_management/data/auth/token_refresh_coordinator.dart';
import 'package:rental_room_management/models/auth_models.dart';

AuthSession _session({
  String accessToken = 'old-access',
  String refreshToken = 'old-refresh',
}) {
  return AuthSession(
    user: const LandlordUser(
      id: 'u1',
      fullName: 'Test User',
      email: 'test@example.com',
      role: 'landlord',
    ),
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
}

String _sessionJson({
  String accessToken = 'new-access',
  String refreshToken = 'new-refresh',
}) {
  return jsonEncode({
    'data': {
      'user': {
        'id': 'u1',
        'fullName': 'Test User',
        'email': 'test@example.com',
        'phone': null,
        'role': 'landlord',
      },
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    },
  });
}

ResponseBody _json(String body, int statusCode) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeSessionStorage extends SecureSessionStorage {
  _FakeSessionStorage(this.session)
      : super(storage: const FlutterSecureStorage());

  AuthSession? session;
  int writes = 0;
  int clears = 0;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    writes += 1;
    this.session = session;
  }

  @override
  Future<void> clear() async {
    clears += 1;
    session = null;
  }
}

class _CompleterAdapter implements HttpClientAdapter {
  final completer = Completer<ResponseBody>();
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _waitForRequest(_CompleterAdapter adapter) async {
  for (var i = 0; i < 20; i += 1) {
    if (adapter.requests.isNotEmpty) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected refresh request to be sent.');
}

void main() {
  test('shares one in-flight refresh across concurrent callers', () async {
    final storage = _FakeSessionStorage(_session());
    final adapter = _CompleterAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    final coordinator = TokenRefreshCoordinator(
      storage: storage,
      refreshClient: dio,
    );

    final first = coordinator.refresh();
    final second = coordinator.refresh();
    await _waitForRequest(adapter);

    expect(adapter.requests, hasLength(1));
    adapter.completer.complete(_json(_sessionJson(), 201));

    final results = await Future.wait([first, second]);
    expect(results.first?.accessToken, 'new-access');
    expect(results.last?.accessToken, 'new-access');
    expect(storage.writes, 1);
  });

  test('clears stored session and returns null when refresh is rejected with 401',
      () async {
    final storage = _FakeSessionStorage(_session());
    final adapter = _CompleterAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    var invalidated = false;
    final coordinator = TokenRefreshCoordinator(
      storage: storage,
      refreshClient: dio,
      onSessionInvalid: () async => invalidated = true,
    );

    final refresh = coordinator.refresh();
    await _waitForRequest(adapter);
    adapter.completer.complete(
      _json('{"error":{"message":"Refresh token rejected"}}', 401),
    );

    await expectLater(refresh, completion(isNull));
    expect(storage.clears, 1);
    expect(invalidated, isTrue);
  });

  test('does not clear stored session on non-401 refresh failures', () async {
    final storage = _FakeSessionStorage(_session());
    final adapter = _CompleterAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;
    final coordinator = TokenRefreshCoordinator(
      storage: storage,
      refreshClient: dio,
    );

    final refresh = coordinator.refresh();
    await _waitForRequest(adapter);
    adapter.completer.complete(
      _json('{"error":{"message":"Temporarily unavailable"}}', 503),
    );

    await expectLater(refresh, throwsA(isA<DioException>()));
    expect(storage.clears, 0);
    expect(storage.session?.refreshToken, 'old-refresh');
  });

  test('starts a new refresh after the previous in-flight request completes',
      () async {
    final storage = _FakeSessionStorage(_session());
    final firstAdapter = _CompleterAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = firstAdapter;
    final coordinator = TokenRefreshCoordinator(
      storage: storage,
      refreshClient: dio,
    );

    final first = coordinator.refresh();
    await _waitForRequest(firstAdapter);
    firstAdapter.completer.complete(_json(_sessionJson(), 201));
    await first;

    final secondAdapter = _CompleterAdapter();
    dio.httpClientAdapter = secondAdapter;
    final second = coordinator.refresh();
    await _waitForRequest(secondAdapter);

    expect(secondAdapter.requests, hasLength(1));
    secondAdapter.completer.complete(
      _json(_sessionJson(accessToken: 'newer-access'), 201),
    );
    expect((await second)?.accessToken, 'newer-access');
  });
}
