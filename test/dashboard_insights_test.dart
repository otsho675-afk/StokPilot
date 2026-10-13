import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/dashboard_insights.dart';

void main() {
  final now = DateTime(2026, 10, 14, 13);

  test('period includes start of first day, ignores future and older trades', () {
    final result = DashboardInsights.compute([
      {
        'type': 'sale',
        'createdAt': DateTime(2026, 10, 8),
        'totalMinor': 12500,
        'paidMinor': 12500,
        'paymentMethod': 'cash',
      },
      {
        'type': 'sale',
        'createdAt': DateTime(2026, 10, 14, 12),
        'totalMinor': 8000,
        'paidMinor': 0,
        'paymentMethod': 'credit',
      },
      {
        'type': 'purchase',
        'createdAt': DateTime(2026, 10, 13),
        'totalMinor': 6500,
      },
      {
        'type': 'sale',
        'createdAt': DateTime(2026, 10, 7, 23),
        'totalMinor': 10000,
      },
      {
        'type': 'sale',
        'createdAt': DateTime(2026, 10, 15),
        'totalMinor': 10000,
      },
    ], days: 7, now: now);
    expect(result.salesMinor, 20500);
    expect(result.collectedMinor, 12500);
    expect(result.purchasesMinor, 6500);
    expect(result.saleCount, 2);
    expect(result.averageSaleMinor, 10250);
    expect(result.cashMinor, 12500);
    expect(result.creditMinor, 8000);
    expect(result.recent.length, 4);
    expect(result.byDay[DateTime(2026, 10, 8)], 12500);
  });

  test('empty period is safe for averages', () {
    final result = DashboardInsights.compute([], days: 30, now: now);
    expect(result.averageSaleMinor, 0);
    expect(result.recent, isEmpty);
    expect(result.byDay, isEmpty);
  });

  test('restocking ignores inactive, prioritizes empty and estimates target', () {
    final suggestions = suggestRestocks([
      MapEntry('x', {'name': 'X', 'stockMilli': 1500, 'minStockMilli': 2000}),
      MapEntry('y', {'name': 'Y', 'stockMilli': 0, 'minStockMilli': 1000}),
      MapEntry('z', {'name': 'Z', 'stockMilli': 0, 'minStockMilli': 1000, 'isActive': false}),
      MapEntry('q', {'name': 'Q', 'stockMilli': 5000, 'minStockMilli': 1000}),
    ]);
    expect(suggestions.map((e) => e.id).toList(), ['y', 'x']);
    expect(suggestions.first.orderMilli, 2000);
    expect(suggestions.last.orderMilli, 2500);
  });
}
