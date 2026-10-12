import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/erp/erp_metrics.dart';

void main() {
  test('ERP totals separate sales, purchases and VAT without guessing profit', () {
    final now = DateTime(2026, 10, 12, 12);
    final m = ErpMetrics.compute(
      now: now,
      lastDays: 30,
      products: [
        {'stockMilli': 4000, 'purchasePriceMinor': 1250, 'minStockMilli': 2000, 'isActive': true},
        {'stockMilli': 0, 'purchasePriceMinor': 150, 'minStockMilli': 1000, 'isActive': true},
        {'stockMilli': 0, 'purchasePriceMinor': 0, 'minStockMilli': 1000, 'isActive': false},
      ],
      contacts: [
        {'balanceMinor': 3500}, {'balanceMinor': -2100}, {'balanceMinor': 500},
      ],
      trades: [
        {'type': 'sale', 'totalMinor': 12000, 'netMinor': 10000,
          'taxMinor': 2000, 'paidMinor': 9000,
          'createdAt': DateTime(2026, 10, 11),
          'lines': [{'name': 'Karton Bardak', 'quantityMilli': 2000, 'netMinor': 10000}]},
        {'type': 'sale', 'totalMinor': 6000, 'netMinor': 5000,
          'taxMinor': 1000, 'paidMinor': 6000,
          'createdAt': DateTime(2026, 10, 12),
          'lines': [{'name': 'Karton Bardak', 'quantityMilli': 1000, 'netMinor': 5000}]},
        {'type': 'purchase', 'totalMinor': 12000, 'netMinor': 10000,
          'taxMinor': 2000, 'paidMinor': 7000, 'createdAt': DateTime(2026, 10, 12)},
        {'type': 'sale', 'totalMinor': 200000, 'netMinor': 180000,
          'taxMinor': 20000, 'paidMinor': 0, 'createdAt': DateTime(2026, 5, 1)},
      ],
    );
    expect(m.productCount, 3);
    expect(m.inventoryCostMinor, 5000);
    expect(m.lowStockCount, 1);
    expect(m.emptyStockCount, 1);
    expect(m.receivableMinor, 4000);
    expect(m.payableMinor, 2100);
    expect(m.saleCount, 2);
    expect(m.purchaseCount, 1);
    expect(m.salesGrossMinor, 18000);
    expect(m.salesNetMinor, 15000);
    expect(m.outputVatMinor, 3000);
    expect(m.inputVatMinor, 2000);
    expect(m.outstandingSalesMinor, 3000);
    expect(m.unpaidPurchasesMinor, 5000);
    expect(m.averageSaleMinor, 9000);
    expect(m.topProducts.single.quantityMilli, 3000);
    expect(m.topProducts.single.netMinor, 15000);
    expect(m.byDay.length, 2);
  });

  test('empty ERP data yields a valid summary and no chart points', () {
    final m = ErpMetrics.compute(products: [], trades: [], contacts: []);
    expect(m.saleCount, 0);
    expect(m.averageSaleMinor, 0);
    expect(m.topProducts, isEmpty);
    expect(m.byDay, isEmpty);
  });

  test('CSV quotes names, does not execute formulas and preserves negative numbers', () {
    final content = erpCsv([
      ['Ürün', 'Değer'],
      ['=IMPORTRANGE("secret")', -350],
      ['Test; ürün', 250],
    ]);
    expect(content.startsWith('\uFEFF'), isTrue);
    expect(content, contains('"\'=IMPORTRANGE(""secret"")"'));
    expect(content, contains('"-350"'));
    expect(content, contains('"Test; ürün"'));
  });
}