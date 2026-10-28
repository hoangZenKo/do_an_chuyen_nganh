import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/api_config.dart';
import '../../data/listings/reviews_repository.dart';
import '../../models/housing.dart';
import '../../models/room_review.dart';
import '../auth/auth_providers.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>(
    (ref) => ReviewsRepository(ref.watch(sessionDioProvider).client));
final publicReviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return ReviewsRepository(dio);
});
typedef PublicReviewsQuery = ({String listingId, int page});
final publicReviewsProvider = FutureProvider.autoDispose
    .family<PublicReviewPage, PublicReviewsQuery>((ref, query) => ref
        .watch(publicReviewsRepositoryProvider)
        .publicReviews(query.listingId, query.page));
final reviewContextProvider = FutureProvider.autoDispose
    .family<ReviewContext, String>((ref, leaseId) =>
        ref.watch(reviewsRepositoryProvider).context(leaseId));
typedef ManagedReviewsQuery = ({
  bool admin,
  int page,
  String status,
  bool replies
});
final managedReviewsProvider = FutureProvider.autoDispose
    .family<HousingPage<RoomReview>, ManagedReviewsQuery>((ref, query) => ref
        .watch(reviewsRepositoryProvider)
        .manage(
            admin: query.admin,
            page: query.page,
            status: query.status,
            replies: query.replies));
