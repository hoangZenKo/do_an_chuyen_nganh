import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/listings/housing_repository.dart';
import 'package:rental_room_management/models/housing.dart';
import 'listings_api_test.dart' show RecordingListingsAdapter;

void main() {
  HousingRepository repository(RecordingListingsAdapter adapter) =>
      HousingRepository(Dio()..httpClientAdapter = adapter);
  test('favorites use account endpoints and idempotent PUT / DELETE', () async {
    final adapter = RecordingListingsAdapter({
      'data': {'saved': true}
    });
    final api = repository(adapter);
    expect(await api.isSaved('room/id'), isTrue);
    expect(adapter.request.path, '/housing/favorites/room%2Fid');
    await api.saveFavorite('room-1', true);
    expect(adapter.request.method, 'PUT');
    await api.saveFavorite('room-1', false);
    expect(adapter.request.method, 'DELETE');
  });
  test('booking transmits a UTC instant and trims notes', () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    final date = DateTime(2026, 11, 2, 10, 30);
    await repository(adapter).book('listing-1', date, '  Bring a friend  ');
    expect(adapter.request.path, '/housing/viewings');
    expect(adapter.request.data, {
      'listingId': 'listing-1',
      'scheduledAt': date.toUtc().toIso8601String(),
      'note': 'Bring a friend'
    });
  });
  test('slot booking and handover mutations preserve optimistic versions',
      () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    final api = repository(adapter);
    final date = DateTime(2026, 11, 2, 10, 30);
    await api.bookSlot('listing-1', date, ' note ', 'slot-1');
    expect(adapter.request.data, {
      'listingId': 'listing-1',
      'scheduledAt': date.toUtc().toIso8601String(),
      'note': 'note',
      'slotId': 'slot-1'
    });
    await api.saveHandover('lease/1', 2, 1234, 89, ' Existing scratch ',
        ['/uploads/condition.png']);
    expect(adapter.request.path, '/housing/leases/lease%2F1/handover');
    expect(adapter.request.method, 'PUT');
    expect(adapter.request.data, {
      'version': 2,
      'electricity': 1234,
      'water': 89,
      'condition': 'Existing scratch',
      'imageUrls': ['/uploads/condition.png']
    });
    await api.acceptHandover('lease/1', 3);
    expect(adapter.request.data, {'version': 3});
  });
  test('viewing transitions carry the last-read version', () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    final viewing = RoomViewing(
        id: 'visit-1',
        listingId: 'listing-1',
        title: 'Room',
        studentName: 'Student',
        landlordName: 'Landlord',
        address: 'Address',
        status: 'COMPLETED',
        version: 3,
        scheduledAt: DateTime(2026, 11, 2),
        rent: 2500000,
        deposit: 2000000);
    final api = repository(adapter);
    await api.updateViewing(viewing, 'CANCELLED', ' Changed plans ');
    expect(adapter.request.method, 'PATCH');
    expect(adapter.request.data,
        {'version': 3, 'status': 'CANCELLED', 'note': 'Changed plans'});
    await api.createLease(viewing, DateTime(2026, 11, 3), 2400000, 1000000);
    expect(adapter.request.path, '/housing/viewings/visit-1/lease');
    expect(adapter.request.data, {
      'version': 3,
      'startDate': '2026-11-03T00:00:00.000Z',
      'monthlyRent': 2400000,
      'deposit': 1000000
    });
  });
  test(
      'page parsing preserves unavailable favorites and requests the next page',
      () async {
    final adapter = RecordingListingsAdapter({
      'data': [
        {
          'id': 'saved-1',
          'title': 'Old room',
          'publicAddress': 'Road',
          'district': 'District',
          'city': 'City',
          'monthlyRent': 2000000,
          'available': false
        }
      ],
      'meta': {'page': 2, 'limit': 20, 'total': 45}
    });
    final page = await repository(adapter).favorites(2);
    expect(adapter.request.queryParameters, {'page': 2});
    expect(page.items.single.available, isFalse);
    expect(page.hasNext, isTrue);
  });
  test('maps validation and conflict responses to recoverable failures',
      () async {
    final adapter = RecordingListingsAdapter(
        {'message': 'Lịch đã thay đổi. Hãy tải lại.'},
        status: 409);
    await expectLater(
        repository(adapter).isSaved('x'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.message, 'message', contains('tải lại'))));
    final invalid = RecordingListingsAdapter({
      'message': ['rating must be at most 5']
    }, status: 400);
    await expectLater(
        repository(invalid).isSaved('x'),
        throwsA(isA<ApiFailure>()
            .having((error) => error.message, 'message', contains('rating'))));
  });
  test(
      'pilot feedback uses server-provided area without introducing an invitation side effect',
      () async {
    final adapter = RecordingListingsAdapter({'data': {}});
    await repository(adapter).feedback(
        const RentalPilot(enabled: true, area: 'Test district'),
        'viewing',
        4,
        '  Good workflow  ');
    expect(adapter.request.path, '/housing/feedback');
    expect(adapter.request.data, {
      'area': 'Test district',
      'stage': 'viewing',
      'rating': 4,
      'detail': 'Good workflow'
    });
  });
}
