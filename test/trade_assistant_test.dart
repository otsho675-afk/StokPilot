import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/trade_assistant.dart';

void main() {
  const line = BasketLineSnapshot(
    id: 'coffee',
    name: 'Kahve',
    quantityMilli: 2000,
    priceMinor: 10000,
  );

  test('warns before overselling and blocks the action', () {
    final hints = inspectBasket(
      sale: true,
      lines: [line],
      products: {
        'coffee': {
          'stockMilli': 1000,
          'minStockMilli': 500,
          'salePriceMinor': 10000,
        },
      },
    );
    expect(hints.single.kind, BasketHintKind.insufficient);
    expect(hints.single.blocksSave, isTrue);
  });

  test('shows a forecast of critical stock and a changed price', () {
    final hints = inspectBasket(
      sale: true,
      lines: [line],
      products: {
        'coffee': {
          'stockMilli': 2500,
          'minStockMilli': 1000,
          'salePriceMinor': 11000,
        },
      },
    );
    expect(hints.map((hint) => hint.kind), [
      BasketHintKind.lowAfterSale,
      BasketHintKind.priceChanged,
    ]);
    expect(hints.every((hint) => !hint.blocksSave), isTrue);
  });

  test('does not report sale-only hints for a purchase', () {
    final hints = inspectBasket(
      sale: false,
      lines: [line],
      products: {
        'coffee': {
          'stockMilli': 0,
          'minStockMilli': 1000,
          'salePriceMinor': 11000,
        },
      },
    );
    expect(hints, isEmpty);
  });

  test('inactive product blocks both sale and purchase', () {
    final hints = inspectBasket(
      sale: false,
      lines: [line],
      products: {
        'coffee': {'isActive': false},
      },
    );
    expect(hints.single.kind, BasketHintKind.unavailable);
    expect(hints.single.blocksSave, isTrue);
  });
}
