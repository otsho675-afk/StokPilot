import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/screens/product_editor_dialog.dart';

void main() {
  const catalog = ProductCatalog(
    categories: [ProductOption('cat1', 'Ambalaj')],
    units: [ProductOption('unit1', 'Adet')],
    taxes: [ProductOption('tax1', '%20 KDV', taxRateBps: 2000)],
  );

  testWidgets('Real product form opens and closes without layout or lifecycle failures',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (outer) => FilledButton(
        onPressed: () => showDialog<void>(context: outer,
          builder: (_) => ProductEditorDialog(
            loadCatalog: () async => catalog,
            saveProduct: (data) async { saved = data; },
          ),
        ),
        child: const Text('Yeni ürün aç'),
      ),
    ))));
    await tester.tap(find.text('Yeni ürün aç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, 'Karton Bardak');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['name'], 'Karton Bardak');
    expect(saved!['salePriceMinor'], 0);
    expect(find.text('Yeni ürün'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Real product form handles narrow landscape and validation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 320));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (outer) => FilledButton(
        onPressed: () => showDialog<void>(context: outer,
          builder: (_) => ProductEditorDialog(
            loadCatalog: () async => catalog,
            saveProduct: (_) async {},
          ),
        ),
        child: const Text('Formu aç'),
      ),
    ))));
    await tester.tap(find.text('Formu aç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Ürün adı zorunludur.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Product dialog shows loading and recovers on catalog failure',
      (tester) async {
    var tries = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (outer) => FilledButton(
        onPressed: () => showDialog<void>(context: outer,
          builder: (_) => ProductEditorDialog(
            loadCatalog: () async {
              tries++;
              if (tries == 1) throw StateError('Örnek bağlantı hatası');
              return catalog;
            },
            saveProduct: (_) async {},
          ),
        ),
        child: const Text('Formu aç'),
      ),
    ))));
    await tester.tap(find.text('Formu aç'));
    await tester.pumpAndSettle();
    expect(find.text('Ürün seçenekleri yüklenemedi'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}