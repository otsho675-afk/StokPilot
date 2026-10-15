import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('Pager stays inside phones, tablets and desktop widths', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    for (final width in <double>[320, 375, 400, 768, 1024]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ListPager(
                total: 245,
                page: 3,
                pageSize: 10,
                onPageChanged: (_) {},
                onPageSizeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Overflow at $width px');
      if (width < 500) {
        expect(
          find.byKey(const ValueKey('pager-mobile-scroll')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('Pager supports changing record count on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    int? selectedSize;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: ListPager(
              total: 80,
              page: 0,
              pageSize: 10,
              onPageChanged: (_) {},
              onPageSizeChanged: (n) => selectedSize = n,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pager-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 kayıt').last);
    await tester.pumpAndSettle();
    expect(selectedSize, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Responsive checkout-style dialog fits narrow landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 350));
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
                            (dialogContext) => ResponsiveFormDialog(
                              title: const Text('Cari borç kaydı'),
                              content: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ResponsiveFields(
                                    first: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Tutar',
                                      ),
                                    ),
                                    second: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Açıklama',
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text('İşlem tarihi'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(dialogContext).pop(),
                                  child: const Text('Vazgeç'),
                                ),
                                FilledButton(
                                  onPressed: () {},
                                  child: const Text('Kaydet'),
                                ),
                              ],
                            ),
                      ),
                  child: const Text('Aç'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Cari borç kaydı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
