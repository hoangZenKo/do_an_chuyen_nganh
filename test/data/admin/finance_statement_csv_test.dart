import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/admin/finance_statement_csv.dart';

void main() {
  test('parses strict statement CSV and normalizes UTC', () {
    final rows = parseFinanceStatementCsv(
        'externalId,amount,occurredAt,reference\nTX-1,1500000,2026-10-26T08:00:00+07:00,"invoice,123"\n');
    expect(rows, [
      {
        'externalId': 'TX-1',
        'amount': 1500000,
        'occurredAt': '2026-10-26T01:00:00.000Z',
        'reference': 'invoice,123',
      }
    ]);
  });

  test('rejects duplicate ids, local times and malformed header', () {
    expect(
        () => parseFinanceStatementCsv(
            'externalId,amount,occurredAt,reference\nTX-1,1,2026-10-26T08:00:00Z,\nTX-1,2,2026-10-26T09:00:00Z,'),
        throwsFormatException);
    expect(
        () => parseFinanceStatementCsv(
            'externalId,amount,occurredAt,reference\nTX-1,1,2026-10-26T08:00:00,'),
        throwsFormatException);
    expect(
        () => parseFinanceStatementCsv(
            'id,amount,date,reference\nTX-1,1,2026-10-26T08:00:00Z,'),
        throwsFormatException);
  });
}
