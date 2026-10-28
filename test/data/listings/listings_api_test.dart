import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/auth/auth_api.dart';
import 'package:rental_room_management/data/listings/listings_api.dart';
import 'package:rental_room_management/models/room_listing.dart';

const listingJson = <String, dynamic>{
  'id': 'l1',
  'title': 'Phòng có ban công',
  'description': 'Phòng sáng, thoáng và có lối đi riêng.',
  'imageUrls': <String>[],
  'city': 'TP.HCM',
  'district': 'Bình Thạnh',
  'publicAddress': 'Đường D2',
  'monthlyRent': 2500000,
  'deposit': 2500000,
  'electricityPrice': 3500,
  'waterPrice': 15000,
  'serviceFee': 100000,
  'areaSqm': 25,
  'amenities': ['WC riêng'],
  'propertyName': 'Trọ An Bình',
};

class RecordingListingsAdapter implements HttpClientAdapter {
  RecordingListingsAdapter(this.body,
      {this.status = 200, this.timeout = false});
  final Object body;
  final int status;
  final bool timeout;
  late RequestOptions request;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    if (timeout) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    }
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  ListingsApi api(RecordingListingsAdapter adapter) =>
      ListingsApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter);

  test('student endpoints use dedicated public and protected contracts',
      () async {
    final campusAdapter = RecordingListingsAdapter({
      'data': [
        {
          'id': 'c1',
          'name': 'School',
          'campus': 'Main',
          'city': 'Test',
          'isDemo': true
        }
      ]
    });
    final campuses = await api(campusAdapter).campuses();
    expect(campusAdapter.request.path, '/public/campuses');
    expect(campuses.single.isDemo, isTrue);
    final reportAdapter = RecordingListingsAdapter({
      'data': {'id': 'r1', 'status': 'OPEN'}
    });
    await api(reportAdapter)
        .report('l1', reason: 'wrong_price', detail: 'Price does not match.');
    expect(reportAdapter.request.path, '/student/listings/l1/reports');
    expect(reportAdapter.request.data,
        {'reason': 'wrong_price', 'detail': 'Price does not match.'});
    final reviewAdapter = RecordingListingsAdapter({'data': {}});
    await api(reviewAdapter)
        .reviewReport('r1', 'DISMISSED', 'Checked with landlord.');
    expect(reviewAdapter.request.path, '/admin/listings/reports/r1/review');
    expect(reviewAdapter.request.data['status'], 'DISMISSED');
    final verificationAdapter = RecordingListingsAdapter({'data': {}});
    await api(verificationAdapter).verify(
        RoomListing.fromJson({...listingJson, 'version': 3}),
        landlordVerified: true,
        roomInspected: false,
        note: 'Ownership evidence checked.');
    expect(verificationAdapter.request.path, '/admin/listings/l1/verification');
    expect(verificationAdapter.request.data, {
      'version': 3,
      'landlordVerified': true,
      'roomInspected': false,
      'note': 'Ownership evidence checked.',
    });
  });
  test('browse serializes filters and parses pagination', () async {
    final adapter = RecordingListingsAdapter({
      'data': [listingJson],
      'meta': {'total': 15, 'page': 1, 'limit': 12}
    });
    final page = await api(adapter).browse(const ListingQuery(
        search: ' ban công ',
        minPrice: 1000000,
        minArea: 20,
        city: 'TP.HCM',
        amenity: 'WC riêng'));
    expect(adapter.request.path, '/public/listings');
    expect(adapter.request.queryParameters['search'], 'ban công');
    expect(adapter.request.queryParameters['minArea'], 20);
    expect(page.items.single.areaSqm, 25.0);
    expect(page.hasNext, isTrue);
    expect(page.items.single.propertyName, 'Trọ An Bình');
  });

  test('detail and management parse their separate contracts', () async {
    final detail = RecordingListingsAdapter({'data': listingJson});
    expect((await api(detail).detail('l1')).id, 'l1');
    expect(detail.request.path, '/public/listings/l1');
    final management = RecordingListingsAdapter({
      'data': [
        {...listingJson, 'roomId': 'r1', 'status': 'PENDING', 'version': 3}
      ],
      'meta': {'total': 1, 'page': 1, 'limit': 12}
    });
    final page =
        await api(management).manage(admin: true, page: 1, status: 'PENDING');
    expect(management.request.path, '/admin/listings');
    expect(management.request.queryParameters['status'], 'PENDING');
    expect(page.items.single.version, 3);
    expect(page.hasNext, isFalse);
  });

  test('mutations send version and preserve server-side ownership', () async {
    final adapter = RecordingListingsAdapter({});
    final listing = RoomListing.fromJson({...listingJson, 'version': 4});
    await api(adapter).action(listing, 'REJECT', note: 'Thiếu ảnh');
    expect(adapter.request.path, '/admin/listings/l1/review');
    expect(adapter.request.data,
        {'version': 4, 'decision': 'REJECT', 'note': 'Thiếu ảnh'});
    await api(adapter).action(listing, 'submit');
    expect(adapter.request.path, '/listings/l1/submit');
    expect(adapter.request.data, {'version': 4});
    await api(adapter).save({...listing.content, 'roomId': 'r1'});
    expect(adapter.request.method, 'POST');
    expect(adapter.request.path, '/listings');
    await api(adapter).save({...listing.content, 'version': 4}, id: 'l1');
    expect(adapter.request.method, 'PATCH');
  });

  test('invalid data is rejected rather than becoming a fake empty result',
      () async {
    final adapter = RecordingListingsAdapter({'data': [], 'meta': 'invalid'});
    await expectLater(
        api(adapter).browse(const ListingQuery()), throwsA(isA<ApiFailure>()));
    await expectLater(
        api(RecordingListingsAdapter({
          'data': {'id': 'l1'}
        })).detail('l1'),
        throwsA(isA<ApiFailure>()));
  });

  test('timeout, not found and conflict keep useful error information',
      () async {
    await expectLater(
        api(RecordingListingsAdapter({}, timeout: true))
            .browse(const ListingQuery()),
        throwsA(isA<ApiFailure>()
            .having((error) => error.message, 'message', contains('quá hạn'))));
    for (final status in [404, 409]) {
      await expectLater(
          api(RecordingListingsAdapter({'message': 'Tin đã thay đổi'},
                  status: status))
              .detail('l1'),
          throwsA(isA<ApiFailure>()
              .having((error) => error.statusCode, 'statusCode', status)));
    }
  });

  test('seeker registration uses a dedicated endpoint, not a client role field',
      () async {
    final adapter = RecordingListingsAdapter({
      'data': {
        'user': {
          'id': 'u1',
          'fullName': 'Seeker',
          'email': 'user@example.com',
          'role': 'tenant'
        },
        'accessToken': 'a',
        'refreshToken': 'r'
      }
    });
    final auth = AuthApi(Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
      ..httpClientAdapter = adapter);
    final session = await auth.register(
        fullName: 'Seeker',
        email: 'user@example.com',
        phone: '+84901234567',
        password: 'StrongPassword!123',
        seeker: true);
    expect(session.user.role, 'tenant');
    expect(adapter.request.path, '/auth/register-seeker');
    expect(adapter.request.data, isNot(contains('role')));
    await auth.register(
        fullName: 'Owner',
        email: 'owner@example.com',
        phone: '+84901234567',
        password: 'StrongPassword!123');
    expect(adapter.request.path, '/auth/register');
  });
}
