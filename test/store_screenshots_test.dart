import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/screens/shell.dart';
import 'package:stokpilot/services/app_api.dart';
import 'package:stokpilot/widgets/pilot_theme.dart';

// Render the production widgets with isolated, fictional shop records.
// flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const export = bool.fromEnvironment('STORE_SCREENSHOTS');
  setUpAll(() async {
    final font =
        FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await font.load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final device in [
    ('compact_android', 320.0, 640.0),
    ('android', 360.0, 640.0),
    ('iphone', 430.0, 932.0),
    ('iphone_medium', 393.0, 852.0),
    ('ipad', 1024.0, 1366.0),
  ]) {
    testWidgets('Real pages fit ${device.$1} and navigate correctly', (
      tester,
    ) async {
      tester.view.physicalSize = Size(device.$2, device.$3);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        AppApi.resetTestBackend();
      });
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'store-preview',
          email: 'ornek@stokpilot.example',
          isAnonymous: false,
        ),
        signedIn: true,
      );
      AppApi.useTestBackend(auth, db);
      final api = AppApi.instance;
      await api.initialize();
      await api.workspace.update({'productCount': 6});
      await api.collection('entitlements').doc('current').set({
        'status': 'free',
      });
      await api.collection('categories').doc('coffee').set({'name': 'Kahve'});
      await api.collection('units').doc('unit').set({'name': 'Adet'});
      const products = [
        ('Filtre kahve 250 g', 24, 18500, 12000),
        ('Espresso kahve 1 kg', 18, 64000, 42000),
        ('Karton bardak 50 adet', 4, 9500, 6000),
        ('Cam kahve kupası', 32, 24000, 15000),
        ('French press 600 ml', 12, 49000, 31000),
        ('Kahve filtresi 100 adet', 45, 12500, 8000),
      ];
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        await api.collection('products').doc('product$i').set({
          'name': p.$1,
          'stockMilli': p.$2 * 1000,
          'salePriceMinor': p.$3,
          'purchasePriceMinor': p.$4,
          'minStockMilli': 5000,
          'isActive': true,
          'taxRateBps': 2000,
          'categoryId': 'coffee',
          'unitId': 'unit',
          'sku': 'STK-00${i + 1}',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }
      for (final contact in [
        ('Ada Kafe', 325000),
        ('Mavi Atölye', 148500),
        ('Park Büfe', 0),
      ]) {
        await api.collection('contacts').add({
          'name': contact.$1,
          'companyName': contact.$1,
          'type': 'customer',
          'balanceMinor': contact.$2,
          'createdAt': Timestamp.now(),
        });
      }
      for (var i = 0; i < 7; i++) {
        await api.collection('trades').add({
          'type': 'sale',
          'totalMinor': 125000 + i * 25000,
          'paidMinor': 125000 + i * 25000,
          'paymentMethod': i.isEven ? 'cash' : 'card',
          'contactName': 'Ada Kafe',
          'documentNo': 'S-2026-00${i + 1}',
          'items': [],
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(Duration(days: i, minutes: 5)),
          ),
        });
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildPilotTheme(),
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const MainShell(),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      for (final screen in [
        ('dashboard', 'Panel'),
        ('products', 'Stok'),
        ('sales', 'Satış'),
        ('customers', 'Müşteriler'),
      ]) {
        await tester.tap(
          device.$1 == 'ipad'
              ? find.byTooltip(switch (screen.$1) {
                'dashboard' => 'Genel Bakış',
                'products' => 'Ürünler',
                _ => screen.$2,
              })
              : find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(screen.$2),
              ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 10),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${device.$1} ${screen.$1}',
        );
        if (screen.$1 == 'sales') {
          await tester.enterText(find.byType(TextField).first, 'Filtre');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Filtre kahve 250 g').last);
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(find.text('1 kalem'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        if (export) {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage(
              pixelRatio: device.$1 == 'ipad' ? 2 : 3,
            );
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final folder = Directory('store_assets/screenshots/redesign');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/${device.$1}_${screen.$1}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    });
  }
}
