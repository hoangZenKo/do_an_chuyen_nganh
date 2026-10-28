import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/maintenance/maintenance_api.dart';
import '../../data/maintenance/maintenance_repository.dart';
import '../../models/maintenance.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../expenses/expense_providers.dart';
import '../rooms/room_providers.dart';

final maintenanceApiProvider = Provider<MaintenanceApi>((ref) {
  return MaintenanceApi(ref.watch(sessionDioProvider).client);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository(ref.watch(maintenanceApiProvider));
});

class MaintenanceListQuery {
  const MaintenanceListQuery({
    this.propertyId,
    this.roomId,
    this.status,
    this.priority,
  });

  final String? propertyId;
  final String? roomId;
  final MaintenanceStatus? status;
  final MaintenancePriority? priority;

  @override
  bool operator ==(Object other) {
    return other is MaintenanceListQuery &&
        other.propertyId == propertyId &&
        other.roomId == roomId &&
        other.status == status &&
        other.priority == priority;
  }

  @override
  int get hashCode => Object.hash(propertyId, roomId, status, priority);
}

final maintenanceListProvider =
    FutureProvider.family<MaintenanceListResult, MaintenanceListQuery>(
  (ref, query) {
    final selectedPropertyId = ref.watch(selectedPropertyProvider);
    return ref.watch(maintenanceRepositoryProvider).list(
          propertyId: query.propertyId ?? selectedPropertyId,
          roomId: query.roomId,
          status: query.status,
          priority: query.priority,
        );
  },
);

final maintenanceDetailProvider =
    FutureProvider.autoDispose.family<MaintenanceTicket, String>((ref, id) {
  return ref.watch(maintenanceRepositoryProvider).getById(id);
});

class MaintenanceFormController
    extends AutoDisposeAsyncNotifier<MaintenanceTicket?> {
  @override
  Future<MaintenanceTicket?> build() async => null;

  Future<MaintenanceTicket> submit({
    String? ticketId,
    required String propertyId,
    required String roomId,
    required MaintenanceStatus status,
    required MaintenancePriority priority,
    required String title,
    String? description,
    String? reportedAt,
    int? estimatedCost,
    int? actualCost,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      final repo = ref.read(maintenanceRepositoryProvider);
      if (ticketId == null) {
        return repo.create(
          propertyId: propertyId,
          roomId: roomId,
          priority: priority,
          title: title,
          description: description,
          reportedAt: reportedAt,
          estimatedCost: estimatedCost,
          note: note,
        );
      }
      return repo.update(
        ticketId,
        propertyId: propertyId,
        roomId: roomId,
        status: status,
        priority: priority,
        title: title,
        description: description,
        reportedAt: reportedAt,
        estimatedCost: estimatedCost,
        actualCost: actualCost,
        note: note,
      );
    });
    state = result;
    if (result.hasValue) _invalidateMaintenance(ref);
    return result.value ?? (throw result.error!);
  }
}

final maintenanceFormControllerProvider = AutoDisposeAsyncNotifierProvider<
    MaintenanceFormController,
    MaintenanceTicket?>(MaintenanceFormController.new);

class MaintenanceActionController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStatus(String id, MaintenanceStatus status) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(maintenanceRepositoryProvider).updateStatus(id, status);
    });
    state = result;
    if (!result.hasError) _invalidateMaintenance(ref);
    if (result.hasError) throw result.error!;
  }

  Future<void> complete(
    String id, {
    int? actualCost,
    String? note,
    bool createExpense = true,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(maintenanceRepositoryProvider).complete(
            id,
            actualCost: actualCost,
            note: note,
            createExpense: createExpense,
            completedAt: _todayIsoDate(),
          );
    });
    state = result;
    if (!result.hasError) _invalidateMaintenance(ref);
    if (result.hasError) throw result.error!;
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(maintenanceRepositoryProvider).delete(id);
    });
    state = result;
    if (!result.hasError) _invalidateMaintenance(ref);
    if (result.hasError) throw result.error!;
  }

  Future<void> addComment(
    String id, {
    required String body,
    List<String> imageUrls = const [],
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(maintenanceRepositoryProvider).addComment(
            ticketId: id,
            body: body,
            imageUrls: imageUrls,
          );
    });
    state = result;
    if (!result.hasError) _invalidateMaintenance(ref);
    if (result.hasError) throw result.error!;
  }
}

final maintenanceActionControllerProvider =
    AutoDisposeAsyncNotifierProvider<MaintenanceActionController, void>(
  MaintenanceActionController.new,
);

void _invalidateMaintenance(Ref ref) {
  ref.invalidate(maintenanceListProvider);
  ref.invalidate(maintenanceDetailProvider);
  ref.invalidate(expenseListProvider);
  ref.invalidate(propertiesProvider);
  ref.invalidate(dashboardMetricsProvider);
}

String _todayIsoDate() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
