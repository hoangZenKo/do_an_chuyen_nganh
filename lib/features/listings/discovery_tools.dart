import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_failure.dart';
import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';
import '../auth/auth_providers.dart';

class DiscoveryToolsApi {
  const DiscoveryToolsApi(this.client);
  final Dio client;
  Future<dynamic> request(String path,
      {String method = 'GET',
      Object? data,
      Map<String, dynamic>? query}) async {
    try {
      return (await client.request<dynamic>(path,
              data: data,
              queryParameters: query,
              options: Options(method: method)))
          .data;
    } on DioException catch (error) {
      throw ApiFailure.fromResponse(
          statusCode: error.response?.statusCode, data: error.response?.data);
    } on TypeError {
      throw const ApiFailure(
          message: 'Dữ liệu phản hồi không hợp lệ. Hãy thử tải lại.');
    }
  }

  Future<List<Map<String, dynamic>>> searches() async =>
      ((await request('/student/searches'))['data'] as List)
          .cast<Map<String, dynamic>>();
  Future<void> save(String name, ListingQuery query) async {
    final filters = query.toQuery()
      ..remove('page')
      ..remove('limit');
    await request('/student/searches',
        method: 'POST', data: {'name': name, 'filters': filters});
  }

  Future<void> status(String id, bool enabled) async {
    await request('/student/searches/$id',
        method: 'PATCH', data: {'enabled': enabled});
  }

  Future<void> remove(String id) async {
    await request('/student/searches/$id', method: 'DELETE');
  }

  Future<Map<String, dynamic>> alerts(int page) async =>
      (await request('/student/searches/alerts', query: {'page': page}))
          as Map<String, dynamic>;
  Future<void> read(String id) async {
    await request('/student/searches/alerts/$id/read', method: 'POST');
  }

  Future<List<SchoolCampus>> campuses() async =>
      ((await request('/admin/campuses'))['data'] as List)
          .map((item) => SchoolCampus.fromJson(item as Map<String, dynamic>))
          .toList();
  Future<void> campus(Map<String, dynamic> data, String? id) async {
    await request('/admin/campuses${id == null ? '' : '/$id'}',
        method: id == null ? 'POST' : 'PATCH', data: data);
  }
}

final discoveryToolsProvider =
    Provider((ref) => DiscoveryToolsApi(ref.watch(sessionDioProvider).client));
final savedSearchesProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(discoveryToolsProvider).searches());
final searchAlertsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>(
        (ref, page) => ref.watch(discoveryToolsProvider).alerts(page));
final adminCampusesProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(discoveryToolsProvider).campuses());
