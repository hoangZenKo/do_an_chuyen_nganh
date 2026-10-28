import '../../models/property.dart';
import '../../models/room.dart';
import 'property_api.dart';
import 'room_api.dart';

/// Thin coordinator over [PropertyApi] and [RoomApi], mirroring
/// `AuthRepository`. Keeps UI/state layers free of raw Dio concerns.
class RoomRepository {
  const RoomRepository({required this.propertyApi, required this.roomApi});

  final PropertyApi propertyApi;
  final RoomApi roomApi;

  Future<List<Property>> properties({String? lifecycle}) =>
      propertyApi.list(lifecycle: lifecycle);

  Future<Property> property(String id) => propertyApi.getById(id);

  Future<Property> createProperty({
    required String name,
    String? address,
  }) {
    return propertyApi.create(
      name: name,
      address: address?.trim() ?? '',
    );
  }

  Future<Property> updateProperty(
    String id, {
    String? name,
    String? address,
  }) {
    return propertyApi.update(id, name: name, address: address);
  }

  Future<Property> setPropertyArchived(String id, bool isArchived) =>
      propertyApi.setArchived(id, isArchived);

  Future<void> deleteProperty(String id) => propertyApi.delete(id);

  Future<List<Room>> roomsOf(String propertyId, {String? lifecycle}) =>
      roomApi.listByProperty(propertyId, lifecycle: lifecycle);

  Future<Room> room(String id) => roomApi.getById(id);

  Future<Room> createRoom(String propertyId, Room room) =>
      roomApi.create(propertyId, room.toPayload());

  Future<Room> updateRoom(Room room) =>
      roomApi.update(room.id, room.toPayload());

  Future<Room> setRoomActive(String id, bool isActive) =>
      roomApi.setActive(id, isActive);

  Future<void> deleteRoom(String id) => roomApi.delete(id);
}
