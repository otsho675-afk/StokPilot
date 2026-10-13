import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/core/sales_tools.dart';
import 'package:stokpilot/screens/product_editor_dialog.dart';

Finder fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('product form generates EAN13 and previews tax and profit in real time',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(home: ProductEditorDialog(
      loadCatalog: () async => const ProductCatalog(),
      saveProduct: (data) async { saved = data; },
    )));
    await tester.pumpAndSettle();

    await tester.enterText(fieldWithLabel('Ürün adı *'), 'Deneme ürün');
    await tester.tap(find.byTooltip('Otomatik iç barkod üret'));
    await tester.pump();
    final barcode = tester.widget<TextField>(fieldWithLabel('Barkod')).controller!.text;
    expect(isValidEan13(barcode), true);
    expect(barcode.startsWith('20'), true);

    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('%20').last);
    await tester.pumpAndSettle();

    await tester.enterText(fieldWithLabel('KDV hariç alış (₺)'), '100');
    await tester.enterText(fieldWithLabel('KDV hariç satış (₺)'), '150');
    await tester.pumpAndSettle();
    expect(find.textContaining('120,00'), findsWidgets);
    expect(find.textContaining('180,00'), findsWidgets);
    expect(find.textContaining('%50'), findsWidgets);

    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!['purchasePriceMinor'], 10000);
    expect(saved!['salePriceMinor'], 15000);
    expect(saved!['taxRateBps'], 2000);
    expect(saved!['barcode'], barcode);
    expect(tester.takeException(), isNull);
  });
}
