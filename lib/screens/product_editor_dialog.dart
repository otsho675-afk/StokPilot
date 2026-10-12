import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/app_api.dart';
import '../widgets/ui.dart';

/// A full-screen, keyboard-safe form route. Avoids nested AlertDialog
/// intrinsic measurement and inherited-widget teardown during modal pop.
class ProductFormScaffold extends StatelessWidget {
  const ProductFormScaffold({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: title),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: content,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ProductOption {
  const ProductOption(this.id, this.name, {this.taxRateBps = 0});
  final String id;
  final String name;
  final int taxRateBps;
}

class ProductCatalog {
  const ProductCatalog({
    this.categories = const [],
    this.units = const [],
    this.taxes = const [],
  });
  final List<ProductOption> categories;
  final List<ProductOption> units;
  final List<ProductOption> taxes;

  static Future<ProductCatalog> fetch() async {
    final api = AppApi.instance;
    final cats = await api.collection('categories').get();
    final units = await api.collection('units').get();
    final taxes = await api.collection('taxRates').get();
    return ProductCatalog(
      categories: cats.docs.map((d) => ProductOption(
        d.id, (d.data()['name'] ?? '').toString())).toList(),
      units: units.docs.map((d) => ProductOption(
        d.id, (d.data()['name'] ?? '').toString())).toList(),
      taxes: taxes.docs.map((d) => ProductOption(
        d.id, (d.data()['name'] ?? '').toString(),
        taxRateBps: (d.data()['rateBps'] as num?)?.toInt() ?? 0)).toList(),
    );
  }
}

/// A real route with its own lifecycle: controllers are not disposed until
/// after the closing animation completes and the widget is unmounted.
class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({
    super.key,
    required this.loadCatalog,
    required this.saveProduct,
    this.existing,
  });

  final Future<ProductCatalog> Function() loadCatalog;
  final Future<void> Function(Map<String, dynamic>) saveProduct;
  final Map<String, dynamic>? existing;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController barcode;
  late final TextEditingController purchase;
  late final TextEditingController sale;
  late final TextEditingController minimum;
  late Future<ProductCatalog> _catalog;

  late String categoryId;
  late String unitId;
  String taxId = '';
  bool active = true;
  bool saving = false;
  String? error;

  String _currency(dynamic amount) =>
      ((amount is num ? amount : 0) / 100).toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    final data = widget.existing ?? const <String, dynamic>{};
    name = TextEditingController(text: (data['name'] ?? '').toString());
    sku = TextEditingController(text: (data['sku'] ?? '').toString());
    barcode = TextEditingController(text: (data['barcode'] ?? '').toString());
    purchase = TextEditingController(text: _currency(data['purchasePriceMinor']));
    sale = TextEditingController(text: _currency(data['salePriceMinor']));
    minimum = TextEditingController(text:
      quantity((data['minStockMilli'] as num?)?.toInt() ?? 0));
    categoryId = (data['categoryId'] ?? '').toString();
    unitId = (data['unitId'] ?? '').toString();
    active = data['isActive'] != false;
    _catalog = widget.loadCatalog();
  }

