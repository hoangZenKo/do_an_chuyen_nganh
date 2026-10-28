import '../../core/network/api_failure.dart';
import '../../models/auth_models.dart';
import 'auth_api.dart';
import 'secure_session_storage.dart';

class AuthRepository {
  const AuthRepository({required this.api, required this.storage});

  final AuthApi api;
  final SecureSessionStorage storage;

  Future<AuthSession> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    final session =
        await api.login(email: email, password: password, mfaCode: mfaCode);
    _ensureSupportedRole(session.user);
    await storage.write(session);
    return session;
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    bool seeker = false,
  }) async {
    final session = await api.register(
      seeker: seeker,
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );
    _ensureSupportedRole(session.user);
    await storage.write(session);
    return session;
  }

  Future<AuthSession?> restore() async {
    final session = await storage.read();
    if (session == null) return null;
    try {
      final user = await api.me();
      _ensureSupportedRole(user);
      final currentSession = await storage.read();
      if (currentSession == null) return null;
      if (currentSession.user.id != session.user.id) return currentSession;
      final refreshed = AuthSession(
        user: user,
        accessToken: currentSession.accessToken,
        refreshToken: currentSession.refreshToken,
        accessTokenExpiresAt: currentSession.accessTokenExpiresAt,
        refreshTokenExpiresAt: currentSession.refreshTokenExpiresAt,
      );
      await storage.write(refreshed);
      return refreshed;
    } on ApiFailure catch (error) {
      if (error.statusCode != 401) rethrow;
      final beforeRefresh = await storage.read();
      if (beforeRefresh == null) return null;
      if (beforeRefresh.user.id != session.user.id) return beforeRefresh;
      try {
        final refreshed = await api.refresh(beforeRefresh.refreshToken);
        _ensureSupportedRole(refreshed.user);
        final current = await storage.read();
        if (current == null ||
            current.user.id != beforeRefresh.user.id ||
            current.refreshToken != beforeRefresh.refreshToken) {
          return current;
        }
        await storage.write(refreshed);
        return refreshed;
      } on ApiFailure catch (refreshError) {
        if (refreshError.statusCode == 401) {
          final current = await storage.read();
          if (current == null ||
              current.user.id != beforeRefresh.user.id ||
              current.refreshToken != beforeRefresh.refreshToken) {
            return current;
          }
          await storage.clear();
          return null;
        }
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    try {
      final session = await storage.read();
      if (session != null) await api.logout(session.refreshToken);
    } finally {
      await storage.clear();
    }
  }

  Future<AuthSession> acceptTenantInvite({
    required String inviteCode,
    required String password,
  }) async {
    final session = await api.acceptTenantInvite(
      inviteCode: inviteCode,
      password: password,
    );
    _ensureSupportedRole(session.user);
    await storage.write(session);
    return session;
  }

  Future<AuthSession> acceptStaffInvite({
    required String inviteCode,
    required String password,
  }) async {
    final session = await api.acceptStaffInvite(
      inviteCode: inviteCode,
      password: password,
    );
    _ensureSupportedRole(session.user);
    await storage.write(session);
    return session;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  void _ensureSupportedRole(LandlordUser user) {
    if (user.role != 'landlord' &&
        user.role != 'admin' &&
        user.role != 'tenant' &&
        user.role != 'staff') {
      throw const ApiFailure(
        code: 'ROLE_NOT_ALLOWED',
        message: 'This account cannot access the application.',
        statusCode: 403,
      );
    }
  }

  bool isAdmin(AuthSession session) => session.user.role == 'admin';

  bool isLandlord(AuthSession session) => session.user.role == 'landlord';

  bool isTenant(AuthSession session) => session.user.role == 'tenant';

  bool isStaff(AuthSession session) => session.user.role == 'staff';
}
