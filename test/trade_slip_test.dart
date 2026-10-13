import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/screens/trades_page.dart';

void main() {
  test('trade slip includes document, company, totals and paid amount', () {
    final text = tradeSlipText({
      'type': 'purchase',
      'documentNo': 'ALS-test123',
      'contactName': 'Deneme Tedarik',
      'externalDocumentNo': 'FT-43',
      'lines': [
        {
          'name': 'Vida',
          'quantityMilli': 2000,
          'priceMinor': 1000,
          'totalMinor': 2000,
        },
      ],
      'netMinor': 2000,
      'taxMinor': 400,
      'totalMinor': 2400,
      'paidMinor': 1000,
      'paymentMethod': 'card',
    });
    expect(text, contains('ALS-test123'));
    expect(text, contains('Deneme Tedarik'));
    expect(text, contains('FT-43'));
    expect(text, contains('Vida'));
    expect(text, contains('Kalan:'));
    expect(text, contains('resmî e-Fatura'));
  });
}
