import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tenant_portal/tenant_portal_api.dart';
import '../../data/tenant_portal/tenant_portal_repository.dart';
import '../../data/uploads/upload_api.dart';
import '../../models/billing.dart';
import '../../models/maintenance.dart';
import '../../models/notification_delivery.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_providers.dart';

final tenantPortalApiProvider = Provider<TenantPortalApi>((ref) {
  return TenantPortalApi(ref.watch(sessionDioProvider).client);
});

final tenantPortalRepositoryProvider = Provider<TenantPortalRepository>((ref) {
  return TenantPortalRepository(ref.watch(tenantPortalApiProvider));
});

final uploadApiProvider = Provider<UploadApi>((ref) {
  return UploadApi(ref.watch(sessionDioProvider).client);
});

final tenantPortalProfileProvider = FutureProvider<TenantPortalProfile>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).me();
});

final tenantPortalDashboardProvider = FutureProvider<TenantDashboard>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).dashboard();
});

final tenantPortalInvoicesProvider = FutureProvider<List<Invoice>>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).invoices();
});

final tenantPortalLeasesProvider =
    FutureProvider<List<TenantPortalLease>>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).leases();
});

final tenantPortalInvoiceProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, id) {
  return ref.watch(tenantPortalRepositoryProvider).invoice(id);
});

final tenantPortalNotificationsProvider =
    FutureProvider<List<TenantNotification>>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).notifications();
});

final tenantPortalZaloMessagesProvider =
    FutureProvider<List<NotificationDeliveryLog>>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).zaloMessages();
});

final tenantPortalMaintenanceProvider =
    FutureProvider<List<MaintenanceTicket>>((ref) {
  return ref.watch(tenantPortalRepositoryProvider).maintenance();
});

class TenantMaintenanceController
    extends AutoDisposeAsyncNotifier<MaintenanceTicket?> {
  @override
  Future<MaintenanceTicket?> build() async => null;

  Future<MaintenanceTicket> submit({
    required String title,
    String? description,
    MaintenancePriority priority = MaintenancePriority.medium,
    List<String> imageUrls = const [],
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantPortalRepositoryProvider).createMaintenance(
            title: title,
            description: description,
            priority: priority,
            imageUrls: imageUrls,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(tenantPortalDashboardProvider);
      ref.invalidate(tenantPortalMaintenanceProvider);
    }
    return result.value ?? (throw result.error!);
  }

  Future<MaintenanceComment> comment({
    required String ticketId,
    required String body,
    List<String> imageUrls = const [],
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantPortalRepositoryProvider).addMaintenanceComment(
            ticketId: ticketId,
            body: body,
            imageUrls: imageUrls,
          );
    });
    state = const AsyncValue<MaintenanceTicket?>.data(null);
    if (result.hasValue) {
      ref.invalidate(tenantPortalDashboardProvider);
      ref.invalidate(tenantPortalMaintenanceProvider);
    }
    if (result.hasError) throw result.error!;
    return result.value!;
  }
}

final tenantMaintenanceControllerProvider = AutoDisposeAsyncNotifierProvider<
    TenantMaintenanceController,
    MaintenanceTicket?>(TenantMaintenanceController.new);

class TenantNotificationController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markRead(String id) async {
    await ref.read(tenantPortalRepositoryProvider).markNotificationRead(id);
    ref.invalidate(tenantPortalDashboardProvider);
    ref.invalidate(tenantPortalNotificationsProvider);
  }

  Future<void> markZaloRead(String id) async {
    await ref.read(tenantPortalRepositoryProvider).markZaloMessageRead(id);
    ref.invalidate(tenantPortalDashboardProvider);
    ref.invalidate(tenantPortalZaloMessagesProvider);
  }
}

final tenantNotificationControllerProvider =
    AutoDisposeAsyncNotifierProvider<TenantNotificationController, void>(
  TenantNotificationController.new,
);

class TenantZaloMessageController
    extends AutoDisposeAsyncNotifier<NotificationDeliveryLog?> {
  @override
  Future<NotificationDeliveryLog?> build() async => null;

  Future<NotificationDeliveryLog> send(String message) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantPortalRepositoryProvider).createZaloMessage(
            message: message,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(tenantPortalDashboardProvider);
      ref.invalidate(tenantPortalZaloMessagesProvider);
    }
    return result.value ?? (throw result.error!);
  }
}

final tenantZaloMessageControllerProvider = AutoDisposeAsyncNotifierProvider<
    TenantZaloMessageController,
    NotificationDeliveryLog?>(TenantZaloMessageController.new);

class TenantPaymentProofController
    extends AutoDisposeAsyncNotifier<PaymentProof?> {
  @override
  Future<PaymentProof?> build() async => null;

  Future<PaymentProof> submit({
    required String invoiceId,
    required int amount,
    String method = 'bank_transfer',
    String? note,
    List<String> proofImageUrls = const [],
    String? requestKey,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(tenantPortalRepositoryProvider).submitPaymentProof(
            requestKey: requestKey,
            invoiceId: invoiceId,
            amount: amount,
            method: method,
            note: note,
            proofImageUrls: proofImageUrls,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(tenantPortalDashboardProvider);
      ref.invalidate(tenantPortalInvoiceProvider(invoiceId));
      ref.invalidate(tenantPortalInvoicesProvider);
      ref.invalidate(tenantPortalNotificationsProvider);
    }
    return result.value ?? (throw result.error!);
  }
}

final tenantPaymentProofControllerProvider = AutoDisposeAsyncNotifierProvider<
    TenantPaymentProofController,
    PaymentProof?>(TenantPaymentProofController.new);
