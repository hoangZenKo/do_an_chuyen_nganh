import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/auth/auth_api.dart';
import 'package:rental_room_management/data/auth/auth_repository.dart';
import 'package:rental_room_management/data/auth/secure_session_storage.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/rooms/room_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';

AuthSession _session(String account) {
  return AuthSession(
    user: LandlordUser(
      id: 'user-$account',
      fullName: 'User $account',
      email: '$account@example.com',
      role: 'landlord',
    ),
    accessToken: 'access-$account',
    refreshToken: 'refresh-$account',
  );
}

class _FakeSessionStorage extends SecureSessionStorage {
  _FakeSessionStorage() : super(storage: const FlutterSecureStorage());

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

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.sessionStorage)
      : super(api: AuthApi(Dio()), storage: sessionStorage);

  final _FakeSessionStorage sessionStorage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    final session = _session(email.split('@').first);
    await sessionStorage.write(session);
    return session;
  }

  @override
  Future<void> logout() => sessionStorage.clear();
  @override
  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {}
}

class _AccountPropertyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'];
    final account = authorization == 'Bearer access-b' ? 'b' : 'a';
    return ResponseBody.fromString(
      jsonEncode({
        'data': [
          {
            'id': 'property-$account',
            'name': 'Property $account',
            'address': 'Address $account',
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_FakeSessionStorage storage) {
  final repository = _FakeAuthRepository(storage);
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

void main() {
  test(
      'password change clears the local session and returns to unauthenticated state',
      () async {
    final storage = _FakeSessionStorage();
    final container = _container(storage);
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.login(email: 'a@example.com', password: 'secret');
    await controller.changePassword(
        currentPassword: 'secret', newPassword: 'NewPassword!123');
    expect(container.read(sessionControllerProvider).status,
        SessionStatus.unauthenticated);
    expect(await storage.read(), isNull);
  });
  test('property cache reloads when a different account signs in', () async {
    final storage = _FakeSessionStorage();
    final container = _container(storage);
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = _AccountPropertyAdapter();
    final sessionController =
        container.read(sessionControllerProvider.notifier);

    await sessionController.login(email: 'a@example.com', password: 'secret');
    final accountAProperties = await container.read(propertiesProvider.future);

    await sessionController.logout();
    await sessionController.login(email: 'b@example.com', password: 'secret');
    final accountBProperties = await container.read(propertiesProvider.future);

    expect(accountAProperties.single.id, 'property-a');
    expect(accountBProperties.single.id, 'property-b');
  });

  test('selected property resets when the authenticated account changes',
      () async {
    final storage = _FakeSessionStorage();
    final container = _container(storage);
    addTearDown(container.dispose);
    final sessionController =
        container.read(sessionControllerProvider.notifier);

    await sessionController.login(email: 'a@example.com', password: 'secret');
    container.read(selectedPropertyProvider.notifier).state = 'property-a';

    await sessionController.logout();

    expect(container.read(selectedPropertyProvider), isNull);
  });
}
