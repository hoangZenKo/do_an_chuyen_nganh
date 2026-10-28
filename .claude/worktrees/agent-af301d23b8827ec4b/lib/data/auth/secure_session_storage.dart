import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_models.dart';

class SecureSessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessToken = 'auth.access_token';
  static const _refreshToken = 'auth.refresh_token';
  static const _accessExpires = 'auth.access_expires_at';
  static const _refreshExpires = 'auth.refresh_expires_at';
  static const _userId = 'auth.user_id';
  static const _fullName = 'auth.full_name';
  static const _email = 'auth.email';
  static const _phone = 'auth.phone';
  static const _role = 'auth.role';

  final FlutterSecureStorage _storage;

  Future<void> write(AuthSession session) async {
    await _storage.write(key: _accessToken, value: session.accessToken);
    await _storage.write(key: _refreshToken, value: session.refreshToken);
    await _storage.write(
      key: _accessExpires,
      value: session.accessTokenExpiresAt?.toIso8601String(),
    );
    await _storage.write(
      key: _refreshExpires,
      value: session.refreshTokenExpiresAt?.toIso8601String(),
    );
    await _storage.write(key: _userId, value: session.user.id);
    await _storage.write(key: _fullName, value: session.user.fullName);
    await _storage.write(key: _email, value: session.user.email);
    await _storage.write(key: _phone, value: session.user.phone);
    await _storage.write(key: _role, value: session.user.role);
  }

  Future<AuthSession?> read() async {
    final values = await _storage.readAll();
    final access = values[_accessToken];
    final refresh = values[_refreshToken];
    final id = values[_userId];
    final name = values[_fullName];
    final email = values[_email];
    if ([access, refresh, id, name, email].any((value) => value == null)) {
      return null;
    }

    return AuthSession(
      accessToken: access!,
      refreshToken: refresh!,
      accessTokenExpiresAt: _parse(values[_accessExpires]),
      refreshTokenExpiresAt: _parse(values[_refreshExpires]),
      user: LandlordUser(
        id: id!,
        fullName: name!,
        email: email!,
        phone: values[_phone],
        role: values[_role] ?? 'landlord',
      ),
    );
  }

  Future<void> clear() async {
    for (final key in const [
      _accessToken,
      _refreshToken,
      _accessExpires,
      _refreshExpires,
      _userId,
      _fullName,
      _email,
      _phone,
      _role,
    ]) {
      await _storage.delete(key: key);
    }
  }

  DateTime? _parse(String? value) =>
      value == null ? null : DateTime.tryParse(value);
}
