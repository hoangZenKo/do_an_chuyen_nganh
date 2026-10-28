import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rental_room_management/data/dashboard/dashboard_api.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final ResponseBody response;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('metrics requests dashboard endpoint and parses the data envelope',
      () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        '''
        {
          "data": {
            "propertyId": "p1",
            "generatedAt": "2026-08-06T10:00:00.000Z",
            "roomStats": {
              "total": 3,
              "occupied": 2,
              "vacant": 1,
              "maintenance": 0,
              "occupancyRate": 67
            },
            "leaseStats": { "active": 2 },
            "currentMonth": {
              "invoiceCount": 2,
              "billedAmount": 7000000,
              "receivedAmount": 3500000,
              "outstandingInvoiceCount": 1,
              "outstandingAmount": 3500000
            },
            "revenueTrend": [
              { "month": "2026-07-01T00:00:00.000Z", "amount": 0 },
              { "month": "2026-08-01T00:00:00.000Z", "amount": 3500000 }
            ],
            "attentionItems": [
              {
                "kind": "overdue_invoice",
                "roomId": "r1",
                "roomName": "201",
                "tenantId": "t1",
                "tenantName": "Nguyễn Văn A",
                "invoiceId": "i1",
                "remainingAmount": 3500000,
                "dueDate": "2026-08-01T00:00:00.000Z"
              }
            ],
            "recentInvoices": [
              {
                "id": "i2",
                "roomId": "r2",
                "roomName": "101",
                "tenantId": "t2",
                "tenantName": "Nguyễn Văn B",
                "billingMonth": "2026-08-01T00:00:00.000Z",
                "totalAmount": 3500000,
                "paidAmount": 3500000,
                "remainingAmount": 0,
                "status": "paid",
                "dueDate": "2026-08-10T00:00:00.000Z",
                "issuedAt": "2026-08-05T00:00:00.000Z"
              }
            ]
          }
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter;

    final metrics =
        await DashboardApi(dio).metrics(propertyId: 'p1', months: 2);

    expect(adapter.request.path, '/dashboard/metrics');
    expect(adapter.request.queryParameters, {'propertyId': 'p1', 'months': 2});
    expect(metrics.roomStats.occupied, 2);
    expect(metrics.currentMonth.outstandingAmount, 3500000);
    expect(metrics.revenueTrend.last.amount, 3500000);
    expect(metrics.attentionItems.single.invoiceId, 'i1');
    expect(metrics.recentInvoices.single.status.name, 'paid');
  });
}
