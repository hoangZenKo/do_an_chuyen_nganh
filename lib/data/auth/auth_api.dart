import 'package:dio/dio.dart';

import '../../models/auth_models.dart';
import '../../core/network/api_failure.dart';

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<String> requestPasswordReset(String email) async {
    final response = await _request(
        () => _dio.post('/auth/account-access/forgot', data: {'email': email}));
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as Map<String, dynamic>)['message'] as String;
  }

  Future<void> redeemAccountAccess(String token, String password) async {
    await _request(() => _dio.post('/auth/account-access/redeem',
        data: {'token': token, 'password': password}));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    final response = await _request(
      () => _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        if (mfaCode?.trim().isNotEmpty == true) 'mfaCode': mfaCode!.trim(),
      }),
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    bool seeker = false,
  }) async {
    final response = await _request(
      () =>
          _dio.post(seeker ? '/auth/register-seeker' : '/auth/register', data: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _request(
      () => _dio.post('/auth/refresh', data: {'refreshToken': refreshToken}),
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> acceptTenantInvite({
    required String inviteCode,
    required String password,
  }) async {
    final response = await _request(
      () => _dio.post('/tenant-invites/accept', data: {
        'inviteCode': inviteCode,
        'password': password,
      }),
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> acceptStaffInvite({
    required String inviteCode,
    required String password,
  }) async {
    final response = await _request(
      () => _dio.post('/staff/invites/accept', data: {
        'inviteCode': inviteCode,
        'password': password,
      }),
    );
    return AuthSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      () => _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
  }

  Future<LandlordUser> me() async {
    final response = await _request(() => _dio.get('/auth/me'));
    final data = response.data as Map<String, dynamic>;
    final user = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return LandlordUser.fromJson(user);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
    } on DioException {
      // Local credentials are cleared by the repository regardless of network
      // availability, so logout remains safe when the API is offline.
    }
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
        statusCode: error.response?.statusCode,
        data: error.response?.data,
      );
    } on TypeError {
      throw const ApiFailure(
          message: 'The server returned an invalid response.');
    }
  }
}
