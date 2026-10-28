import 'package:dio/dio.dart';

import '../../models/auth_models.dart';
import 'secure_session_storage.dart';

/// Coordinates access-token refreshes so concurrent 401 responses share one
/// refresh request and the rotated token pair is stored exactly once.
class TokenRefreshCoordinator {
  TokenRefreshCoordinator({
    required this.storage,
    required this.refreshClient,
    this.onSessionInvalid,
  });

  final SecureSessionStorage storage;
  final Dio refreshClient;
  final Future<void> Function()? onSessionInvalid;
  Future<AuthSession?>? _inFlight;

  Future<AuthSession?> refresh() {
    final current = _inFlight;
    if (current != null) return current;

    final future = _refreshOnce();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<AuthSession?> _refreshOnce() async {
    final stored = await storage.read();
    if (stored == null) return null;

    try {
      final response = await refreshClient.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': stored.refreshToken},
      );
      final session =
          AuthSession.fromJson(response.data as Map<String, dynamic>);
      await storage.write(session);
      return session;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await storage.clear();
        await onSessionInvalid?.call();
        return null;
      }
      rethrow;
    }
  }
}
