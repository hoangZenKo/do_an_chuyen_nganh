import '../../models/room_listing.dart';
import '../../models/student_discovery.dart';
import 'listings_api.dart';

class ListingsRepository {
  const ListingsRepository(this.api);
  final ListingsApi api;
  Future<void> verify(RoomListing listing,
          {required bool landlordVerified,
          required bool roomInspected,
          required String note}) =>
      api.verify(listing,
          landlordVerified: landlordVerified,
          roomInspected: roomInspected,
          note: note);
  Future<List<SchoolCampus>> campuses() => api.campuses();
  Future<void> report(String id,
          {required String reason, required String detail}) =>
      api.report(id, reason: reason, detail: detail);
  Future<Map<String, dynamic>> reports(int page) => api.reports(page);
  Future<void> reviewReport(String id, String status, String note) =>
      api.reviewReport(id, status, note);
  Future<ListingPage> browse(ListingQuery query) => api.browse(query);
  Future<RoomListing> detail(String id) => api.detail(id);
  Future<ListingPage> manage(
          {required bool admin, required int page, String? status}) =>
      api.manage(admin: admin, page: page, status: status);
  Future<void> save(Map<String, dynamic> content, {String? id}) =>
      api.save(content, id: id);
  Future<void> action(RoomListing listing, String action, {String? note}) =>
      api.action(listing, action, note: note);
}
