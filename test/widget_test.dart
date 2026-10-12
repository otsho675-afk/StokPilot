import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('StokPilot metrik kartı görüntülenir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricCard(
            title: 'Toplam ürün',
            value: '42',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      ),
    );
    expect(find.text('Toplam ürün'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });
}
