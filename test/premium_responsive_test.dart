import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('MetricCard displays values without clipping on small screens', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 280, child: MetricCard(
        title: 'Stok maliyet değeri', value: '12.345.678,90 ₺',
        icon: Icons.warehouse_outlined,
      )),
    ))));
    expect(find.text('Stok maliyet değeri'), findsOneWidget);
    expect(find.text('12.345.678,90 ₺'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageTitle stacks action on narrow screens', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 310, child: PageTitle(
        title: 'Ürünler ve stoklar', subtitle: 'Ürün arama ve yönetim',
        action: FilledButton(onPressed: () {}, child: const Text('Yeni ürün')),
      )),
    ))));
    expect(find.text('Yeni ürün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ResponsiveFields stacks paired inputs on phones', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 310, child: ResponsiveFields(
        first: TextField(decoration: InputDecoration(labelText: 'Barkod')),
        second: TextField(decoration: InputDecoration(labelText: 'SKU')),
      )),
    ))));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
