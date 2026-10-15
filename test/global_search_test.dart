import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/global_search.dart';

void main() {
  test('Turkish text, identifiers and relevance across ERP records', () {
    const items = [
      SearchItem(
        id: '1',
        kind: SearchKind.product,
        title: 'Çelik Vida',
        subtitle: 'Stok',
        keywords: ['VID-42', '8691234567890'],
      ),
      SearchItem(
        id: '2',
        kind: SearchKind.supplier,
        title: 'Çelik Ticaret',
        subtitle: 'Tedarikçi',
        keywords: ['5551234567'],
      ),
      SearchItem(
        id: '3',
        kind: SearchKind.sale,
        title: 'SAT-42',
        subtitle: 'Satış fişi',
        keywords: ['Çelik Ticaret'],
      ),
    ];
    expect(findAcrossWorkspace(items, 'celik').map((e) => e.id), [
      '2',
      '1',
      '3',
    ]);
    expect(findAcrossWorkspace(items, 'VID-42').single.id, '1');
    expect(findAcrossWorkspace(items, '555123').single.id, '2');
    expect(findAcrossWorkspace(items, '').isEmpty, true);
  });
}
