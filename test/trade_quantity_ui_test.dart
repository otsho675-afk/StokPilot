import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/screens/trades_page.dart';
import 'package:stokpilot/services/app_api.dart';
import 'package:stokpilot/widgets/pilot_theme.dart';

void main() {
  testWidgets('compact sale accepts a fractional basket quantity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      AppApi.resetTestBackend();
    });
    final db = FakeFirebaseFirestore();
    AppApi.useTestBackend(
      MockFirebaseAuth(
        mockUser: MockUser(uid: 'quantity-test'),
        signedIn: true,
      ),
      db,
    );
    await AppApi.instance.collection('products').doc('coffee').set({
      'name': 'Filtre kahve',
      'sku': 'COFFEE',
      'barcode': '',
      'stockMilli': 5000,
      'minStockMilli': 1000,
      'salePriceMinor': 1000,
      'purchasePriceMinor': 500,
      'taxRateBps': 0,
      'isActive': true,
      'createdAt': Timestamp.now(),
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPilotTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: TradesPage(type: 'sale'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Filtre');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtre kahve').last);
    await tester.pumpAndSettle();

    final quantity = find.byKey(const ValueKey('trade-quantity-coffee'));
    await tester.ensureVisible(quantity);
    await tester.tap(quantity);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0,5');
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();

    expect(find.text('0.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
