import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/inventory_forecast.dart';

void main() {
  test('sales velocity and recommended order are deterministic', () {
    final result = InventoryForecast.forProduct(
      productId: 'a',
      stockMilli: 4000,
      minimumMilli: 1000,
      soldMilli: 14000,
      periodDays: 14,
    );
    expect(result.dailyUnitsMilli, 1000);
    expect(result.daysOfCover, 4);
    expect(result.recommendedOrderMilli, 17000);
  });

  test('zero sales uses minimum stock instead of invented demand', () {
    final result = InventoryForecast.forProduct(
      productId: 'a', stockMilli: 0, minimumMilli: 3000,
      soldMilli: 0, periodDays: 30,
    );
    expect(result.daysOfCover, isNull);
    expect(result.recommendedOrderMilli, 6000);
  });

  test('sales aggregation ignores purchases, old and future data', () {
    final sold = InventoryForecast.soldByProduct([
      {
        'type': 'sale', 'createdAt': DateTime(2026, 10, 11),
        'lines': [
          {'productId': 'cup', 'quantityMilli': 4000},
          {'productId': 'plate', 'quantityMilli': 2000},
        ],
      },
      {
        'type': 'sale', 'createdAt': DateTime(2026, 10, 14),
        'lines': [{'productId': 'cup', 'quantityMilli': 5000}],
      },
      {
        'type': 'purchase', 'createdAt': DateTime(2026, 10, 12),
        'lines': [{'productId': 'cup', 'quantityMilli': 6000}],
      },
      {
        'type': 'sale', 'createdAt': DateTime(2026, 9, 10),
        'lines': [{'productId': 'cup', 'quantityMilli': 7000}],
      },
    ], now: DateTime(2026, 10, 14, 20), periodDays: 7);
    expect(sold['cup'], 9000);
    expect(sold['plate'], 2000);
  });

  test('invalid time window is rejected', () {
    expect(() => InventoryForecast.forProduct(
      productId: 'a', stockMilli: 0, minimumMilli: 0,
      soldMilli: 0, periodDays: 0,
    ), throwsArgumentError);
  });
}
