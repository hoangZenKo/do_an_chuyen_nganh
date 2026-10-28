import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/features/billing/widgets/meter_reading_fields.dart';
import 'package:rental_room_management/models/billing.dart';

void main() {
  test('meterInsight flags unusually high consumption against baseline', () {
    final previous = TextEditingController(text: '100');
    final current = TextEditingController(text: '180');
    final unitPrice = TextEditingController(text: '3500');
    addTearDown(previous.dispose);
    addTearDown(current.dispose);
    addTearDown(unitPrice.dispose);

    final insight = meterInsight(
      previous,
      current,
      unitPrice,
      const MeterReading(
        id: 'm1',
        roomId: 'r1',
        utilityType: UtilityType.electricity,
        billingMonth: null,
        previousReading: 50,
        currentReading: 90,
        unitPrice: 3500,
        usage: 40,
        amount: 140000,
      ),
    );

    expect(insight?.usage, 80);
    expect(insight?.amount, 280000);
    expect(insight?.level, MeterInsightLevel.danger);
  });

  testWidgets('MeterReadingFields shows previous reading and warning copy',
      (tester) async {
    final previous = TextEditingController(text: '100');
    final current = TextEditingController(text: '180');
    final unitPrice = TextEditingController(text: '3500');
    addTearDown(previous.dispose);
    addTearDown(current.dispose);
    addTearDown(unitPrice.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MeterReadingFields(
              previous: previous,
              current: current,
              unitPrice: unitPrice,
              utilityType: UtilityType.electricity,
              baseline: const MeterReading(
                id: 'm1',
                roomId: 'r1',
                utilityType: UtilityType.electricity,
                billingMonth: null,
                previousReading: 50,
                currentReading: 90,
                unitPrice: 3500,
                usage: 40,
                amount: 140000,
              ),
              validator: (_) => (_) => null,
              summary: meterSummary(previous, current, unitPrice),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Đã lấy kỳ trước'), findsOneWidget);
    expect(find.textContaining('Điện: 80 số'), findsOneWidget);
    expect(find.textContaining('Tăng mạnh so với kỳ trước'), findsOneWidget);
  });
}
