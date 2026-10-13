import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('MetricCard displays values without clipping on small screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: MetricCard(
                title: 'Stok maliyet değeri',
                value: '12.345.678,90 ₺',
                icon: Icons.warehouse_outlined,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Stok maliyet değeri'), findsOneWidget);
    expect(find.text('12.345.678,90 ₺'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageTitle stacks action on narrow screens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 310,
              child: PageTitle(
                title: 'Ürünler ve stoklar',
                subtitle: 'Ürün arama ve yönetim',
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Yeni ürün'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResponsiveFields stacks paired inputs on phones', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 310,
              child: ResponsiveFields(
                first: TextField(
                  decoration: InputDecoration(labelText: 'Barkod'),
                ),
                second: TextField(
                  decoration: InputDecoration(labelText: 'SKU'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Product editor dialog keeps paired form fields laid out on a narrow window',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => FilledButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (dialogContext) => AlertDialog(
                                title: const Text('Yeni ürün'),
                                content: SizedBox(
                                  width: 520,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        ResponsiveFields(
                                          first: TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Stok kodu',
                                            ),
                                          ),
                                          second: TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Barkod',
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        ResponsiveFields(
                                          first: TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Alış fiyatı',
                                            ),
                                          ),
                                          second: TextField(
                                            decoration: InputDecoration(
                                              labelText: 'Satış fiyatı',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                    child: const Text('Kapat'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Ürün ekle'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ürün ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni ürün'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sales item dialog lays out input fields in constrained landscape',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(470, 310));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => FilledButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (dialogContext) => AlertDialog(
                                title: const Text('Satış miktarı'),
                                content: const SizedBox(
                                  width: 380,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Miktar',
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Birim fiyat',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                    child: const Text('Tamam'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Satışı aç'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Satışı aç'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Product form dialog renders inside a 320px phone without intrinsic-size errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (outerContext) => FilledButton(
                    onPressed:
                        () => showDialog<void>(
                          context: outerContext,
                          builder:
                              (dialogContext) => ResponsiveFormDialog(
                                title: const Text('Yeni ürün'),
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Ürün adı',
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    ResponsiveFields(
                                      first: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Stok kodu',
                                        ),
                                      ),
                                      second: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Barkod',
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    ResponsiveFields(
                                      first: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Alış fiyatı',
                                        ),
                                      ),
                                      second: TextField(
                                        decoration: InputDecoration(
                                          labelText: 'Satış fiyatı',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(dialogContext),
                                    child: const Text('Kapat'),
                                  ),
                                  FilledButton(
                                    onPressed: () {},
                                    child: const Text('Kaydet'),
                                  ),
                                ],
                              ),
                        ),
                    child: const Text('Ürün ekle'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ürün ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni ürün'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Product form is scrollable on a small landscape screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(440, 280));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (outerContext) => FilledButton(
                  onPressed:
                      () => showDialog<void>(
                        context: outerContext,
                        builder:
                            (_) => ResponsiveFormDialog(
                              title: const Text('Yeni ürün'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  10,
                                  (i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Alan ${i + 1}',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () {},
                                  child: const Text('Kaydet'),
                                ),
                              ],
                            ),
                      ),
                  child: const Text('Ürün ekle'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ürün ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
