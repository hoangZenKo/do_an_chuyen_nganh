import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/billing/widgets/invoice_timeline.dart';
import 'package:rental_room_management/models/billing.dart';
import 'package:rental_room_management/models/tenant_portal.dart';

Invoice _invoice(
    {bool isDemo = false, String paymentNote = 'Đã chuyển khoản'}) {
  return Invoice(
    id: 'inv-1',
    leaseId: 'lease-1',
    roomId: 'room-1',
    tenantId: 'tenant-1',
    isDemo: isDemo,
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
        note: paymentNote,
      ),
    ],
  );
}

void main() {
  test('legacy test payment notes use product copy without changing real notes',
      () {
    const legacyNote = 'DEMO CARD - VISA **** 4242 - KHONG CO TIEN THAT';
    final simulated = buildInvoiceTimelineEntries(
      _invoice(isDemo: true, paymentNote: legacyNote),
    ).firstWhere((entry) => entry.kind == InvoiceTimelineKind.payment);
    expect(simulated.subtitle, contains('Thẻ •••• 4242'));
    expect(simulated.subtitle, contains('Môi trường kiểm thử'));
    expect(simulated.subtitle, isNot(contains('DEMO')));
    final real = buildInvoiceTimelineEntries(
      _invoice(paymentNote: legacyNote),
    ).firstWhere((entry) => entry.kind == InvoiceTimelineKind.payment);
    expect(real.subtitle, contains(legacyNote));
  });

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
