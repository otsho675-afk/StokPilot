import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stokpilot/widgets/ui.dart';

void main() {
  testWidgets('Closing an owned dialog keeps its controller until the route unmounts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (outer) => FilledButton(
            onPressed: () => showOwnedDialog<void>(
              context: outer,
              controllers: [controller],
              builder: (dialogContext) => ResponsiveFormDialog(
                title: const Text('Cari kaydı'),
                content: TextField(controller: controller),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test müşteri');
    expect(controller.text, 'Test müşteri');
    await tester.tap(find.text('Kapat'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Cari kaydı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back navigation does not leave inherited dependencies behind',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (outer) => FilledButton(
          onPressed: () => Navigator.of(outer).push<void>(
            MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Ürün ekle')),
              body: const SafeArea(child: Column(children: [
                TextField(decoration: InputDecoration(labelText: 'Ürün adı')),
              ])),
            )),
          ),
          child: const Text('Git'),
        )),
      ),
    ));
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(find.text('Ürün ekle'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
