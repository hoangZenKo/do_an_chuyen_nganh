import '../../models/maintenance.dart';
import 'maintenance_api.dart';

class MaintenanceRepository {
  const MaintenanceRepository(this._api);

  final MaintenanceApi _api;

  Future<MaintenanceListResult> list({
    String? propertyId,
    String? roomId,
    MaintenanceStatus? status,
    MaintenancePriority? priority,
  }) {
    return _api.list(
      propertyId: propertyId,
      roomId: roomId,
      status: status,
      priority: priority,
    );
  }

  Future<MaintenanceTicket> getById(String id) => _api.getById(id);

  Future<MaintenanceTicket> create({
    required String propertyId,
    required String roomId,
    required MaintenancePriority priority,
    required String title,
    String? description,
    String? reportedAt,
    int? estimatedCost,
    String? note,
    List<String> imageUrls = const [],
  }) {
    return _api.create(_payload(
      propertyId: propertyId,
      roomId: roomId,
      priority: priority,
      title: title,
      description: description,
      reportedAt: reportedAt,
      estimatedCost: estimatedCost,
      note: note,
      imageUrls: imageUrls,
    ));
  }

  Future<MaintenanceTicket> update(
    String id, {
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
    List<String> imageUrls = const [],
  }) {
    return _api.update(
      id,
      _payload(
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
        imageUrls: imageUrls,
      ),
    );
  }

  Future<MaintenanceTicket> updateStatus(
    String id,
    MaintenanceStatus status,
  ) {
    return _api.updateStatus(id, status);
  }

  Future<MaintenanceTicket> complete(
    String id, {
    int? actualCost,
    String? note,
    bool createExpense = true,
    String? completedAt,
  }) {
    return _api.complete(id, {
      if (actualCost != null) 'actualCost': actualCost,
      if (note != null) 'note': note.trim(),
      'createExpense': createExpense,
      if (completedAt != null) 'completedAt': completedAt,
    });
  }

  Future<MaintenanceComment> addComment({
    required String ticketId,
    required String body,
    List<String> imageUrls = const [],
  }) {
    return _api.addComment(ticketId, {
      'body': body.trim(),
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    });
  }

  Future<void> delete(String id) => _api.delete(id);

  Map<String, dynamic> _payload({
    required String propertyId,
    required String roomId,
    MaintenanceStatus? status,
    required MaintenancePriority priority,
    required String title,
    String? description,
    String? reportedAt,
    int? estimatedCost,
    int? actualCost,
    String? note,
    List<String> imageUrls = const [],
  }) {
    return {
      'propertyId': propertyId,
      'roomId': roomId,
      if (status != null) 'status': status.wire,
      'priority': priority.name,
      'title': title.trim(),
      if (description != null) 'description': description.trim(),
      if (reportedAt != null && reportedAt.trim().isNotEmpty)
        'reportedAt': reportedAt.trim(),
      if (estimatedCost != null) 'estimatedCost': estimatedCost,
      if (actualCost != null) 'actualCost': actualCost,
      if (note != null) 'note': note.trim(),
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    };
  }
}
