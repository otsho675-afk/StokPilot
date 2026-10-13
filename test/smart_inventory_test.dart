import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/smart_inventory.dart';

void main() {
  test('same Turkish product is matched by full name, SKU or barcode', () {
    final products = [
      MapEntry('one', <String, dynamic>{
        'name': 'İçli Köfte',
        'sku': 'IK-7',
        'barcode': '12345',
      }),
    ];
    expect(
      findProductMatch(name: 'icli', sku: '', barcode: '', products: products),
      isNull,
    );
    expect(
      findProductMatch(
        name: 'İÇLİ   KÖFTE',
        sku: '',
        barcode: '',
        products: products,
      )?.kind,
      ProductMatchKind.name,
    );
    expect(
      findProductMatch(
        name: 'Başka',
        sku: 'ik-7',
        barcode: '',
        products: products,
      )?.kind,
      ProductMatchKind.sku,
    );
    expect(
      findProductMatch(
        name: 'Başka',
        sku: '',
        barcode: '12345',
        products: products,
      )?.kind,
      ProductMatchKind.barcode,
    );
    expect(
      findProductMatch(
        name: 'İçli Köfte',
        sku: '',
        barcode: '',
        products: products,
        excludingId: 'one',
      ),
      isNull,
    );
  });

  test('stock and price alerts honor age and inactive products', () {
    final now = DateTime.utc(2026, 10, 13);
    final products = [
      MapEntry('one', <String, dynamic>{
        'name': 'Kahve',
        'stockMilli': 2000,
        'minStockMilli': 3000,
        'priceChangedAt': now.subtract(const Duration(days: 60)),
      }),
      MapEntry('two', <String, dynamic>{
        'name': 'Çay',
        'stockMilli': 0,
        'minStockMilli': 0,
        'isActive': false,
        'priceChangedAt': now.subtract(const Duration(days: 100)),
      }),
    ];
    expect(
      inventoryAlerts(
        products,
        now: now,
        priceReminderDays: 45,
      ).map((e) => e.kind),
      ['stock', 'price'],
    );
    expect(
      inventoryAlerts(
        products,
        now: now,
        priceReminderDays: 90,
      ).map((e) => e.kind),
      ['stock'],
    );
  });
}
