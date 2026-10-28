import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';

class UploadApi {
  const UploadApi(this._dio);

  final Dio _dio;

  Future<String> uploadFile(String path, {bool publicListing = false}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path),
      'purpose': publicListing ? 'PUBLIC_LISTING' : 'PRIVATE',
    });
    final response = await _request(
      () => _dio.post(
        '/uploads',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : const <String, dynamic>{};
    final payload = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    return payload['url']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> uploadSupportAttachment(
      String ticketId, String path, int version,
      {bool internal = false}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path,
          contentType:
              DioMediaType.parse(switch (path.split('.').last.toLowerCase()) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            'pdf' => 'application/pdf',
            _ => 'application/octet-stream'
          })),
      'version': '$version',
      'internal': '$internal',
    });
    final response = await _request(() => _dio.post(
          '/support/tickets/$ticketId/attachments',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        ));
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<String> accessUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const ApiFailure(message: 'Liên kết file không hợp lệ.');
    }
    if (!uri.path.startsWith('/uploads/')) return url;
    final filename = uri.pathSegments.last;
    final response = await _request(
        () => _dio.get('/uploads/${Uri.encodeComponent(filename)}/access'));
    final path = response.data['data']['url'] as String;
    return Uri.parse(_dio.options.baseUrl).resolve(path).toString();
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
        message: 'The server returned an invalid response.',
      );
    }
  }
}
