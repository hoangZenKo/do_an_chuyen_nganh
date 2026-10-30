import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/maintenance/maintenance_api.dart';
import 'package:rental_room_management/data/maintenance/maintenance_repository.dart';
import 'package:rental_room_management/models/maintenance.dart';

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'id': 'ticket',
            'title': 'Repair',
            'status': 'open',
            'priority': 'medium',
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('editing can explicitly clear description and internal note', () async {
    final adapter = _Adapter();
    final repository = MaintenanceRepository(
        MaintenanceApi(Dio()..httpClientAdapter = adapter));
    await repository.update('ticket',
        propertyId: 'property',
        roomId: 'room',
        status: MaintenanceStatus.open,
        priority: MaintenancePriority.medium,
        title: 'Repair',
        description: '',
        note: '   ');
    expect(adapter.request.data['description'], '');
    expect(adapter.request.data['note'], '');
  });
}
