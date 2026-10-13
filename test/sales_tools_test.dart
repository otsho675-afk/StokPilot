import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/sales_tools.dart';

void main() {
  test('internal EAN-13 has a valid checksum and internal prefix', () {
    for (var i = 0; i < 50; i++) {
      final code = generateInternalBarcode(random: Random(i));
      expect(code.length, 13);
      expect(code.startsWith('20'), isTrue);
      expect(isValidEan13(code), isTrue);
      final broken = code.substring(0, 12) +
        ((int.parse(code[12]) + 1) % 10).toString();
      expect(isValidEan13(broken), isFalse);
    }
  });
  test('VAT preview is added without mutating stored net prices', () {
    expect(vatMinor(10000, 2000), 2000);
    expect(grossMinor(10000, 2000), 12000);
    expect(grossMinor(10000, 1000), 11000);
    expect(grossMinor(10000, 100), 10100);
    expect(grossMinor(10000, 0), 10000);
    expect(profitMarkupPercent(10000, 15000), 50);
    expect(profitMarkupPercent(10000, 7500), -25);
    expect(profitMarkupPercent(0, 15000), isNull);
  });
  test('barcode exact match ranks ahead of name and SKU', () {
    final items = [
      const ProductSearchEntry(id: 'name', name: '8691234567890 Kağıt',
          sku: 'KA-1', barcode: '2022222222222', stockMilli: 2000),
      const ProductSearchEntry(id: 'barcode', name: 'Bardak',
          sku: 'BAR', barcode: '8691234567890', stockMilli: 3000),
      const ProductSearchEntry(id: 'sku', name: 'Karton',
          sku: '8691234567890', barcode: '', stockMilli: 0),
    ];
    expect(findProducts(items, '8691234567890').first.id, 'barcode');
    expect(findProducts(items, 'KAGIT').map((e) => e.id), ['name']);
    expect(findProducts(items, 'bardak').single.id, 'barcode');
    expect(findProducts(items, 'yok'), isEmpty);
  });
  test('cash/card are collected, credit requires customer account', () {
    expect(salePaidMinor('cash', 5000, hasContact: false), 5000);
    expect(salePaidMinor('card', 5000, hasContact: false), 5000);
    expect(salePaidMinor('credit', 5000, hasContact: true), 0);
    expect(() => salePaidMinor('credit', 5000, hasContact: false),
      throwsFormatException);
    expect(() => salePaidMinor('invalid', 5000, hasContact: true),
      throwsFormatException);
  });
}
