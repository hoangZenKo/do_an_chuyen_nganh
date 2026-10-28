import 'package:dio/dio.dart';

import '../../core/network/api_failure.dart';
import '../../models/expense.dart';

class ExpenseApi {
  const ExpenseApi(this._dio);

  final Dio _dio;

  Future<ExpenseListResult> list({
    String? propertyId,
    String? roomId,
    ExpenseCategory? category,
    String? month,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/expenses',
        queryParameters: {
          if (propertyId != null) 'propertyId': propertyId,
          if (roomId != null) 'roomId': roomId,
          if (category != null) 'category': category.name,
          if (month != null) 'month': month,
        },
      ),
    );
    return ExpenseListResult.fromJson(response.data);
  }

  Future<Expense> getById(String id) async {
    final response = await _request(() => _dio.get('/expenses/$id'));
    return Expense.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Expense> create(Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.post('/expenses', data: payload),
    );
    return Expense.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Expense> update(String id, Map<String, dynamic> payload) async {
    final response = await _request(
      () => _dio.patch('/expenses/$id', data: payload),
    );
    return Expense.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _request(() => _dio.delete('/expenses/$id'));
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
