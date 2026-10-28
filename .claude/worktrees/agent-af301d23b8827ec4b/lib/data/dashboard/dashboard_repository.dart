import '../../models/dashboard.dart';
import 'dashboard_api.dart';

class DashboardRepository {
  const DashboardRepository(this._api);

  final DashboardApi _api;

  Future<DashboardMetrics> metrics({
    String? propertyId,
    int months = 12,
  }) {
    return _api.metrics(propertyId: propertyId, months: months);
  }
}
