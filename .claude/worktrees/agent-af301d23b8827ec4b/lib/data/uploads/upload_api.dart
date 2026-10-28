import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';

class UploadApi {
  const UploadApi(this._dio);

  final Dio _dio;

  Future<String> uploadFile(String path) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path),
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
