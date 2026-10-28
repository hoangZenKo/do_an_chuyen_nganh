import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/admin/admin_api.dart';
import 'package:rental_room_management/models/admin_models.dart';
import 'package:rental_room_management/models/admin_inventory.dart';

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  Object body = {
    'data': [],
    'meta': {'page': 2, 'limit': 20, 'total': 25, 'pages': 2}
  };
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
      'property reads and mutations remain bound to the original session owner',
      () async {
    final adapter = _Adapter()
      ..body = {
        'data': {'id': 'property', 'name': 'Building', 'rooms': []}
      };
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'operator');
    await api.getProperty('property');
    expect(adapter.request.extra['expectedUserId'], 'operator');
    await api.createProperty(
        landlordId: 'owner', name: 'Building', address: 'Address');
    expect(adapter.request.extra['expectedUserId'], 'operator');
    await api.updateProperty('property', name: 'Updated');
    expect(adapter.request.extra['expectedUserId'], 'operator');
  });
  test('property page retains server metadata and owner binding', () async {
    final adapter = _Adapter();
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'operator');
    final result = await api.listProperties(const AdminPropertiesQuery(
        page: 2,
        search: '  Building  ',
        archived: 'archived',
        ownerStatus: 'inactive'));
    expect(adapter.request.path, '/admin/properties');
    expect(adapter.request.extra['expectedUserId'], 'operator');
    expect(adapter.request.queryParameters, {
      'page': 2,
      'limit': 20,
      'search': 'Building',
      'archived': 'archived',
      'ownerStatus': 'inactive'
    });
    expect(result.total, 25);
    expect(result.pages, 2);
  });

  test(
      'rooms serialize only applied filters and distinguish internal vs advertised rent',
      () async {
    final adapter = _Adapter()
      ..body = {
        'data': [
          {
            'id': 'room',
            'name': 'A.101',
            'status': 'VACANT',
            'isActive': false,
            'basePrice': 3500000,
            'floor': 2,
            'areaSqm': 24,
            'property': {
              'id': 'property',
              'name': 'Building',
              'address': 'Address',
              'isArchived': true,
              'landlord': {
                'id': 'owner',
                'fullName': 'Owner',
                'email': 'o***@example.test',
                'phone': '***123',
                'isActive': false
              }
            },
            'listing': {
              'id': 'listing',
              'title': 'Room listing',
              'status': 'PENDING',
              'version': 3,
              'monthlyRent': 4000000
            },
          }
        ],
        'meta': {'page': 2, 'limit': 20, 'total': 21, 'pages': 2}
      };
    final api =
        AdminApi(Dio()..httpClientAdapter = adapter, ownerId: 'operator');
    final page = await api.rooms(const AdminRoomsQuery(
        page: 2,
        propertyId: 'property',
        search: '  A.101 ',
        status: 'VACANT',
        activity: 'inactive',
        minPrice: 0,
        maxPrice: 5000000,
        listingStatus: 'PENDING'));
    expect(adapter.request.path, '/admin/rooms');
    expect(adapter.request.extra['expectedUserId'], 'operator');
    expect(adapter.request.queryParameters, {
      'page': 2,
      'limit': 20,
      'propertyId': 'property',
      'search': 'A.101',
      'status': 'VACANT',
      'activity': 'inactive',
      'minPrice': 0,
      'maxPrice': 5000000,
      'listingStatus': 'PENDING'
    });
    expect(page.data.single.basePrice, 3500000);
    expect(page.data.single.listing?.monthlyRent, 4000000);
    expect(page.data.single.property.isArchived, isTrue);
    expect(page.total, 21);
    expect(const AdminRoomsQuery().toQuery(), {'page': 1, 'limit': 20});
  });

  test('query identity includes all filters and supports explicit clearing',
      () {
    const original = AdminRoomsQuery(
        page: 3,
        minPrice: 1,
        maxPrice: 4,
        propertyId: 'property',
        listingStatus: 'NONE');
    expect(original, isNot(original.copyWith(page: 1)));
    expect(original.copyWith(clearPrices: true).minPrice, isNull);
    expect(original.copyWith(clearProperty: true).propertyId, isNull);
    expect(
        original
            .copyWith(listingStatus: 'all')
            .toQuery()
            .containsKey('listingStatus'),
        isFalse);
  });
}
