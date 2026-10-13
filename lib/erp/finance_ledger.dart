import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceTotals {
  const FinanceTotals({
    required this.collectionsMinor,
    required this.payoutsMinor,
    required this.expensesMinor,
  });

  final int collectionsMinor;
  final int payoutsMinor;
  final int expensesMinor;

  int get netMinor => collectionsMinor - payoutsMinor - expensesMinor;

  static FinanceTotals compute({
    required Iterable<Map<String, dynamic>> payments,
    required Iterable<Map<String, dynamic>> expenses,
    DateTime? since,
  }) {
    bool included(Map<String, dynamic> row) {
      if (since == null) return true;
      final stamp = row['createdAt'];
      final date =
          stamp is Timestamp
              ? stamp.toDate()
              : stamp is DateTime
              ? stamp
              : null;
      return date != null && !date.isBefore(since);
    }

    var collections = 0, payouts = 0, expenseTotal = 0;
    for (final row in payments.where(included)) {
      final amount = row['amountMinor'];
      if (amount is! num || amount <= 0) continue;
      if (row['type'] == 'collection') collections += amount.toInt();
      if (row['type'] == 'payout') payouts += amount.toInt();
    }
    for (final row in expenses.where(included)) {
      final amount = row['amountMinor'];
      if (amount is num && amount > 0) expenseTotal += amount.toInt();
    }
    return FinanceTotals(
      collectionsMinor: collections,
      payoutsMinor: payouts,
      expensesMinor: expenseTotal,
    );
  }
}
