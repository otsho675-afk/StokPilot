import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/erp/finance_ledger.dart';

void main() {
  test(
    'finance ledger counts settled payments once and separates expenses',
    () {
      final totals = FinanceTotals.compute(
        payments: [
          {'type': 'collection', 'amountMinor': 12000},
          {'type': 'payout', 'amountMinor': 3000},
          {'type': 'other', 'amountMinor': 999},
        ],
        expenses: [
          {'amountMinor': 2500},
          {'amountMinor': -100},
        ],
      );
      expect(totals.collectionsMinor, 12000);
      expect(totals.payoutsMinor, 3000);
      expect(totals.expensesMinor, 2500);
      expect(totals.netMinor, 6500);
    },
  );

  test('finance ledger respects selected period', () {
    final totals = FinanceTotals.compute(
      since: DateTime(2026, 10, 1),
      payments: [
        {
          'type': 'collection',
          'amountMinor': 900,
          'createdAt': DateTime(2026, 9, 30),
        },
        {
          'type': 'collection',
          'amountMinor': 200,
          'createdAt': DateTime(2026, 10, 1),
        },
      ],
      expenses: [
        {'amountMinor': 100, 'createdAt': DateTime(2026, 10, 2)},
      ],
    );
    expect(totals.netMinor, 100);
  });
}
