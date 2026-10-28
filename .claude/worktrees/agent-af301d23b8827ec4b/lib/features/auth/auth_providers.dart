import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../data/auth/auth_api.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/secure_session_storage.dart';
import '../../models/auth_models.dart';

final secureStorageProvider = Provider<SecureSessionStorage>((ref) {
  return SecureSessionStorage(
    storage: const FlutterSecureStorage(),
  );
});

final dioProvider = Provider((ref) {
  return createApiClient(
    ref.watch(secureStorageProvider),
    onSessionInvalid: () async {
      ref.read(sessionControllerProvider.notifier).markUnauthenticated();
    },
  );
});

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    api: AuthApi(ref.watch(dioProvider)),
    storage: ref.watch(secureStorageProvider),
  );
});

enum SessionStatus { checking, unauthenticated, authenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.session,
    this.failure,
  });

  const SessionState.checking() : this(status: SessionStatus.checking);
  const SessionState.unauthenticated({Object? failure})
      : this(status: SessionStatus.unauthenticated, failure: failure);
  const SessionState.authenticated(AuthSession session)
      : this(status: SessionStatus.authenticated, session: session);

  final SessionStatus status;
  final AuthSession? session;
  final Object? failure;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState.checking();

  Future<void> restore() async {
    state = const SessionState.checking();
    try {
      final session = await ref.read(authRepositoryProvider).restore();
      state = session == null
          ? const SessionState.unauthenticated()
          : SessionState.authenticated(session);
    } catch (error) {
      // A timeout or server outage must not turn a valid local session into a
      // logout. AuthRepository clears credentials only when the refresh token
      // is explicitly rejected.
      state = SessionState.unauthenticated(failure: error);
    }
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    try {
      final session = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      state = SessionState.authenticated(session);
      return session;
    } catch (error) {
      state = SessionState.unauthenticated(failure: error);
      rethrow;
    }
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final session = await ref.read(authRepositoryProvider).register(
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
          );
      state = SessionState.authenticated(session);
      return session;
    } catch (error) {
      state = SessionState.unauthenticated(failure: error);
      rethrow;
    }
  }

  void markUnauthenticated() {
    state = const SessionState.unauthenticated();
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const SessionState.unauthenticated();
    }
  }

  Future<AuthSession> acceptTenantInvite({
    required String inviteCode,
    required String password,
  }) async {
    final session = await ref.read(authRepositoryProvider).acceptTenantInvite(
          inviteCode: inviteCode,
          password: password,
        );
    state = SessionState.authenticated(session);
    return session;
  }

  Future<AuthSession> acceptStaffInvite({
    required String inviteCode,
    required String password,
  }) async {
    final session = await ref.read(authRepositoryProvider).acceptStaffInvite(
          inviteCode: inviteCode,
          password: password,
        );
    state = SessionState.authenticated(session);
    return session;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(sessionControllerProvider).session?.user.role == 'admin';
});
