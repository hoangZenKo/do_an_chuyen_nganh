import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/operations/operations_api.dart';
import 'package:rental_room_management/models/landlord_notification.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Object body;
  final int status;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

OperationsApi _api(_Adapter adapter) =>
    OperationsApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter);

void main() {
  test('malformed responses become a retryable API failure', () async {
    final adapter = _Adapter(['invalid response']);
    expect(_api(adapter).actionItems(), throwsA(isA<ApiFailure>()));
  });
  test('forwards filters and parses scoped summary, rows and metadata',
      () async {
    final adapter = _Adapter({
      'data': {
        'summary': {
          'total': 40,
          'unread': 30,
          'pendingViewings': 8,
          'openMaintenance': 4
        },
        'categories': ['viewing', 'maintenance'],
        'items': [
          {
            'id': 'viewing-pending-v1',
            'kind': 'viewing_pending',
            'category': 'viewing',
            'propertyId': 'p1',
            'propertyName': 'Khu A',
            'isRead': true,
            'dueAt': '2026-10-24T08:00:00.000Z',
            'actionRoute': '/housing/viewings?viewingId=v1',
          }
        ],
      },
      'meta': {'total': 8, 'page': 2, 'limit': 3},
    });
    final result = await _api(adapter)
        .actionItems(page: 2, limit: 3, category: 'viewing', propertyId: 'p1');
    expect(adapter.request.path, '/operations/action-items');
    expect(adapter.request.queryParameters,
        {'page': 2, 'limit': 3, 'category': 'viewing', 'propertyId': 'p1'});
    expect(result.summary.pendingViewings, 8);
    expect(result.summary.openMaintenance, 4);
    expect(result.categories, ['viewing', 'maintenance']);
    expect(result.items.single.propertyName, 'Khu A');
    expect(result.items.single.isRead, true);
    expect(result.items.single.dueAt, DateTime.utc(2026, 10, 24, 8));
    expect(result.meta.hasNext, true);
    expect(result.meta.page, 2);
  });

  test('default request omits property and supplies bounded pagination',
      () async {
    final adapter = _Adapter({
      'data': {'summary': {}, 'items': []}
    });
    await _api(adapter).actionItems();
    expect(adapter.request.queryParameters,
        {'page': 1, 'limit': 20, 'category': 'all'});
  });

  test('marks read through operation permission endpoint', () async {
    final adapter = _Adapter({'data': {}}, status: 201);
    await _api(adapter).markRead('maintenance-urgent-m1');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path,
        '/operations/action-items/maintenance-urgent-m1/read');
  });

  test('API failures retain the actionable backend message', () async {
    final adapter = _Adapter({
      'error': {'message': 'Không có quyền xem'}
    }, status: 403);
    expect(
        _api(adapter).actionItems(),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 403)));
  });

  test('missing legacy fields remain safe to parse', () {
    final result = ActionItems.fromJson({
      'summary': {'total': '2'},
      'items': [
        {'kind': 'invoice_overdue'}
      ]
    });
    expect(result.summary.total, 2);
    expect(result.summary.pendingViewings, 0);
    expect(result.summary.openMaintenance, 0);
    expect(result.items.single.category, 'invoice');
    expect(result.meta.page, 1);
    expect(result.meta.limit, 20);
    expect(result.meta.hasNext, false);
  });
}
