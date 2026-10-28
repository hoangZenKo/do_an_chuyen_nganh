import 'package:dio/dio.dart';
import 'dart:convert';

import '../../core/network/api_failure.dart';
import '../../models/admin_models.dart';
import '../../models/admin_inventory.dart';
import '../../models/admin_account_detail.dart';

typedef AdminStepUpPrompt = Future<String?> Function();

class AdminApi {
  const AdminApi(this._dio, {this.ownerId});

  final Dio _dio;
  final String? ownerId;

  Future<Map<String, dynamic>> resource(String path,
      {Map<String, dynamic>? query}) async {
    final response = await _request(() => _dio.get(path,
        queryParameters: query,
        options:
            Options(extra: {if (ownerId != null) 'expectedUserId': ownerId})));
    if (response.data is! Map<String, dynamic>) {
      throw const ApiFailure(message: 'Phản hồi admin không hợp lệ.');
    }
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> command(String path, Map<String, dynamic> data,
      {bool patch = false}) async {
    final options =
        Options(extra: {if (ownerId != null) 'expectedUserId': ownerId});
    final response = await _request(() => patch
        ? _dio.patch(path, data: data, options: options)
        : _dio.post(path, data: data, options: options));
    if (response.data is! Map<String, dynamic>) {
      throw const ApiFailure(message: 'Phản hồi admin không hợp lệ.');
    }
    return response.data as Map<String, dynamic>;
  }

  Future<T> _authorize<T>(
      String path,
      Map<String, dynamic> data,
      String method,
      AdminStepUpPrompt prompt,
      Future<T> Function() first,
      Future<T> Function(String) retry) async {
    try {
      return await first();
    } on ApiFailure catch (error) {
      if (error.code != 'ADMIN_STEP_UP_REQUIRED') rethrow;
      final code = await prompt();
      if (code == null) {
        throw const ApiFailure(
            message: 'Đã hủy xác thực. Chưa thực hiện thao tác.');
      }
      final response = await command('/admin/me/security/step-up', {
        'method': method,
        'path': path,
        'payload': data,
        'code': code,
        'reason': data['reason'] ?? 'Xác thực bổ sung cho thao tác quản trị',
      });
      final token = (response['data'] as Map?)?['token'];
      if (token is! String || token.isEmpty) {
        throw const ApiFailure(
            message: 'Không nhận được xác nhận bảo mật hợp lệ.');
      }
      return retry(token);
    }
  }

  Future<Map<String, dynamic>> authorizedCommand(
      String path, Map<String, dynamic> data,
      {bool patch = false, required AdminStepUpPrompt prompt}) {
    final payload = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    return _authorize(path, payload, patch ? 'PATCH' : 'POST', prompt,
        () => command(path, payload, patch: patch), (token) async {
      final options = Options(headers: {
        'X-Admin-Step-Up': token
      }, extra: {
        if (ownerId != null) 'expectedUserId': ownerId,
      });
      final response = await _request(() => patch
          ? _dio.patch(path, data: payload, options: options)
          : _dio.post(path, data: payload, options: options));
      if (response.data is! Map<String, dynamic>) {
        throw const ApiFailure(message: 'Phản hồi admin không hợp lệ.');
      }
      return response.data as Map<String, dynamic>;
    });
  }

  Future<String> authorizedAuditExport(Map<String, dynamic> filters,
      {required String reason, required AdminStepUpPrompt prompt}) {
    final data = {...filters, 'reason': reason};
    return _authorize('/admin/audit-logs/export', data, 'POST', prompt,
        () => exportAudit(filters, reason: reason), (token) async {
      final response =
          await _request(() => _dio.post('/admin/audit-logs/export',
              data: data,
              options: Options(headers: {
                'X-Admin-Step-Up': token
              }, extra: {
                if (ownerId != null) 'expectedUserId': ownerId,
              })));
      if (response.data is! String) {
        throw const ApiFailure(message: 'Phản hồi CSV không hợp lệ.');
      }
      return response.data as String;
    });
  }

  Future<AdminOverview> overview() async {
    final response = await _request(() => _dio.get('/admin/overview'));
    return AdminOverview.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminCapabilities> capabilities() async {
    final response = await _request(() => _dio.get('/admin/me/capabilities'));
    return AdminCapabilities.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> securityStatus() =>
      resource('/admin/me/security');

  Future<Map<String, dynamic>> supportViews() => resource('/support/views');
  Future<Map<String, dynamic>> saveSupportView(Map<String, dynamic> data,
          {String? id}) =>
      command(id == null ? '/support/views' : '/support/views/$id', data,
          patch: id != null);
  Future<Map<String, dynamic>> supportSkills() => resource('/support/skills');
  Future<Map<String, dynamic>> notificationDeliveryQueue() =>
      resource('/admin/operations/notification-delivery');
  Future<Map<String, dynamic>> financeStatementLines(
          {String? status, String? propertyId}) =>
      resource('/admin/finance/statement-lines', query: {
        if (status != null) 'status': status,
        if (propertyId != null) 'propertyId': propertyId,
      });
  Future<Map<String, dynamic>> financeProposals() =>
      resource('/admin/finance/reconciliation-proposals');
  Future<String> downloadReport(String id) async {
    final response = await _request(() => _dio.get(
        '/admin/report-runs/$id/download',
        options: Options(
            responseType: ResponseType.plain,
            extra: {if (ownerId != null) 'expectedUserId': ownerId})));
    return response.data.toString();
  }

  Future<Map<String, dynamic>> enrollMfa() =>
      command('/admin/me/security/enroll', const {});
  Future<Map<String, dynamic>> confirmMfa(String code) =>
      command('/admin/me/security/confirm', {'code': code});

  Future<AdminPagedResponse<AdminAccount>> accounts({
    int page = 1,
    int limit = 20,
    String? search,
    String? role,
    String status = 'all',
    String? from,
    String? to,
  }) async {
    final response = await _request(() => _dio.get('/admin/accounts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
          if (role != null) 'role': role,
          'status': status,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
        options: Options(extra: {
          if (ownerId != null) 'expectedUserId': ownerId,
        })));
    return AdminPagedResponse.fromJson(response.data, AdminAccount.fromJson);
  }

  Future<AdminAccountDetail> account(String id) async {
    final response = await resource('/admin/accounts/$id');
    return AdminAccountDetail.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  Future<AdminAccount> updateAccountStatus(
    String id, {
    required bool isActive,
    required int version,
    required String reason,
    required AdminStepUpPrompt prompt,
  }) async {
    final response = await authorizedCommand(
        '/admin/accounts/$id/${isActive ? 'restore' : 'suspend'}',
        {'reason': reason, 'version': version},
        prompt: prompt);
    return AdminAccount.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<int> revokeAccountSessions(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    final response = await authorizedCommand(
        '/admin/accounts/$id/revoke-sessions', {'reason': reason},
        prompt: prompt);
    return ((response['data'] as Map)['revokedSessions'] as num?)?.toInt() ?? 0;
  }

  Future<void> resetAccountPassword(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    final response = await authorizedCommand(
        '/admin/accounts/$id/reset-password', {'reason': reason},
        prompt: prompt);
    if ((response['data'] as Map?)?['queued'] != true) {
      throw const ApiFailure(
          message: 'Chưa xác nhận được yêu cầu đặt lại mật khẩu.');
    }
  }

  Future<AdminAccountContacts> revealAccountContacts(String id,
      {required String reason, required AdminStepUpPrompt prompt}) async {
    final response = await authorizedCommand(
        '/admin/accounts/$id/reveal', {'reason': reason},
        prompt: prompt);
    return AdminAccountContacts.fromJson(
        response['data'] as Map<String, dynamic>);
  }

  Future<AdminPagedResponse<AdminAuditEntry>> auditLogs({
    int page = 1,
    int limit = 30,
    String? search,
    String? requestId,
    String? from,
    String? to,
  }) async {
    final response =
        await _request(() => _dio.get('/admin/audit-logs', queryParameters: {
              'page': page,
              'limit': limit,
              if (search?.trim().isNotEmpty == true) 'action': search!.trim(),
              if (requestId?.trim().isNotEmpty == true)
                'requestId': requestId!.trim(),
              if (from != null) 'from': from,
              if (to != null) 'to': to,
            }));
    return AdminPagedResponse.fromJson(response.data, AdminAuditEntry.fromJson);
  }

  Future<String> exportAudit(Map<String, dynamic> filters,
      {required String reason}) async {
    final response = await _request(() => _dio.post('/admin/audit-logs/export',
        data: {
          ...filters,
          'reason': reason,
        },
        options: Options(extra: {
          if (ownerId != null) 'expectedUserId': ownerId,
        })));
    if (response.data is! String) {
      throw const ApiFailure(message: 'Phản hồi CSV không hợp lệ.');
    }
    return response.data as String;
  }

  Future<AdminAnalytics> analytics({int days = 30}) async {
    final response = await _request(() =>
        _dio.get('/admin/analytics/summary', queryParameters: {'days': days}));
    return AdminAnalytics.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminPagedResponse<AdminQueueItem>> moderationQueue(
      {String kind = 'LISTING', int page = 1}) async {
    final response = await _request(() => _dio.get('/admin/moderation/queue',
        queryParameters: {'kind': kind, 'page': page, 'limit': 20}));
    return AdminPagedResponse.fromJson(response.data, AdminQueueItem.fromJson);
  }

  Future<List<AdminLandlordSummary>> listLandlords(
      AdminLandlordsQuery query) async {
    final response = await _request(() => _dio.get(
          '/admin/landlords',
          queryParameters: query.toQuery(),
        ));
    return _parseList(response.data, AdminLandlordSummary.fromJson);
  }

  Future<AdminLandlordRecord> createLandlord({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _request(() => _dio.post('/admin/landlords', data: {
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
        }));
    return AdminLandlordRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordDetail> getLandlord(String id) async {
    final response = await _request(() => _dio.get('/admin/landlords/$id'));
    return AdminLandlordDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordRecord> updateLandlord(
    String id, {
    String? fullName,
    String? phone,
  }) async {
    final response =
        await _request(() => _dio.patch('/admin/landlords/$id', data: {
              if (fullName != null) 'fullName': fullName,
              if (phone != null) 'phone': phone,
            }));
    return AdminLandlordRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminLandlordRecord> updateLandlordStatus(
    String id, {
    required bool isActive,
    String? reason,
    int? version,
    AdminStepUpPrompt? prompt,
  }) async {
    final data = <String, dynamic>{
      'isActive': isActive,
      if (reason != null) 'reason': reason,
      if (version != null) 'version': version,
    };
    final response = prompt == null
        ? await command('/admin/landlords/$id/status', data, patch: true)
        : await authorizedCommand('/admin/landlords/$id/status', data,
            patch: true, prompt: prompt);
    return AdminLandlordRecord.fromJson(response);
  }

  Future<AdminPagedResponse<AdminPropertySummary>> listProperties(
    AdminPropertiesQuery query,
  ) async {
    final response = await _request(() => _dio.get(
          '/admin/properties',
          queryParameters: query.toQuery(),
          options:
              Options(extra: {if (ownerId != null) 'expectedUserId': ownerId}),
        ));
    return AdminPagedResponse.fromJson(
        response.data, AdminPropertySummary.fromJson);
  }

  Future<AdminPagedResponse<AdminRoomSummary>> rooms(
      AdminRoomsQuery query) async {
    final response = await _request(() => _dio.get('/admin/rooms',
        queryParameters: query.toQuery(),
        options:
            Options(extra: {if (ownerId != null) 'expectedUserId': ownerId})));
    return AdminPagedResponse.fromJson(
        response.data, AdminRoomSummary.fromJson);
  }

  Future<AdminPropertySummary> createProperty({
    required String landlordId,
    required String name,
    required String address,
  }) async {
    final response = await _request(() => _dio.post('/admin/properties',
            options: Options(
                extra: {if (ownerId != null) 'expectedUserId': ownerId}),
            data: {
              'landlordId': landlordId,
              'name': name,
              'address': address,
            }));
    return AdminPropertySummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminPropertyDetail> getProperty(String id) async {
    final response = await _request(() => _dio.get('/admin/properties/$id',
        options:
            Options(extra: {if (ownerId != null) 'expectedUserId': ownerId})));
    return AdminPropertyDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AdminPropertyDetail> updateProperty(
    String id, {
    String? name,
    String? address,
  }) async {
    final response = await _request(() => _dio.patch('/admin/properties/$id',
            options: Options(
                extra: {if (ownerId != null) 'expectedUserId': ownerId}),
            data: {
              if (name != null) 'name': name,
              if (address != null) 'address': address,
            }));
    return AdminPropertyDetail.fromJson(response.data as Map<String, dynamic>);
  }

  List<T> _parseList<T>(
    Object? data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data is Map<String, dynamic> && data['data'] is List
        ? data['data'] as List
        : data is List
            ? data
            : const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
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
