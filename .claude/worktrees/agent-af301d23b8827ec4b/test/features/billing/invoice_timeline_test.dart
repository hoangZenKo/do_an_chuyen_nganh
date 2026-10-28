import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/billing/widgets/invoice_timeline.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/tenant_portal.dart';

Invoice _invoice() {
  return Invoice(
    id: 'inv-1',
    leaseId: 'lease-1',
    roomId: 'room-1',
    tenantId: 'tenant-1',
    billingMonth: DateTime.parse('2026-08-01T00:00:00.000Z'),
    rentAmount: 1000000,
    electricityAmount: 120000,
    waterAmount: 50000,
    otherAmount: 0,
    totalAmount: 1170000,
    paidAmount: 1170000,
    remainingAmount: 0,
    status: InvoiceStatus.paid,
    dueDate: DateTime.parse('2026-08-05T00:00:00.000Z'),
    issuedAt: DateTime.parse('2026-08-01T00:00:00.000Z'),
    payments: [
      Payment(
        id: 'pay-1',
        invoiceId: 'inv-1',
        amount: 1170000,
        method: PaymentMethod.bankTransfer,
        type: PaymentType.payment,
        paidAt: DateTime.parse('2026-08-06T00:00:00.000Z'),
        note: 'Đã chuyển khoản',
      ),
    ],
  );
}

void main() {
  test('buildInvoiceTimelineEntries includes tenant proof and settlement flow',
      () {
    final entries = buildInvoiceTimelineEntries(
      _invoice(),
      currentProof: PaymentProof(
        id: 'proof-1',
        invoiceId: 'inv-1',
        tenantId: 'tenant-1',
        amount: 1170000,
        method: 'bank_transfer',
        status: 'approved',
        note: 'Đã gửi biên lai',
        proofImageUrls: ['https://example.com/proof.png'],
        submittedAt: DateTime.parse('2026-08-03T00:00:00.000Z'),
        reviewedAt: DateTime.parse('2026-08-04T00:00:00.000Z'),
        reviewNote: 'Đã đối soát',
      ),
    );

    expect(
      entries.map((entry) => entry.title).toList(),
      [
        'Hóa đơn được tạo',
        'Đã gửi chứng từ',
        'Chứng từ đã được duyệt',
        'Đến hạn thanh toán',
        'Thanh toán đã ghi nhận',
        'Đã tất toán',
      ],
    );
    expect(entries.last.kind, InvoiceTimelineKind.settled);
  });
}
