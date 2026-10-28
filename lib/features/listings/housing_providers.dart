import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/listings/housing_repository.dart';
import '../../models/housing.dart';
import '../auth/auth_providers.dart';

final housingRepositoryProvider = Provider<HousingRepository>(
    (ref) => HousingRepository(ref.watch(sessionDioProvider).client));
final viewingSlotsProvider = FutureProvider.autoDispose
    .family<ViewingAvailability, String>(
        (ref, id) => ref.watch(housingRepositoryProvider).slots(id));
final leaseHandoverProvider = FutureProvider.autoDispose
    .family<HandoverDetail, String>(
        (ref, id) => ref.watch(housingRepositoryProvider).handover(id));
final savedRoomsProvider = FutureProvider.autoDispose
    .family<HousingPage<SavedRoom>, int>(
        (ref, page) => ref.watch(housingRepositoryProvider).favorites(page));
final savedRoomProvider = FutureProvider.autoDispose.family<bool, String>(
    (ref, id) => ref.watch(housingRepositoryProvider).isSaved(id));
final roomViewingsProvider = FutureProvider.autoDispose
    .family<HousingPage<RoomViewing>, int>(
        (ref, page) => ref.watch(housingRepositoryProvider).viewings(page));
final roomViewingProvider = FutureProvider.autoDispose
    .family<RoomViewing, String>(
        (ref, id) => ref.watch(housingRepositoryProvider).viewing(id));
final housingNoticesProvider = FutureProvider.autoDispose
    .family<HousingPage<HousingNotice>, int>((ref, page) =>
        ref.watch(housingRepositoryProvider).notifications(page));
final rentalPilotProvider = FutureProvider.autoDispose<RentalPilot>(
    (ref) => ref.watch(housingRepositoryProvider).pilot());
final pilotFeedbackProvider = FutureProvider.autoDispose
    .family<HousingPage<PilotFeedback>, int>(
        (ref, page) => ref.watch(housingRepositoryProvider).feedbackList(page));
