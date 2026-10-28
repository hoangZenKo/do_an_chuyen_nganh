import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/billing/billing_api.dart';
import '../../data/billing/billing_repository.dart';
import '../../models/billing.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../rooms/property_selection_provider.dart';

final billingApiProvider = Provider<BillingApi>((ref) {
  return BillingApi(ref.watch(dioProvider));
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(billingApiProvider));
});

final billingActiveLeasesProvider = FutureProvider<List<BillingLease>>((ref) {
  return ref.watch(billingRepositoryProvider).activeLeases();
});

final invoicesProvider = FutureProvider<List<Invoice>>((ref) {
  final propertyId = ref.watch(selectedPropertyProvider);
  return ref.watch(billingRepositoryProvider).invoices(propertyId: propertyId);
});

final invoiceProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, invoiceId) {
  return ref.watch(billingRepositoryProvider).invoice(invoiceId);
});

final pendingPaymentProofsProvider =
    FutureProvider.autoDispose<List<PaymentProof>>((ref) {
  return ref.watch(billingRepositoryProvider).paymentProofs(status: 'pending');
});

class MeterReadingsKey {
  const MeterReadingsKey({this.roomId, this.month});

  final String? roomId;
  final String? month;

  @override
  bool operator ==(Object other) {
    return other is MeterReadingsKey &&
        other.roomId == roomId &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(roomId, month);
}

final meterReadingsProvider = FutureProvider.autoDispose
    .family<List<MeterReading>, MeterReadingsKey>((ref, key) {
  return ref.watch(billingRepositoryProvider).meterReadings(
        roomId: key.roomId,
        month: key.month,
      );
});

class BulkInvoicePreflightKey {
  const BulkInvoicePreflightKey({
    required this.propertyId,
    required this.billingMonth,
  });

  final String propertyId;
  final String billingMonth;

  @override
  bool operator ==(Object other) {
    return other is BulkInvoicePreflightKey &&
        other.propertyId == propertyId &&
        other.billingMonth == billingMonth;
  }

  @override
  int get hashCode => Object.hash(propertyId, billingMonth);
}

final bulkInvoicePreflightProvider = FutureProvider.autoDispose
    .family<BulkInvoicePreflight, BulkInvoicePreflightKey>((ref, key) {
  return ref.watch(billingRepositoryProvider).bulkInvoicePreflight(
        propertyId: key.propertyId,
        billingMonth: key.billingMonth,
      );
});

final billingAutomationProvider = FutureProvider.autoDispose
    .family<BillingAutomation, String>((ref, propertyId) {
  return ref.watch(billingRepositoryProvider).billingAutomation(propertyId);
});

class BillingAutomationPreviewKey {
  const BillingAutomationPreviewKey({
    required this.propertyId,
    required this.billingMonth,
  });

  final String propertyId;
  final String billingMonth;

  @override
  bool operator ==(Object other) {
    return other is BillingAutomationPreviewKey &&
        other.propertyId == propertyId &&
        other.billingMonth == billingMonth;
  }

