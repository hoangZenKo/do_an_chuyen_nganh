import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_client.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
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
  int reads = 0;
  int writes = 0;
  int clears = 0;

  @override
  Future<AuthSession?> read() async {
    reads += 1;
    return session;
  }

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

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

class _RoutingAdapter implements HttpClientAdapter {
  final Map<String, List<_Handler>> routes = {};
  final List<RequestOptions> requests = [];
  final Map<String, List<Object?>> _authorizationHeaders = {};

  void enqueue(String path, ResponseBody response) {
    enqueueHandler(path, (_) async => response);
  }

  void enqueueHandler(String path, _Handler handler) {
    routes.putIfAbsent(path, () => []).add(handler);
  }

  List<RequestOptions> requestsFor(String path) =>
      requests.where((request) => request.path == path).toList(growable: false);

  List<Object?> authorizationHeadersFor(String path) =>
      _authorizationHeaders[path] ?? const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    _authorizationHeaders
        .putIfAbsent(options.path, () => [])
        .add(options.headers['Authorization']);
    final handlers = routes[options.path];
    if (handlers == null || handlers.isEmpty) {
      return _json('{"error":{"message":"Unexpected path"}}', 500);
    }
    return handlers.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('attaches bearer token only to protected requests', () async {
    final storage = _FakeSessionStorage(_session());
    final mainAdapter = _RoutingAdapter()
      ..enqueue('/auth/login', _json('{"ok":true}', 200))
      ..enqueue('/dashboard', _json('{"ok":true}', 200));
    final dio = createApiClient(storage)..httpClientAdapter = mainAdapter;

    await dio.post('/auth/login');
    await dio.get('/dashboard');

    expect(mainAdapter.authorizationHeadersFor('/auth/login').single, isNull);
    expect(mainAdapter.authorizationHeadersFor('/dashboard').single,
        'Bearer old-access');
  });

  test('refreshes on protected 401, persists rotated session, and retries once',
      () async {
    final storage = _FakeSessionStorage(_session());
    final refreshAdapter = _RoutingAdapter()
      ..enqueue('/auth/refresh', _json(_sessionJson(), 201));
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = refreshAdapter;
    final mainAdapter = _RoutingAdapter()
      ..enqueue('/protected', _json('{"error":{"message":"Expired"}}', 401))
      ..enqueue('/protected', _json('{"data":{"ok":true}}', 200));
    final dio = createApiClient(
      storage,
      refreshClient: refreshClient,
    )..httpClientAdapter = mainAdapter;

    final response = await dio.get('/protected');

    expect(response.statusCode, 200);
    expect(storage.session?.accessToken, 'new-access');
    expect(storage.session?.refreshToken, 'new-refresh');
    expect(storage.writes, 1);
    expect(refreshAdapter.requestsFor('/auth/refresh'), hasLength(1));
    expect(mainAdapter.requestsFor('/protected'), hasLength(2));
    expect(mainAdapter.authorizationHeadersFor('/protected'), [
      'Bearer old-access',
      'Bearer new-access',
    ]);
  });

  test('does not retry indefinitely when replayed request remains unauthorized',
      () async {
    final storage = _FakeSessionStorage(_session());
    final refreshAdapter = _RoutingAdapter()
      ..enqueue('/auth/refresh', _json(_sessionJson(), 201));
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = refreshAdapter;
    final mainAdapter = _RoutingAdapter()
      ..enqueue('/protected', _json('{"error":{"message":"Expired"}}', 401))
      ..enqueue('/protected', _json('{"error":{"message":"Denied"}}', 401));
    final dio = createApiClient(storage, refreshClient: refreshClient)
      ..httpClientAdapter = mainAdapter;

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(refreshAdapter.requestsFor('/auth/refresh'), hasLength(1));
    expect(mainAdapter.requestsFor('/protected'), hasLength(2));
  });

  test('refresh 401 clears session and notifies invalid session', () async {
    final storage = _FakeSessionStorage(_session());
    var invalidated = false;
    final refreshAdapter = _RoutingAdapter()
      ..enqueue(
          '/auth/refresh', _json('{"error":{"message":"Bad refresh"}}', 401));
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = refreshAdapter;
    final mainAdapter = _RoutingAdapter()
      ..enqueue('/protected', _json('{"error":{"message":"Expired"}}', 401));
    final dio = createApiClient(
      storage,
      refreshClient: refreshClient,
      onSessionInvalid: () async => invalidated = true,
    )..httpClientAdapter = mainAdapter;

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(storage.clears, 1);
    expect(invalidated, isTrue);
  });

  test('non-401 refresh failure preserves the stored session', () async {
    final storage = _FakeSessionStorage(_session());
    final refreshAdapter = _RoutingAdapter()
      ..enqueue('/auth/refresh', _json('{"error":{"message":"Offline"}}', 503));
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = refreshAdapter;
    final mainAdapter = _RoutingAdapter()
      ..enqueue('/protected', _json('{"error":{"message":"Expired"}}', 401));
    final dio = createApiClient(storage, refreshClient: refreshClient)
      ..httpClientAdapter = mainAdapter;

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(storage.clears, 0);
    expect(storage.session?.accessToken, 'old-access');
  });
}
