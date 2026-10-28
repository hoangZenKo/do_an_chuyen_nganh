import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/data/billing/billing_api.dart';
import 'package:rental_room_management/data/billing/billing_repository.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/billing_providers.dart';
import 'package:rental_room_management/features/billing/billing_receipts_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/billing_receipt.dart';

class PreviewSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
      user: LandlordUser(
          id: 'preview', fullName: 'Preview', email: 'preview@example.test'),
      accessToken: 'preview',
      refreshToken: 'preview'));
}

class PreviewBillingRepository extends BillingRepository {
  PreviewBillingRepository() : super(BillingApi(Dio()));

  @override
  Future<List<Invoice>> invoices(
          {InvoiceStatus? status, String? month, String? propertyId}) async =>
      [
        for (final month in [9, 10])
          Invoice(
              id: 'invoice-$month',
              leaseId: 'lease',
              roomId: 'room',
              roomName: 'A101',
              tenantId: 'tenant',
              billingMonth: DateTime(2026, month),
              rentAmount: 2500000,
              electricityAmount: 0,
              waterAmount: 0,
              otherAmount: 0,
              totalAmount: 2500000,
              paidAmount: 1000000,
              remainingAmount: 1500000,
              status: InvoiceStatus.partial),
      ];

  @override
  Future<List<BillingReceipt>> receipts({String? tenantId}) async => [
        BillingReceipt(
            id: 'receipt-preview-1',
            tenantId: 'tenant',
            amount: 3500000,
            availableAmount: 1500000,
            refundedAmount: 0,
            method: PaymentMethod.bankTransfer,
            reference: 'BANK-MINH-HOA-01',
            paidAt: DateTime(2026, 10, 26),
            allocations: const [
              BillingAllocation(
                  id: 'allocation-1', invoiceId: 'invoice-9', amount: 1000000),
              BillingAllocation(
                  id: 'allocation-2', invoiceId: 'invoice-10', amount: 1000000)
            ]),
      ];
}

void main() => runApp(ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(PreviewSession.new),
          billingRepositoryProvider
              .overrideWithValue(PreviewBillingRepository())
        ],
        child: MaterialApp(
            theme: AppTheme.dark,
            home: const BillingReceiptsScreen(
                tenantId: 'tenant',
                tenantName: 'Người thuê minh họa · A101'))));
