import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_client.dart';
import 'package:rental_room_management/data/auth/auth_api.dart';
import 'package:rental_room_management/data/auth/auth_repository.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
import 'package:rental_room_management/models/auth_models.dart';

AuthSession _session({
  String accessToken = 'old-access',
  String refreshToken = 'old-refresh',
  String fullName = 'Stored User',
  String userId = 'u1',
  String email = 'test@example.com',
}) {
  return AuthSession(
    user: LandlordUser(
      id: userId,
      fullName: fullName,
      email: email,
      role: 'landlord',
    ),
    accessToken: accessToken,
    refreshToken: refreshToken,
  );
}

String _sessionJson() => jsonEncode({
      'data': {
        'user': {
          'id': 'u1',
          'fullName': 'Stored User',
          'email': 'test@example.com',
          'phone': null,
          'role': 'landlord',
        },
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      },
    });

ResponseBody _json(Object body, int statusCode) {
  return ResponseBody.fromString(
    body is String ? body : jsonEncode(body),
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

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _QueueAdapter implements HttpClientAdapter {
  final Map<String, List<ResponseBody>> responses = {};

  void enqueue(String path, ResponseBody response) {
    responses.putIfAbsent(path, () => []).add(response);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final queued = responses[options.path];
    if (queued == null || queued.isEmpty) {
      return _json({
        'error': {'message': 'Unexpected path'}
      }, 500);
    }
    return queued.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

class _AccountSwitchingAuthApi extends AuthApi {
  _AccountSwitchingAuthApi(this.storage) : super(Dio());

  final _FakeSessionStorage storage;

  @override
  Future<LandlordUser> me() async {
    await storage.write(
      _session(
        accessToken: 'account-b-access',
        refreshToken: 'account-b-refresh',
        fullName: 'Account B',
        userId: 'u2',
        email: 'b@example.com',
      ),
    );
    return const LandlordUser(
      id: 'u1',
      fullName: 'Account A',
      email: 'a@example.com',
      role: 'landlord',
    );
  }
}

void main() {
  test('restore preserves tokens rotated while auth me is retried', () async {
    final storage = _FakeSessionStorage(_session());
    final refreshAdapter = _QueueAdapter()
      ..enqueue('/auth/refresh', _json(_sessionJson(), 201));
    final refreshClient = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = refreshAdapter;
    final mainAdapter = _QueueAdapter()
      ..enqueue(
        '/auth/me',
        _json({
          'error': {'message': 'Expired'}
        }, 401),
      )
      ..enqueue(
        '/auth/me',
        _json({
          'data': {
            'id': 'u1',
            'fullName': 'Current User',
            'email': 'test@example.com',
            'phone': null,
            'role': 'landlord',
          },
        }, 200),
      );
    final dio = createApiClient(storage, refreshClient: refreshClient)
      ..httpClientAdapter = mainAdapter;
    final repository = AuthRepository(
      api: AuthApi(dio),
      storage: storage,
    );

    final restored = await repository.restore();

    expect(restored?.accessToken, 'new-access');
    expect(restored?.refreshToken, 'new-refresh');
    expect(restored?.user.fullName, 'Current User');
    expect(storage.session?.accessToken, 'new-access');
    expect(storage.session?.refreshToken, 'new-refresh');
  });

  test('restore does not overwrite a newer account session', () async {
    final storage = _FakeSessionStorage(
      _session(fullName: 'Account A', email: 'a@example.com'),
    );
    final repository = AuthRepository(
      api: _AccountSwitchingAuthApi(storage),
      storage: storage,
    );

    final restored = await repository.restore();

    expect(restored?.user.id, 'u2');
    expect(restored?.accessToken, 'account-b-access');
    expect(storage.session?.user.id, 'u2');
    expect(storage.session?.accessToken, 'account-b-access');
  });
}
