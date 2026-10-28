import '../../models/billing.dart';
import '../../models/maintenance.dart';
import '../../models/notification_delivery.dart';
import '../../models/tenant_portal.dart';
import 'tenant_portal_api.dart';

class TenantPortalRepository {
  const TenantPortalRepository(this._api);

  final TenantPortalApi _api;

  Future<TenantPortalProfile> me() => _api.me();

  Future<TenantDashboard> dashboard() => _api.dashboard();

  Future<List<Invoice>> invoices() => _api.invoices();

  Future<List<TenantPortalLease>> leases() => _api.leases();

  Future<Invoice> invoice(String id) => _api.invoice(id);

  Future<List<MaintenanceTicket>> maintenance() => _api.maintenance();

  Future<List<TenantNotification>> notifications() => _api.notifications();

  Future<void> markNotificationRead(String id) => _api.markNotificationRead(id);

  Future<List<NotificationDeliveryLog>> zaloMessages() => _api.zaloMessages();

  Future<NotificationDeliveryLog> createZaloMessage({
    required String message,
  }) {
    return _api.createZaloMessage({'message': message.trim()});
  }

  Future<void> markZaloMessageRead(String id) => _api.markZaloMessageRead(id);

  Future<PaymentProof> submitPaymentProof({
    required String invoiceId,
    required int amount,
    String method = 'bank_transfer',
    String? note,
    List<String> proofImageUrls = const [],
  }) {
    return _api.submitPaymentProof(invoiceId, {
      'amount': amount,
      'method': method,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (proofImageUrls.isNotEmpty) 'proofImageUrls': proofImageUrls,
    });
  }

  Future<MaintenanceTicket> createMaintenance({
    required String title,
    String? description,
    MaintenancePriority priority = MaintenancePriority.medium,
    List<String> imageUrls = const [],
  }) {
    return _api.createMaintenance({
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'priority': priority.name,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    });
  }

  Future<MaintenanceComment> addMaintenanceComment({
    required String ticketId,
    required String body,
    List<String> imageUrls = const [],
  }) {
    return _api.addMaintenanceComment(ticketId, {
      'body': body.trim(),
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
    });
  }
}
