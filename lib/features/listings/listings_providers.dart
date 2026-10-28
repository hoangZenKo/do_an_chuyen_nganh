import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/api_config.dart';
import '../../data/listings/listings_api.dart';
import '../../data/listings/listings_repository.dart';
import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';
import '../auth/auth_providers.dart';

final publicListingsRepositoryProvider = Provider<ListingsRepository>((ref) {
  final client = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => client.close(force: true));
  return ListingsRepository(ListingsApi(client));
});

final managedListingsRepositoryProvider = Provider<ListingsRepository>((ref) =>
    ListingsRepository(ListingsApi(ref.watch(sessionDioProvider).client)));

final publicListingsProvider = FutureProvider.autoDispose
    .family<ListingPage, ListingQuery>((ref, query) =>
        ref.watch(publicListingsRepositoryProvider).browse(query));

final publicListingDetailProvider = FutureProvider.autoDispose
    .family<RoomListing, String>(
        (ref, id) => ref.watch(publicListingsRepositoryProvider).detail(id));

final schoolCampusesProvider = FutureProvider.autoDispose<List<SchoolCampus>>(
    (ref) => ref.watch(publicListingsRepositoryProvider).campuses());

class ListingComparison extends Notifier<List<RoomListing>> {
  @override
  List<RoomListing> build() {
    ref.watch(sessionIdentityProvider);
    return [];
  }

  bool toggle(RoomListing listing) {
    if (state.any((item) => item.id == listing.id)) {
      state = state.where((item) => item.id != listing.id).toList();
      return true;
    }
    if (state.length >= 3) return false;
    state = [...state, listing];
    return true;
  }

  void clear() => state = [];
}

final listingComparisonProvider =
    NotifierProvider<ListingComparison, List<RoomListing>>(
        ListingComparison.new);

typedef ManagedListingsQuery = ({bool admin, int page, String? status});
final managedListingsProvider = FutureProvider.autoDispose
    .family<ListingPage, ManagedListingsQuery>((ref, query) => ref
        .watch(managedListingsRepositoryProvider)
        .manage(admin: query.admin, page: query.page, status: query.status));
