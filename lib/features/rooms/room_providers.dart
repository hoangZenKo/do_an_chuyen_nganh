import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/rooms/property_api.dart';
import '../../data/rooms/room_api.dart';
import '../../data/rooms/room_repository.dart';
import '../../models/property.dart';
import '../../models/room.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import 'property_selection_provider.dart';

export 'property_selection_provider.dart';

// ── Dependency injection ──────────────────────────────────────────────────────

final propertyApiProvider = Provider<PropertyApi>((ref) {
  return PropertyApi(ref.watch(sessionDioProvider).client);
});

final roomApiProvider = Provider<RoomApi>((ref) {
  return RoomApi(ref.watch(sessionDioProvider).client);
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(
    propertyApi: ref.watch(propertyApiProvider),
    roomApi: ref.watch(roomApiProvider),
  );
});

// ── Property selection ────────────────────────────────────────────────────────

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final properties = await ref.watch(roomRepositoryProvider).properties();
  final selected = ref.read(selectedPropertyProvider);
  if (properties.isNotEmpty) {
    final nextSelection = properties.any((property) => property.id == selected)
        ? selected
        : properties.first.id;
    if (selected != nextSelection) {
      Future.microtask(
        () => ref.read(selectedPropertyProvider.notifier).state = nextSelection,
      );
    }
  } else if (selected != null) {
    Future.microtask(
      () => ref.read(selectedPropertyProvider.notifier).state = null,
    );
  }
  return properties;
});

final archivedPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  return ref.watch(roomRepositoryProvider).properties(lifecycle: 'archived');
});

// ── Rooms of a property ───────────────────────────────────────────────────────

final roomsProvider =
    FutureProvider.family<List<Room>, String>((ref, propertyId) async {
  return ref.watch(roomRepositoryProvider).roomsOf(propertyId);
});

final inactiveRoomsProvider =
    FutureProvider.family<List<Room>, String>((ref, propertyId) async {
  return ref.watch(roomRepositoryProvider).roomsOf(
        propertyId,
        lifecycle: 'inactive',
      );
});

final roomDetailProvider =
    FutureProvider.family<Room, String>((ref, roomId) async {
  return ref.watch(roomRepositoryProvider).room(roomId);
});

final roomAssetsProvider =
    FutureProvider.family<List<RoomAsset>, String>((ref, roomId) {
  return ref.watch(roomApiProvider).assets(roomId);
});

final roomInspectionsProvider =
    FutureProvider.family<List<RoomInspection>, String>((ref, roomId) {
  return ref.watch(roomApiProvider).inspections(roomId);
});

final roomServiceFeesProvider =
    FutureProvider.family<List<RoomServiceFee>, String>((ref, roomId) {
  return ref.watch(roomApiProvider).serviceFees(roomId);
});

// ── Property create / update / lifecycle controller ───────────────────────────

class PropertyFormController extends AutoDisposeAsyncNotifier<Property?> {
  @override
  Future<Property?> build() async => null;

  Future<Property> submit({
    Property? existing,
    required String name,
    String? address,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roomRepositoryProvider);
    final result = await AsyncValue.guard(() {
      return existing == null
          ? repo.createProperty(name: name.trim(), address: address?.trim())
          : repo.updateProperty(
              existing.id,
              name: name.trim(),
              address: address?.trim(),
            );
    });
    state = result;
    if (result.hasValue) {
      final saved = result.value!;
      if (existing == null) {
        ref.read(selectedPropertyProvider.notifier).state = saved.id;
      }
      _invalidateProperties();
    }
    return result.value ?? (throw result.error!);
  }

  Future<Property> setArchived({
    required String propertyId,
    required bool isArchived,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roomRepositoryProvider);
    final result = await AsyncValue.guard(() {
      return repo.setPropertyArchived(propertyId, isArchived);
    });
    state = result;
    if (result.hasValue) {
      if (isArchived && ref.read(selectedPropertyProvider) == propertyId) {
        ref.read(selectedPropertyProvider.notifier).state = null;
      }
      _invalidateProperties();
    }
    return result.value ?? (throw result.error!);
  }

