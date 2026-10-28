import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/operations/p1_operations_api.dart';
import '../../models/p1_operations.dart';
import '../auth/auth_providers.dart';

final operationOptionsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
        (ref) => ref.watch(p1OperationsApiProvider).options());

final p1OperationsApiProvider = Provider<P1OperationsApi>(
    (ref) => P1OperationsApi(ref.watch(sessionDioProvider).client));
final turnoversProvider = FutureProvider.autoDispose
    .family<P1Page<RoomTurnover>, int>((ref, page) =>
        ref.watch(p1OperationsApiProvider).turnovers(page: page));
final recurringTasksProvider = FutureProvider.autoDispose
    .family<P1Page<OperationTask>, int>(
        (ref, page) => ref.watch(p1OperationsApiProvider).tasks(page: page));
final recurringSchedulesProvider = FutureProvider.autoDispose
    .family<P1Page<RecurringOperation>, int>((ref, page) =>
        ref.watch(p1OperationsApiProvider).recurring(page: page));
final landlordAnnouncementsProvider =
    FutureProvider.autoDispose<List<AnnouncementItem>>(
        (ref) => ref.watch(p1OperationsApiProvider).announcements());
final tenantAnnouncementsProvider =
    FutureProvider.autoDispose<List<AnnouncementItem>>((ref) =>
        ref.watch(p1OperationsApiProvider).announcements(tenant: true));
final announcementTemplatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(p1OperationsApiProvider).templates());
final tenantGroupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(p1OperationsApiProvider).groups());