  @override
  void dispose() {
    for (final input in [name, sku, barcode, purchase, sale, minimum]) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> _save(ProductCatalog options) async {
    if (saving) return;
    try {
      if (name.text.trim().isEmpty) {
        throw const FormatException('Ürün adı zorunludur.');
      }
      final rates = options.taxes.where((o) => o.id == taxId);
      final values = <String, dynamic>{
        'name': name.text.trim(),
        'sku': sku.text.trim(),
        'barcode': barcode.text.trim(),
        'categoryId': categoryId,
        'unitId': unitId,
        'taxRateBps': rates.isEmpty ? 0 : rates.first.taxRateBps,
        'purchasePriceMinor': parseMoney(purchase.text),
        'salePriceMinor': parseMoney(sale.text),
        'minStockMilli': parseQty(minimum.text),
        'isActive': active,
      };
      setState(() { saving = true; error = null; });
      await widget.saveProduct(values);
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception.toString().replaceFirst('FormatException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ProductCatalog>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ProductFormScaffold(
          title: const Text('Ürün seçenekleri yüklenemedi'),
          content: Text(snapshot.error.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat')),
            FilledButton(onPressed: () => setState(() {
              _catalog = widget.loadCatalog();
            }), child: const Text('Tekrar dene')),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const ProductFormScaffold(
          title: Text('Ürün bilgileri yükleniyor'),
          content: Padding(padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator())),
        );
      }

      final options = snapshot.data!;
      final categoryValue = options.categories.any((o) => o.id == categoryId)
          ? categoryId : '';
      final unitValue = options.units.any((o) => o.id == unitId) ? unitId : '';
      if (taxId.isEmpty && widget.existing != null) {
        final oldRate = (widget.existing!['taxRateBps'] as num?)?.toInt() ?? 0;
        for (final item in options.taxes) {
          if (item.taxRateBps == oldRate) { taxId = item.id; break; }
        }
      }
      final taxValue = options.taxes.any((o) => o.id == taxId) ? taxId : '';
      return ProductFormScaffold(
        title: Text(widget.existing == null ? 'Yeni ürün' : 'Ürün düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Ürün adı *')),
            const SizedBox(height: 12),
            ResponsiveFields(
              first: TextField(controller: sku,
                decoration: const InputDecoration(labelText: 'Stok kodu (SKU)')),
              second: TextField(controller: barcode,
                decoration: const InputDecoration(labelText: 'Barkod')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Seçiniz')),
                ...options.categories.map((o) => DropdownMenuItem(
                  value: o.id, child: Text(o.name,
                    overflow: TextOverflow.ellipsis, maxLines: 1))),
              ],
              onChanged: saving ? null : (v) => setState(() => categoryId = v ?? ''),
            ),
            const SizedBox(height: 12),
            ResponsiveFields(
              first: DropdownButtonFormField<String>(
                key: ValueKey('unit-$unitValue'),
                initialValue: unitValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Seçiniz')),
                  ...options.units.map((o) => DropdownMenuItem(
                    value: o.id, child: Text(o.name,
                      overflow: TextOverflow.ellipsis, maxLines: 1))),
                ],
                onChanged: saving ? null : (v) => setState(() => unitId = v ?? ''),
              ),
              second: DropdownButtonFormField<String>(
                key: ValueKey('tax-$taxValue'),
                initialValue: taxValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'KDV oranı'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('%0')),
                  ...options.taxes.map((o) => DropdownMenuItem(
                    value: o.id, child: Text(o.name,
                      overflow: TextOverflow.ellipsis, maxLines: 1))),
                ],
                onChanged: saving ? null : (v) => setState(() => taxId = v ?? ''),
              ),
            ),
            const SizedBox(height: 12),
            ResponsiveFields(
              first: TextField(controller: purchase,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Alış fiyatı (₺)')),
              second: TextField(controller: sale,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Satış fiyatı (₺)')),
            ),
            const SizedBox(height: 12),
            TextField(controller: minimum,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Kritik stok eşiği')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ürün aktif'),
              value: active,
              onChanged: saving ? null : (v) => setState(() => active = v),
            ),
            const Text('İlk stoku ürünü kaydettikten sonra Stok işlemi üzerinden ekleyin.',
              style: TextStyle(color: muted, fontSize: 12)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(
                color: Color(0xFFB73232), fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Vazgeç')),
          FilledButton(
            onPressed: saving ? null : () => _save(options),
            child: Text(saving ? 'Kaydediliyor...' : 'Kaydet')),
        ],
      );
    },
  );
}

/// Stable stock dialog. A previous implementation disposed controllers while
/// the Navigator was still animating the old route out of the element tree.
class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({
    super.key,
    required this.productName,
    required this.adjustStock,
  });

  final String productName;
  final Future<void> Function(int deltaMilli, String note) adjustStock;

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final amount = TextEditingController();
  final note = TextEditingController();
  bool adding = true;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    try {
      final value = parseQty(amount.text);
      if (value <= 0) {
        throw const FormatException('Miktar sıfırdan büyük olmalıdır.');
      }
      setState(() { saving = true; error = null; });
      await widget.adjustStock(adding ? value : -value, note.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception.toString().replaceFirst('FormatException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ProductFormScaffold(
    title: Text('${widget.productName} • Stok işlemi'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Stok giriş')),
            ButtonSegment(value: false, label: Text('Stok çıkış')),
          ],
          selected: {adding},
          onSelectionChanged: saving ? null : (value) =>
              setState(() => adding = value.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Miktar (ör: 2,5)'),
        ),
        const SizedBox(height: 12),
        TextField(controller: note,
          decoration: const InputDecoration(labelText: 'Açıklama')),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Color(0xFFB73232))),
        ],
      ],
    ),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Vazgeç')),
      FilledButton(onPressed: saving ? null : _save,
        child: Text(saving ? 'Kaydediliyor...' : 'Kaydet')),
    ],
  );
}