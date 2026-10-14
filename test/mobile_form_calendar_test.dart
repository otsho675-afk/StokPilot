import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('mobile date picker opens bottom calendar and returns quick date', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => FilledButton(
          onPressed: () async {
            result = await showPilotDatePicker(
              context: context,
              initialDate: today,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              title: 'İşlem tarihi',
            );
          },
          child: const Text('Takvimi aç'),
        )),
      ),
    ));
    await tester.tap(find.text('Takvimi aç'));
    await tester.pumpAndSettle();
    expect(find.text('İşlem tarihi'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('7 gün önce'), findsOneWidget);
    await tester.tap(find.text('7 gün önce'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarihi seç'));
    await tester.pumpAndSettle();
    expect(result, today.subtract(const Duration(days: 7)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile owned form is a bottom sheet and saves with fixed footer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    var saved = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (outer) => FilledButton(
          onPressed: () => showOwnedDialog<void>(
            context: outer,
            controllers: [controller],
            builder: (sheetContext) => ResponsiveFormDialog(
              title: const Text('Yeni müşteri'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Firma adı'),
                  ),
                  const SizedBox(height: 14),
                  const TextField(decoration: InputDecoration(labelText: 'Telefon')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('İptal')),
                FilledButton(
                  onPressed: () {
                    saved = controller.text;
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ),
          child: const Text('Müşteri ekle'),
        )),
      ),
    ));
    await tester.tap(find.text('Müşteri ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Deneme müşterisi');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved, 'Deneme müşterisi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop owned form remains a dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (outer) => FilledButton(
          onPressed: () => showOwnedDialog<void>(
            context: outer,
            controllers: [],
            builder: (dialogContext) => ResponsiveFormDialog(
              title: const Text('Yeni tedarikçi'),
              content: const Text('Form içeriği'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
          child: const Text('Tedarikçi ekle'),
        )),
      ),
    ));
    await tester.tap(find.text('Tedarikçi ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