  Future<void> delete(String propertyId) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomRepositoryProvider).deleteProperty(propertyId);
      return null;
    });
    state = result;
    if (result.hasValue) {
      if (ref.read(selectedPropertyProvider) == propertyId) {
        ref.read(selectedPropertyProvider.notifier).state = null;
      }
      _invalidateProperties();
    }
    if (result.hasError) throw result.error!;
  }

  void _invalidateProperties() {
    ref.invalidate(propertiesProvider);
    ref.invalidate(archivedPropertiesProvider);
    ref.invalidate(dashboardMetricsProvider);
  }
}

final propertyFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<PropertyFormController, Property?>(
  PropertyFormController.new,
);

// ── Create / update form controller ───────────────────────────────────────────

/// Drives room create/update submission. UI watches [AsyncValue] for loading
/// and error, and reads the saved [Room] from a successful call.
class RoomFormController extends AutoDisposeAsyncNotifier<Room?> {
  @override
  Future<Room?> build() async => null;

  Future<Room> submit({
    required String propertyId,
    Room? existing,
    required Room draft,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roomRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      return existing == null
          ? repo.createRoom(propertyId, draft)
          : repo.updateRoom(draft);
    });
    state = result;
    if (result.hasValue) {
      _invalidateRoom(propertyId, existing?.id ?? result.value!.id);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Room> setActive({
    required String propertyId,
    required String roomId,
    required bool isActive,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(roomRepositoryProvider).setRoomActive(roomId, isActive);
    });
    state = result;
    if (result.hasValue) {
      _invalidateRoom(propertyId, roomId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<void> delete({
    required String propertyId,
    required String roomId,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roomRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.deleteRoom(roomId);
      return null;
    });
    if (state.hasValue) {
      _invalidateRoom(propertyId, roomId);
    }
    if (state.hasError) throw state.error!;
  }

  void _invalidateRoom(String propertyId, String roomId) {
    ref.invalidate(roomsProvider(propertyId));
    ref.invalidate(inactiveRoomsProvider(propertyId));
    ref.invalidate(roomDetailProvider(roomId));
    ref.invalidate(propertiesProvider);
    ref.invalidate(archivedPropertiesProvider);
    ref.invalidate(dashboardMetricsProvider);
  }
}

final roomFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<RoomFormController, Room?>(
  RoomFormController.new,
);

class RoomOperationsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createAsset({
    required String roomId,
    required RoomAsset asset,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomApiProvider).createAsset(roomId, asset.toPayload());
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomAssetsProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> deleteAsset({
    required String roomId,
    required String assetId,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomApiProvider).deleteAsset(roomId, assetId);
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomAssetsProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> createInspection({
    required String roomId,
    required RoomInspection inspection,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref
          .read(roomApiProvider)
          .createInspection(roomId, inspection.toPayload());
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomInspectionsProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> completeInspection({
    required String roomId,
    required String inspectionId,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomApiProvider).completeInspection(roomId, inspectionId);
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomInspectionsProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> createServiceFee({
    required String roomId,
    required RoomServiceFee fee,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomApiProvider).createServiceFee(roomId, fee.toPayload());
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomServiceFeesProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> setServiceFeeActive({
    required String roomId,
    required String feeId,
    required bool isActive,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref
          .read(roomApiProvider)
          .updateServiceFee(roomId, feeId, {'isActive': isActive});
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomServiceFeesProvider(roomId));
    if (result.hasError) throw result.error!;
  }

  Future<void> deleteServiceFee({
    required String roomId,
    required String feeId,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(roomApiProvider).deleteServiceFee(roomId, feeId);
    });
    state = result;
    if (result.hasValue) ref.invalidate(roomServiceFeesProvider(roomId));
    if (result.hasError) throw result.error!;
  }
}

final roomOperationsControllerProvider =
    AutoDisposeAsyncNotifierProvider<RoomOperationsController, void>(
  RoomOperationsController.new,
);
