import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../../data/auth/secure_session_storage.dart';
import '../../data/auth/token_refresh_coordinator.dart';

Dio createApiClient(
  SecureSessionStorage storage, {
  Future<void> Function()? onSessionInvalid,
  Dio? refreshClient,
}) {
  final dio = Dio(_baseOptions());
  final refreshDio = refreshClient ?? Dio(_baseOptions());
  final refreshCoordinator = TokenRefreshCoordinator(
    storage: storage,
    refreshClient: refreshDio,
    onSessionInvalid: onSessionInvalid,
  );

  const publicAuthPaths = {
    '/auth/login',
    '/auth/register',
    '/auth/register-seeker',
    '/auth/refresh',
    '/auth/logout',
    '/auth/account-access/forgot',
    '/auth/account-access/redeem',
  };

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requestPath = Uri.parse(options.path).path;
        if (!publicAuthPaths.contains(requestPath)) {
          final session = await storage.read();
          final expectedUser = options.extra['expectedUserId'];
          if (expectedUser != null && session?.user.id != expectedUser) {
            handler.reject(DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Phiên đăng nhập đã thay đổi.'));
            return;
          }
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final requestPath = Uri.parse(error.requestOptions.path).path;
        final alreadyRetried = error.requestOptions.extra['authRetry'] == true;
        final isProtected = !publicAuthPaths.contains(requestPath);

        if (error.response?.statusCode != 401 ||
            !isProtected ||
            alreadyRetried) {
          handler.next(error);
          return;
        }

        try {
          final session = await refreshCoordinator.refresh();
          if (session == null) {
            handler.next(error);
            return;
          }

          final request = error.requestOptions;
          request.extra['authRetry'] = true;
          request.headers['Authorization'] = 'Bearer ${session.accessToken}';
          final response = await dio.fetch(request);
          handler.resolve(response);
        } on DioException {
          // Preserve the original protected request failure. AuthApi will map
          // it to the existing error contract, while storage is cleared by the
          // coordinator only when the refresh endpoint explicitly rejects the
          // refresh token.
          handler.next(error);
        } catch (_) {
          handler.next(error);
        }
      },
    ),
  );
  return dio;
}

BaseOptions _baseOptions() => BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
