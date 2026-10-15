import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/services/app_api.dart';
import 'package:stokpilot/widgets/inventory_alert_button.dart';

void main() {
  testWidgets('stock and stale price reminders open on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      AppApi.resetTestBackend();
    });
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'alerts-test'),
      signedIn: true,
    );
    AppApi.useTestBackend(auth, db);
    final api = AppApi.instance;
    await api.collection('products').doc('coffee').set({
      'name': 'Filtre kahve',
      'isActive': true,
      'stockMilli': 1000,
      'minStockMilli': 3000,
      'priceChangedAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 60)),
      ),
    });
    await api.collection('settings').doc('alerts').set({
      'priceReminderDays': 45,
      'lowStockAlerts': true,
    });
    InventoryAlertSelection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: InventoryAlertButton(
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('2 hatırlatıcı'), findsOneWidget);
    await tester.tap(find.byTooltip('2 hatırlatıcı'));
    await tester.pumpAndSettle();
    expect(find.text('Hatırlatıcılar (2)'), findsOneWidget);
    expect(find.text('Stok kritik seviyede'), findsOneWidget);
    expect(find.text('45 gündür fiyat güncellenmedi'), findsOneWidget);
    await tester.tap(find.text('Stok kritik seviyede'));
    await tester.pumpAndSettle();
    expect(selected?.alert.kind, 'stock');
    expect(selected?.product.id, 'coffee');
    expect(tester.takeException(), isNull);
  });
}