  @override
  int get hashCode => Object.hash(propertyId, billingMonth);
}

final billingAutomationPreviewProvider = FutureProvider.autoDispose
    .family<BillingAutomationPreview, BillingAutomationPreviewKey>((ref, key) {
  return ref.watch(billingRepositoryProvider).billingAutomationPreview(
        propertyId: key.propertyId,
        billingMonth: key.billingMonth,
      );
});

class BillingFormFailure implements Exception {
  const BillingFormFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class BillingFormController extends AutoDisposeAsyncNotifier<Invoice?> {
  @override
  Future<Invoice?> build() async => null;

  Future<Invoice> submit({
    required BillingLease lease,
    required String billingMonth,
    List<BillingMeterReadingDraft> meterReadings = const [],
    String? dueDate,
    int otherAmount = 0,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(billingRepositoryProvider);
    final result = await AsyncValue.guard(() async {
      final existing = await repo.invoices(month: billingMonth);
      final duplicate = existing.any((invoice) => invoice.leaseId == lease.id);
      if (duplicate) {
        throw const BillingFormFailure(
          'Hóa đơn tháng này đã tồn tại. Không có dữ liệu mới nào được tạo.',
        );
      }
      return repo.createInvoice(
        leaseId: lease.id,
        billingMonth: billingMonth,
        dueDate: dueDate,
        otherAmount: otherAmount,
        note: note,
        meterReadings: meterReadings,
      );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
    }
    return result.value ?? (throw result.error!);
  }
}

final billingFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<BillingFormController, Invoice?>(
  BillingFormController.new,
);

class BulkInvoiceController
    extends AutoDisposeAsyncNotifier<BulkInvoiceGenerationResult?> {
  @override
  Future<BulkInvoiceGenerationResult?> build() async => null;

  Future<BulkInvoiceGenerationResult> submit({
    required String propertyId,
    required String billingMonth,
    String? dueDate,
    List<BulkInvoiceReadingDraft> readings = const [],
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).createBulkInvoices(
            propertyId: propertyId,
            billingMonth: billingMonth,
            dueDate: dueDate,
            readings: readings,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(
        bulkInvoicePreflightProvider(
          BulkInvoicePreflightKey(
            propertyId: propertyId,
            billingMonth: billingMonth,
          ),
        ),
      );
    }
    return result.value ?? (throw result.error!);
  }
}

final bulkInvoiceControllerProvider = AutoDisposeAsyncNotifierProvider<
    BulkInvoiceController, BulkInvoiceGenerationResult?>(
  BulkInvoiceController.new,
);

class BillingAutomationController
    extends AutoDisposeAsyncNotifier<BillingAutomationRunResult?> {
  @override
  Future<BillingAutomationRunResult?> build() async => null;

  Future<BillingAutomation> save({
    required String propertyId,
    required bool isEnabled,
    required int invoiceDay,
    required int dueDay,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).updateBillingAutomation(
            propertyId: propertyId,
            isEnabled: isEnabled,
            invoiceDay: invoiceDay,
            dueDay: dueDay,
          );
    });
    state = const AsyncValue<BillingAutomationRunResult?>.data(null);
    if (result.hasValue) {
      ref.invalidate(billingAutomationProvider(propertyId));
      ref.invalidate(dashboardMetricsProvider);
    }
    if (result.hasError) throw result.error!;
    return result.value!;
  }

  Future<BillingAutomationRunResult> run({
    required String propertyId,
    required String billingMonth,
    List<BulkInvoiceReadingDraft> readings = const [],
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).runBillingAutomation(
            propertyId: propertyId,
            billingMonth: billingMonth,
            readings: readings,
          );
    });
    state = result;
    if (result.hasValue) {
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(billingAutomationProvider(propertyId));
      ref.invalidate(
        bulkInvoicePreflightProvider(
          BulkInvoicePreflightKey(
            propertyId: propertyId,
            billingMonth: billingMonth,
          ),
        ),
      );
      ref.invalidate(
        billingAutomationPreviewProvider(
          BillingAutomationPreviewKey(
            propertyId: propertyId,
            billingMonth: billingMonth,
          ),
        ),
      );
    }
    return result.value ?? (throw result.error!);
  }
}

final billingAutomationControllerProvider = AutoDisposeAsyncNotifierProvider<
    BillingAutomationController, BillingAutomationRunResult?>(
  BillingAutomationController.new,
);

class BillingPaymentController extends AutoDisposeAsyncNotifier<Invoice?> {
  @override
  Future<Invoice?> build() async => null;

  Future<Invoice> pay({
    required String invoiceId,
    required int amount,
    PaymentMethod method = PaymentMethod.cash,
    String? paidAt,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).recordPayment(
            invoiceId: invoiceId,
            amount: amount,
            method: method,
            paidAt: paidAt,
            note: note,
          );
    });
    state = result;
    if (result.hasValue) {
      _invalidateBilling(ref, invoiceId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Invoice> cancel({
    required String invoiceId,
    required String note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).cancelInvoice(
            invoiceId: invoiceId,
            note: note,
          );
    });
    state = result;
    if (result.hasValue) {
      _invalidateBilling(ref, invoiceId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<Invoice> reversePayment({
    required String invoiceId,
    required String paymentId,
    required String note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() {
      return ref.read(billingRepositoryProvider).reversePayment(
            invoiceId: invoiceId,
            paymentId: paymentId,
            note: note,
          );
    });
    state = result;
    if (result.hasValue) {
      _invalidateBilling(ref, invoiceId);
    }
    return result.value ?? (throw result.error!);
  }

  Future<void> reviewPaymentProof({
    required String proofId,
    required String invoiceId,
    required String status,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await ref.read(billingRepositoryProvider).reviewPaymentProof(
            proofId: proofId,
            status: status,
            note: note,
          );
    });
    state = const AsyncValue<Invoice?>.data(null);
    if (!result.hasError) {
      _invalidateBilling(ref, invoiceId);
      ref.invalidate(pendingPaymentProofsProvider);
    }
    if (result.hasError) throw result.error!;
  }
}

final billingPaymentControllerProvider =
    AutoDisposeAsyncNotifierProvider<BillingPaymentController, Invoice?>(
  BillingPaymentController.new,
);

void _invalidateBilling(Ref ref, String invoiceId) {
  ref.invalidate(invoicesProvider);
  ref.invalidate(invoiceProvider(invoiceId));
  ref.invalidate(dashboardMetricsProvider);
}
